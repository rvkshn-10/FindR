#!/bin/sh
# Build Flutter web (release) and serve it locally. Use this if the dev server
# (run_web.sh / flutter run -d web-server) shows a white page but deployed app works.
# Open http://localhost:8080 in Safari or your browser.

cd "$(dirname "$0")"

echo "Building release web app..."
flutter build web
if [ $? -ne 0 ]; then
  echo "Build failed."
  exit 1
fi

echo ""
echo "Serving build/web at http://localhost:8080"
echo "Open that URL in your browser. Press Ctrl+C to stop."
echo ""

cd build/web
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server 8080
elif command -v python >/dev/null 2>&1; then
  exec python -m http.server 8080 2>/dev/null || exec python -m SimpleHTTPServer 8080
else
  echo "Need Python. Or run: cd build/web && npx serve -p 8080"
  exit 1
fi
