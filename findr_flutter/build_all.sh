#!/bin/sh
# Build FindR for all platforms (web, Android APK, iOS).
# Output: build/web/, build/app/outputs/flutter-apk/, ios/build (or Xcode archive).

cd "$(dirname "$0")"

echo "Building for web..."
flutter build web

echo ""
echo "Building for Android (APK)..."
flutter build apk

echo ""
echo "Building for iOS (requires Xcode)..."
flutter build ios

echo ""
echo "Done. Outputs:"
echo "  Web:    build/web/"
echo "  Android: build/app/outputs/flutter-apk/app-release.apk"
echo "  iOS:    Open ios/Runner.xcworkspace in Xcode, then Product > Archive"
