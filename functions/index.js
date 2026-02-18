const functions = require("firebase-functions");
const fetch = require("node-fetch");

const SERPAPI_KEY =
  "3c98c1ad2a12891b404f04b5183fc31781b0fd08aed9da9a2d5a21cb296426c0";

const KROGER_CLIENT_ID = "findr-bbccpcdg";
const KROGER_CLIENT_SECRET = "61jjPy8_xnYsa8jQWb-FqGIBW9KI-fJVeiNzXBoY";

function setCorsHeaders(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Accept, Authorization");
}

/**
 * SerpApi proxy — forwards GET requests server-side to avoid CORS.
 *
 * Example: GET /api/serpapi?engine=google_maps&q=batteries+near+me&ll=@37,-122,14z
 */
exports.serpapi = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "GET") { res.status(405).json({ error: "Method not allowed" }); return; }

  try {
    const params = new URLSearchParams(req.query);
    params.set("api_key", SERPAPI_KEY);
    params.set("output", "json");

    const url = `https://serpapi.com/search.json?${params.toString()}`;
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      timeout: 15000,
    });

    const data = await response.json();
    res.status(response.status).json(data);
  } catch (err) {
    console.error("SerpApi proxy error:", err);
    res.status(502).json({ error: "SerpApi request failed" });
  }
});

/**
 * Kroger API proxy — handles OAuth token exchange and API calls server-side.
 *
 * Routes:
 *   GET /api/kroger/token         — get an OAuth2 access token
 *   GET /api/kroger/locations?... — proxy to Kroger Locations API
 *   GET /api/kroger/products?...  — proxy to Kroger Products API
 */
let cachedToken = null;
let tokenExpiry = 0;

async function getKrogerToken() {
  if (cachedToken && Date.now() < tokenExpiry - 60000) {
    return cachedToken;
  }

  const credentials = Buffer.from(`${KROGER_CLIENT_ID}:${KROGER_CLIENT_SECRET}`).toString("base64");
  const resp = await fetch("https://api.kroger.com/v1/connect/oauth2/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials&scope=product.compact",
    timeout: 12000,
  });

  if (!resp.ok) throw new Error(`Kroger OAuth ${resp.status}`);
  const data = await resp.json();
  cachedToken = data.access_token;
  tokenExpiry = Date.now() + (data.expires_in || 1800) * 1000;
  return cachedToken;
}

exports.kroger = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "GET") { res.status(405).json({ error: "Method not allowed" }); return; }

  try {
    const pathParts = req.path.split("/").filter(Boolean);
    const endpoint = pathParts[pathParts.length - 1];

    if (endpoint === "token") {
      const token = await getKrogerToken();
      res.json({ access_token: token });
      return;
    }

    const token = await getKrogerToken();
    if (!token) { res.status(502).json({ error: "Could not get Kroger token" }); return; }

    let krogerUrl;
    if (endpoint === "locations") {
      const params = new URLSearchParams(req.query);
      krogerUrl = `https://api.kroger.com/v1/locations?${params.toString()}`;
    } else if (endpoint === "products") {
      const params = new URLSearchParams(req.query);
      krogerUrl = `https://api.kroger.com/v1/products?${params.toString()}`;
    } else {
      res.status(404).json({ error: `Unknown Kroger endpoint: ${endpoint}` });
      return;
    }

    const resp = await fetch(krogerUrl, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
      timeout: 12000,
    });

    const data = await resp.json();
    res.status(resp.status).json(data);
  } catch (err) {
    console.error("Kroger proxy error:", err);
    res.status(502).json({ error: "Kroger request failed" });
  }
});
