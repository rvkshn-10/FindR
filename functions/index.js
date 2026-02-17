const functions = require("firebase-functions");
const fetch = require("node-fetch");

// SerpApi key (same as in the Flutter app).
const SERPAPI_KEY =
  "3c98c1ad2a12891b404f04b5183fc31781b0fd08aed9da9a2d5a21cb296426c0";

/**
 * Thin proxy for SerpApi.
 *
 * Accepts GET requests with the same query-string parameters you'd send
 * to serpapi.com/search.json. Forwards the request server-side (no CORS
 * issues) and returns the JSON response to the Flutter web app.
 *
 * Example:  GET /api/serpapi?engine=google_maps&q=batteries+near+me&ll=@37,-122,14z
 */
exports.serpapi = functions.https.onRequest(async (req, res) => {
  // Allow requests from our hosting domain.
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Accept");

  // Handle preflight.
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    // Forward all query params to SerpApi, injecting the API key.
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
