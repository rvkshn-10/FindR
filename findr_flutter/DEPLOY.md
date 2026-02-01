# Deploy FindR to GitHub and Firebase

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

## Summary

| Goal           | Where to run        | Commands |
|----------------|---------------------|----------|
| Push to GitHub | FindR repo root     | `git add -A && git commit -m "..." && git push origin main` |
| Deploy to Firebase | `findr_flutter/` | `firebase use --add` (once), then `flutter build web && firebase deploy` |
