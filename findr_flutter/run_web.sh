#!/bin/sh
# Run FindR on web without Chrome debugger (avoids "Timed out finding execution context" and app.dill.incremental.dill errors).
# Open http://localhost:8080 in your browser after it starts.

cd "$(dirname "$0")"

echo "Cleaning and getting packages..."
flutter clean
flutter pub get

echo ""
echo "Starting web server on http://localhost:8080 ..."
echo "Open that URL in your browser. Press Ctrl+C to stop."
echo ""
flutter run -d web-server --web-port=8080
