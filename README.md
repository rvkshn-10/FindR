# FindR

Find items nearby – stores, products, and the best option for you. Supply Map feature: search by item + location, see nearby stores on a map, get AI-ranked best option and directions.

## Setup

```bash
npm install
cp .env.example .env.local   # optional: add OPENAI_API_KEY, GOOGLE_MAPS_API_KEY, NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
npm run dev
```

Open [http://localhost:3000](http://localhost:3000); the app redirects to `/supply-map`.

## Optional env (see `.env.example`)

- **OPENAI_API_KEY** – AI ranking and summary for best option; suggest alternatives when no results.
- **GOOGLE_MAPS_API_KEY** – Road distances (Distance Matrix API).
- **NEXT_PUBLIC_GOOGLE_MAPS_API_KEY** – Use Google Maps for the results map (Maps JavaScript API). Can be the same key if both APIs are enabled.

Without Google keys, road distances use OSRM (free) and the map uses OpenStreetMap/Leaflet.

## Static export (Firebase Hosting)

The app is built as a **static export** so you can deploy to **Firebase Hosting** (free) with the full Supply Map UI:

- **Geocode** – client-side via Nominatim (OpenStreetMap).
- **Search** – client-side: Overpass (nearby stores) + OSRM (road distances). No Google Maps API or OpenAI on the server.
- **Feedback/prices** – stored in the browser (localStorage).
- **Map** – Leaflet/OpenStreetMap by default; set `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` at build time to use Google Maps.

Deploy:

```bash
npm run build        # produces out/
firebase deploy
```

Or: `npm run deploy:firebase`

The previous API routes are kept in **`api.backup/`** for reference (not used in the static build).

## Firebase (Analytics + Hosting)

Firebase is wired for **Analytics** (client-side) and **Hosting** (optional deploy).

- Config lives in `lib/firebase.ts`; analytics is initialized in the browser via `components/FirebaseAnalytics.tsx`.

## Docs

- [Supply Map build plan](./docs/SUPPLY_MAP_PLAN.md)
