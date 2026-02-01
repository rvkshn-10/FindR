# Complete the Dart/Flutter conversion and run the app

Follow these steps in order. You need the **Flutter SDK** installed ([install guide](https://docs.flutter.dev/get-started/install)).

---

## Minimal setup (no Android, Xcode, or Chrome)

If `flutter doctor` shows errors for Android, Xcode, or Chrome, you can **still run the app on web** without fixing those:

1. **Open the Flutter project:** `cd findr_flutter`
2. **Create platform folders (first time only):** `flutter create . --project-name findr_flutter`
3. **Get dependencies:** `flutter pub get`
4. **Run the web server (no Chrome needed):**
   ```bash
   flutter run -d web-server
   ```
5. **Open the URL** it prints (e.g. `http://localhost:12345`) in **Safari**, **Firefox**, **Edge**, or any browser.

That’s it. You don’t need Android Studio, Xcode, or Chrome for this.

---

## 1. Open the Flutter project

```bash
cd FindR/findr_flutter
```

(Or `cd findr_flutter` if you’re already in the FindR repo.)

---

## 2. Generate platform folders (required first time)

The Dart code is in place, but Flutter needs platform folders (Android, iOS, web). Run:

```bash
flutter create . --project-name findr_flutter
```

- This adds `android/`, `ios/`, `web/` (and optionally others) **without** overwriting your `lib/` or `pubspec.yaml`.
- If Flutter asks about existing files, choose to **keep** your existing files.

---

## 3. Install dependencies

```bash
flutter pub get
```

---

## 4. Run the app

**Web (easiest to try first):**

```bash
flutter run -d chrome
```

Or:

```bash
flutter run -d web-server
```

Then open the URL it prints (e.g. http://localhost:xxxxx).

**Android:**

```bash
flutter run -d android
```

(Requires an emulator or device. Location permission is needed; see step 5.)

**iOS (macOS only):**

```bash
flutter run -d ios
```

(Requires Xcode and simulator/device. Location permission is needed; see step 5.)

---

## 5. Location permission (Android / iOS)

For “Use my location” to work on device/emulator:

**Android** – in `android/app/src/main/AndroidManifest.xml` inside `<manifest>` add:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS** – in `ios/Runner/Info.plist` add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FindR uses your location to find nearby stores.</string>
```

Then run again (e.g. `flutter run -d android` or `flutter run -d ios`).

---

## 6. Run on all platforms (web + Android + iOS)

**Option A – Separate terminals (recommended)**  
Open 3 terminals in `findr_flutter` and run:

- Terminal 1: `flutter run -d chrome`
- Terminal 2: `flutter run -d android`
- Terminal 3: `flutter run -d ios` (requires Xcode)

**Option B – One script**  
From `findr_flutter`:

```bash
chmod +x run_all.sh
./run_all.sh
```

This starts web, Android, and iOS in the background. If you don’t have Xcode, edit `run_all.sh` and comment out the `flutter run -d ios` block (or that part will error and you can ignore it).

**Build for all (outputs for deploy):**

```bash
chmod +x build_all.sh
./build_all.sh
```

Produces: `build/web/`, Android APK, and iOS build (then archive in Xcode for App Store).

---

## 7. Check that it works

1. Open the app (web or device).
2. Enter an item (e.g. “milk” or “batteries”).
3. Leave “Use my location” checked (or enter a city/address).
4. Tap **Find nearby**.
5. You should see a map and a list of nearby stores; tap **Directions** to open Google Maps.

---

## 8. Troubleshooting

| Issue | What to do |
|-------|------------|
| `flutter: command not found` | Install Flutter and add it to your PATH ([install](https://docs.flutter.dev/get-started/install)). |
| `No supported devices connected` | For web: run `flutter run -d chrome`. For Android: start an emulator or connect a device. |
| Overpass / OSRM errors | The app uses public APIs (no key). If you see timeouts, try again or another location. |
| Blank white screen on web | Run `flutter pub get` and `flutter run -d chrome` again; check the browser console for errors. |
| `can't find xcodebuild` | You're building for iOS but Xcode isn't set up. Run **web only**: `flutter run -d web-server` and open the URL in Safari. Or install Xcode and run `xcode-select -s /Applications/Xcode.app/Contents/Developer`. |
| **Android toolchain – Unable to locate Android SDK** | You don't need this for web. Run `flutter run -d web-server`. To fix for Android later: install [Android Studio](https://developer.android.com/studio) and let it install the SDK. |
| **Xcode – incomplete / CocoaPods** | You don't need this for web. Run `flutter run -d web-server`. To fix for iOS later: install Xcode from the App Store, run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, then `sudo gem install cocoapods`. |
| **Chrome – Cannot find Chrome executable** | Use **web-server** instead of Chrome: `flutter run -d web-server`, then open the printed URL in Safari (or any browser). Or if Chrome is elsewhere: `export CHROME_EXECUTABLE="/path/to/Chrome"` then `flutter run -d chrome`. |

---

## Summary

1. `cd findr_flutter`
2. `flutter create . --project-name findr_flutter`
3. `flutter pub get`
4. `flutter run -d chrome` (or `android` / `ios`)
5. Add location permissions for Android/iOS if you use “Use my location” on device.

After that, the app is fully Dart/Flutter and running.
