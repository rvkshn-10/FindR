const fs = require("fs");
const path = require("path");

const outDir = path.join(__dirname, "..", "out");
const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>FindR – Supply Map</title>
</head>
<body>
  <h1>FindR</h1>
  <p>Supply Map: find items nearby. The full app (with search and API) runs on a Node server.</p>
  <p>Deploy the full app with <a href="https://vercel.com">Vercel</a> or <a href="https://firebase.google.com/docs/app-hosting">Firebase App Hosting</a>.</p>
</body>
</html>
`;

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "index.html"), html);
console.log("Created out/index.html for Firebase Hosting.");
