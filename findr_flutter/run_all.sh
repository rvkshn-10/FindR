#!/bin/sh
# Run FindR on web, Android, and iOS (each in background).
# Requires: Flutter SDK. For iOS: Xcode. For Android: emulator or device.
# Don't have Xcode? Comment out the "flutter run -d ios" block below.
# Stop with Ctrl+C.

cd "$(dirname "$0")"

echo "Starting on web (Chrome)..."
flutter run -d chrome &
PID1=$!

echo "Starting on Android..."
flutter run -d android &
PID2=$!

echo "Starting on iOS (needs Xcode)..."
flutter run -d ios &
PID3=$!

echo ""
echo "Running on all. Press Ctrl+C to stop."
trap "kill $PID1 $PID2 $PID3 2>/dev/null; exit" INT TERM
wait
