# Deploy FindR to GitHub and Firebase

## Automatic deployment (recommended)

- **GitHub:** Your existing post-commit hook pushes to GitHub after every commit.
- **Firebase:** Every push to `main` triggers a GitHub Action that builds the Flutter web app and deploys it to Firebase Hosting.

**One-time setup for automatic Firebase deploy:** Add a GitHub secret named `FIREBASE_TOKEN`:

1. On your machine, run:  
   `firebase login:ci`  
   (Log in in the browser if prompted, then copy the token it prints.)
2. In GitHub: repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
3. Name: `FIREBASE_TOKEN`, Value: paste the token from step 1.

After that, every push to `main` will deploy the Flutter web app to Firebase Hosting automatically.

---

## 1. Push to GitHub

From the **FindR** repo root:

```bash
cd FindR
git add -A
git status   # check what will be committed
git commit -m "Add Flutter app, Firebase config, deploy setup"
git push origin main
```

Use your GitHub auth (HTTPS token or SSH) if prompted.

---

## 2. Deploy to Firebase Hosting (web app)

From the **FindR** repo, in the Flutter project folder:

```bash
cd findr_flutter
```

**First time only – link Firebase project:**

```bash
firebase use --add
```

- Select your **existing** Firebase project from the list.
- Choose an alias (e.g. **default**) and press Enter.

**Build and deploy:**

```bash
flutter build web
firebase deploy
```

When it finishes, it will print a **Hosting URL** (e.g. `https://your-project-id.web.app`). Open that URL to see your app live.

---

## 3. Later deploys

**GitHub:** same as step 1 – `git add`, `git commit`, `git push origin main`.

**Firebase:** from `findr_flutter`:

```bash
flutter build web
firebase deploy
```

---

## Auto-deploy on save (optional)

- **Option A – Run on Save (Cursor/VS Code):** Install the [Run on Save](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave) extension. The repo’s `.vscode/settings.json` is already set so that saving any file under `findr_flutter/lib/`, `findr_flutter/web/`, or `findr_flutter/pubspec.yaml` runs `npm run deploy:firebase:flutter` and deploys to Firebase.
- **Option B – Watch script:** From the repo root, run `npm run watch:deploy` and leave the terminal open. Any change under `findr_flutter/lib`, `findr_flutter/web`, or `findr_flutter/pubspec.yaml` will trigger a build and deploy.

---

## Summary

| Goal           | How |
|----------------|-----|
| Push to GitHub | Post-commit hook pushes automatically after each commit. |
| Deploy to Firebase | GitHub Action runs on every push to `main` (set `FIREBASE_TOKEN` secret once). |
| Manual Firebase deploy | From repo root: `npm run deploy:firebase:flutter` |
| Deploy on every save | Install Run on Save extension (see above) or run `npm run watch:deploy`. |
