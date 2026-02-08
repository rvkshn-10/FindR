#!/bin/sh
# Run FindR on web without Chrome debugger (avoids "Timed out finding execution context" and app.dill.incremental.dill errors).
# Open http://localhost:8081 in your browser after it starts.
# (Uses 8081 so it doesn't conflict with serve_release_web.sh on 8080 or other tools.)

cd "$(dirname "$0")"

echo "Cleaning and getting packages..."
flutter clean
flutter pub get

echo ""
echo "Starting web server on http://localhost:8081 ..."
echo "Open that URL in your browser. Press Ctrl+C to stop."
echo ""
flutter run -d web-server --web-port=8081
