# Step-by-step: Connect FindR Flutter to your existing Firebase project (FlutterFire CLI)

Do these steps in order. You need: **Node.js** (for Firebase CLI), **Flutter SDK**, and your **Firebase project** already created.

---

## Step 1: Install Firebase CLI (if you don’t have it)

1. Open **Terminal** (or your command line).
2. Run:
   ```bash
   npm install -g firebase-tools
   ```
3. If you get a permission error, try:
   ```bash
   sudo npm install -g firebase-tools
   ```
4. Check it worked:
   ```bash
   firebase --version
   ```
   You should see a version number (e.g. `13.0.0`).

---

## Step 2: Log in to Firebase

1. In Terminal, run:
   ```bash
   firebase login
   ```
2. A browser window will open.
3. Sign in with the **same Google account** you use for your existing Firebase project.
4. Click **Allow** so the Firebase CLI can access your account.
5. When you see “Success! Logged in as …” in the browser, you can close it.
6. Back in Terminal you should see something like: “Success! Logged in as your@email.com”.

---

## Step 3: Install FlutterFire CLI (one time)

1. In Terminal, run:
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Make sure the Dart global bin folder is on your PATH.  
   If `flutterfire` is not found in the next step, run this and then try again (use your shell; below is for bash/zsh):
   ```bash
   export PATH="$PATH:$HOME/.pub-cache/bin"
   ```
   To make that permanent, add that line to `~/.zshrc` or `~/.bash_profile` and run `source ~/.zshrc` (or restart the terminal).

---

## Step 4: Go to your FindR Flutter project folder

1. In Terminal, go to your **FindR** repo folder.
2. Then go into the Flutter app folder:
   ```bash
   cd FindR/findr_flutter
   ```
   (If you’re already inside the FindR repo, use: `cd findr_flutter`.)

3. Check you’re in the right place:
   ```bash
   ls pubspec.yaml lib/main.dart
   ```
   You should see both files listed.

---

## Step 5: Run FlutterFire configure

1. Make sure the Dart global bin folder is on your PATH (you may have done this in Step 3). Run:
   ```bash
   export PATH="$PATH:$HOME/.pub-cache/bin"
   ```
   (If you already added this to `~/.zshrc` or `~/.bash_profile`, open a **new** terminal so it’s applied.)

2. From inside **findr_flutter**, run:
   ```bash
   flutterfire configure
   ```
   **Do not** use `dart run flutterfire_cli:flutterfire configure`; use the global command `flutterfire configure` after activating in Step 3.

2. **Select your Firebase project**
   - You’ll see a list of projects (e.g. “1. my-project (my-project)”).
   - Use the **arrow keys** to move to your **existing** project.
   - Press **Enter** to select it.
   - Do **not** choose “Create a new project” unless you want a second project.

3. **Select platforms**
   - You’ll see something like: “Which platforms should your configuration support?”
   - Use **space** to turn options on/off:
     - **web** – turn on if you use `flutter run -d web-server` or Chrome.
     - **android** – turn on if you build/run on Android.
     - **ios** – turn on if you build/run on iOS (needs Xcode).
   - Move with arrow keys, space to toggle, **Enter** when done.

4. Wait for it to finish.
   - It will create/overwrite `lib/firebase_options.dart`.
   - For Android it will add/update `android/app/google-services.json`.
   - For iOS it will add/update `ios/Runner/GoogleService-Info.plist` (and may ask you to open Xcode to add the file to the target).

5. When it says “Configuration complete” (or similar), you’re done with this step.

---

## Step 6: Add a Web app in Firebase (if you use web and it asked for it)

1. If the CLI said something like “No web app found”, it may have given you a link or told you to add a web app.
2. Open [Firebase Console](https://console.firebase.google.com/).
3. Select the **same project** you chose in Step 5.
4. On the project overview, click the **Web** icon: **</>** (“Add app” or “Web”).
5. Register the app:
   - **App nickname:** e.g. `FindR Web`.
   - **Firebase Hosting:** optional (you can leave it unchecked for now).
6. Click **Register app**.
7. You can skip copying the config snippet; FlutterFire already wrote it into `lib/firebase_options.dart`.
8. Go back to Terminal and run **Step 5 again** so it picks up the new web app:
   ```bash
   flutterfire configure
   ```
   Select the same project, enable **web** again, then finish.

---

## Step 7: Get Flutter dependencies and run the app

1. In Terminal, still inside **findr_flutter**, run:
   ```bash
   flutter pub get
   ```

2. Run the app on web:
   ```bash
   flutter run -d web-server
   ```

3. When it prints a URL (e.g. `http://localhost:12345`), open that URL in your browser.

4. The app should start and Firebase will initialize using your existing project (no errors in the console about “Firebase init failed” if everything is set up correctly).

---

## Step 8: Confirm Firebase is connected

1. In the app, use it as usual (e.g. search, find nearby).
2. In the browser **Developer Tools** (e.g. right‑click → Inspect → **Console**), you should **not** see: “Firebase init failed (run flutterfire configure)”.
3. (Optional) In [Firebase Console](https://console.firebase.google.com/) → your project → **Authentication** or **Firestore** (or whatever you use), you can later add sign-in or data and see that it’s the same project.

---

## Quick recap

| Step | What you do |
|------|------------------|
| 1 | `npm install -g firebase-tools` |
| 2 | `firebase login` (browser, same Google as Firebase) |
| 3 | `dart pub global activate flutterfire_cli` (and fix PATH if needed) |
| 4 | `cd FindR/findr_flutter` (or `cd findr_flutter`) |
| 5 | `flutterfire configure` (after Step 3 and PATH) → choose **existing project** → choose platforms (web / android / ios) |
| 6 | If you use web and CLI said “no web app”: add Web app in Firebase Console, then run Step 5 again |
| 7 | `flutter pub get` then `flutter run -d web-server` |
| 8 | Open the URL in the browser and check there’s no Firebase init error |

---

## If something goes wrong

- **“firebase: command not found”**  
  Run Step 1 again; if it still fails, use `sudo npm install -g firebase-tools` or install Node.js first.

- **“flutterfire: command not found”** or **“Could not find package flutterfire_cli”**  
  Do **not** use `dart run flutterfire_cli:flutterfire configure`. Use the global command instead:
  1. Run: `dart pub global activate flutterfire_cli`
  2. Add to PATH: `export PATH="$PATH:$HOME/.pub-cache/bin"` (and add that line to `~/.zshrc` or `~/.bash_profile`)
  3. Open a **new** terminal (or run `source ~/.zshrc`)
  4. From **findr_flutter**, run: `flutterfire configure`

- **“No Firebase project found”**  
  Make sure you did Step 2 (`firebase login`) with the same Google account that owns the Firebase project.

- **“No web app found”**  
  Do Step 6: add a Web app in Firebase Console for that project, then run Step 5 again.

- **App still shows “Firebase init failed”**  
  Make sure you ran Step 5 from inside **findr_flutter** and that `lib/firebase_options.dart` was updated (open the file and check that `apiKey` and `projectId` are real values, not placeholders).
