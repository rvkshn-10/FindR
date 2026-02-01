# Firebase App Hosting (full Next.js app)

App Hosting runs your **full** Next.js app (including API routes) on Firebase. You get a live URL that serves Supply Map with search, map, and APIs—not just the static placeholder.

**Requirement:** Firebase project on the **Blaze (pay-as-you-go)** plan. You only pay for what you use; there is a free tier.

---

## Step 1: Open App Hosting in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Select your project **supplymapper** (or the one that has your app).
3. In the left sidebar, open **Build** → **App Hosting**.
4. Click **Get started** (or **Create backend** if you already have one).

---

## Step 2: Create the backend

Follow the wizard:

| Step | What to choose |
|------|-----------------|
| **Region** | Pick one close to your users (e.g. `us-central1`). |
| **Connect GitHub** | Sign in / authorize Firebase to access GitHub if needed. |
| **Repository** | Select **rvkshn-10/FindR** (your repo). |
| **App root directory** | Leave as **`/`** (repo root, where `package.json` is). |
| **Live branch** | **`main`**. |
| **Automatic rollouts** | Leave **on** so each push to `main` deploys. |
| **Backend name** | e.g. **findr** or **supplymapper**. |
| **Firebase web app** | Create new or use existing (your app is already in Firebase config). |

Then click **Finish and deploy**.

---

## Step 3: Wait for the first rollout

- The first deploy can take **about 5 minutes**.
- You’ll get a URL like:  
  `https://findr--supplymapper.us-central1.hosted.app`
- Open that link to see the **full** Supply Map app (search, map, API).

---

## Step 4: (Optional) Environment variables and secrets

Your app can use:

- `OPENAI_API_KEY` – AI ranking
- `GOOGLE_MAPS_API_KEY` – Distance Matrix
- `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` – Maps on the client

**Option A – Firebase Console**

1. In App Hosting, open your backend.
2. Go to **Environment** (or **Configuration**).
3. Add variables and/or secrets there.

**Option B – `apphosting.yaml`**

1. In the project root, run:  
   `firebase init apphosting`  
   to generate `apphosting.yaml`.
2. Add env vars or secret references, for example:

```yaml
env:
  - variable: OPENAI_API_KEY
    secret: openai-api-key   # create in Cloud Secret Manager first
  - variable: GOOGLE_MAPS_API_KEY
    secret: google-maps-api-key
  - variable: NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
    value: "your-key"   # or use secret
```

3. Create secrets (e.g. OpenAI key) with:  
   `firebase apphosting:secrets:set openai-api-key`

Commit `apphosting.yaml` (only references to secrets, not the key values). The next rollout will use these env vars.

---

## Step 5: Deployments after the first one

- With **automatic rollouts** on, every push to **main** triggers a new build and deploy.
- You can watch rollouts and logs under **App Hosting** in the Firebase Console.

---

## Summary

| What | Where |
|------|--------|
| Console | [Firebase Console](https://console.firebase.google.com/) → Build → App Hosting |
| Repo | **rvkshn-10/FindR**, branch **main**, root **/** |
| Live URL | `https://<backend-id>--supplymapper.<region>.hosted.app` |
| Env / secrets | Console or `apphosting.yaml` + `firebase apphosting:secrets:set` |

Once the first rollout finishes, that URL is your full app on Firebase App Hosting.
