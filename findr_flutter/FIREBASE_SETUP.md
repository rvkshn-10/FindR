# Connect FindR Flutter to Firebase

The app already has **Firebase Core** and initialization in code. To connect it to **your** Firebase project, use one of the two options below.

---

## Option A: FlutterFire CLI (recommended)

This generates `lib/firebase_options.dart` and (for Android/iOS) adds config files from your Firebase project.

### 1. Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** (or use an existing project).
3. Follow the steps (name, Google Analytics if you want).
4. When the project is ready, stay on the project overview.

### 2. Register your app in Firebase

- **Web:** In the project overview, click the **Web** icon (`</>`), register the app with a nickname (e.g. "FindR Web"), then copy the `firebaseConfig` object (you’ll use it in step 4 if you skip the CLI).
- **Android:** Click **Add app** → Android. Use package name **`com.findr.findr_flutter`** (or the one in `android/app/build.gradle`). Download `google-services.json` and put it in `android/app/`.
- **iOS:** Click **Add app** → iOS. Use bundle ID **`com.findr.findrFlutter`** (or the one in Xcode). Download `GoogleService-Info.plist` and add it to `ios/Runner` in Xcode.

### 3. Install Firebase CLI and FlutterFire CLI

```bash
# Firebase CLI (one time)
npm install -g firebase-tools

# Log in to Firebase
firebase login

# FlutterFire CLI (one time)
dart pub global activate flutterfire_cli
```

### 4. Generate config in your Flutter project

From the **FindR repo**, in the Flutter project folder:

```bash
cd findr_flutter
flutterfire configure
```
(If `flutterfire` is not found: run `dart pub global activate flutterfire_cli`, then add `export PATH="$PATH:$HOME/.pub-cache/bin"` and open a new terminal.)

- Select your Firebase project.
- Select the platforms you use (web, Android, iOS).
- This overwrites `lib/firebase_options.dart` with your real config and adds `google-services.json` / `GoogleService-Info.plist` where needed.

### 5. Run the app

```bash
flutter pub get
flutter run -d web-server
```

Firebase is now connected. You can add Auth, Firestore, etc. in code and use them.

---

## Option B: Manual config (web only)

If you only care about **web** and don’t want to use the CLI:

### 1. Create a Firebase project and add a web app

1. [Firebase Console](https://console.firebase.google.com/) → your project (or create one).
2. Add a **Web** app (`</>`), get the `firebaseConfig` object.

### 2. Edit `lib/firebase_options.dart`

Replace the **`web`** constant with your config, for example:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIza...',
  appId: '1:123456789:web:abc...',
  messagingSenderId: '123456789',
  projectId: 'your-project-id',
  authDomain: 'your-project-id.firebaseapp.com',
  storageBucket: 'your-project-id.appspot.com',
);
```

Leave `android` and `ios` as they are if you’re not using them.

### 3. Run the app

```bash
flutter pub get
flutter run -d web-server
```

---

## After Firebase is connected

- The app will call `Firebase.initializeApp(...)` on startup (see `lib/main.dart`).
- To add **Auth** (sign-in): add `firebase_auth` to `pubspec.yaml` and use it in your screens.
- To add **Firestore** (database): add `cloud_firestore` to `pubspec.yaml` and use it in your services/screens.
- To add **Realtime Database**: add `firebase_database` to `pubspec.yaml`.

If you tell me what you want next (e.g. “sign-in with Google” or “save favorites in Firestore”), I can give exact code steps.
