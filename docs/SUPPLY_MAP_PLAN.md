# Supply Map – Refined Build Plan

**Goal:** Help users quickly find where to get items nearby (stores, products, essentials) and surface the best option based on convenience, estimated availability, and—when data exists—price.

---

## 1. Core Features

### Item Search
- User enters the product or item they want (e.g. "AA batteries", "milk").
- **Important:** OpenStreetMap does not index by product. The app maps the user's search to **store types/categories** (e.g. "batteries" → supermarkets, electronics, convenience), then finds those types of stores nearby.
- Optional filters: **distance** (radius), **category**.  
- **Price range:** Only feasible if you have another data source or crowd-sourced data; omit or label as "future" for MVP.

### Nearby Stores Display
- Interactive map (Leaflet) with OpenStreetMap tiles.
- **Data source for "nearby stores":** Use the **Overpass API** (OSM query API) to fetch nodes/ways by shop type and bounding box. Use **Nominatim** for geocoding (address ↔ lat/lng) and reverse geocoding (lat/lng → address).
- Pins for each store; click → popup/side panel with name, address, distance from user.

### Best Option Highlight
- AI ranks stores using:
  - **Distance** (known).
  - **Estimated availability** (heuristic: e.g. large retailers more likely to carry common items; no real inventory from OSM).
  - **Price** only if you have that data (crowd-sourced or external); otherwise omit from ranking.
- One store is highlighted as "best choice" on map and in the list.

### Alternative Suggestions
- If the item is unlikely to be found at nearby stores, AI can suggest:
  - Substitute items.
  - Nearby alternatives (e.g. next-closest cluster of stores).

### Quick Directions
- Per store: link to Google Maps or OSRM for turn-by-turn directions.

### Optional: Crowd-Sourced Updates
- Users can report "in stock" / "out of stock" (or "available" / "not available") to improve future recommendations. Stored in your own backend, not in OSM.

---

## 2. Tech Stack (Hackathon-Friendly)

| Layer        | Choice                          | Notes                                      |
|-------------|----------------------------------|--------------------------------------------|
| Frontend    | React / Next.js + Leaflet        | Leaflet renders OSM tiles and markers      |
| Geocoding   | Nominatim API                    | Address ↔ coordinates, reverse geocoding   |
| Store data  | Overpass API                     | Query OSM by shop type + bbox/radius       |
| Map tiles   | OpenStreetMap (e.g. default OSM) | Standard tile layer                        |
| Backend     | Next.js API routes (optional)    | AI ranking, item→category mapping, feedback|
| AI          | OpenAI (or other LLM)            | Ranking, substitutes, 1–2 sentence summary|
| Hosting     | Vercel / Netlify                 | Fast deploy                                |

**Clarification:** Nominatim is for **geocoding**. Overpass is for **querying OSM features** (e.g. "all shops in this area"). Both are needed; they are not interchangeable.

---

## 3. Data Flow

1. **User input:** Item name + optional filters (distance, category).
2. **Location:**
   - Prefer **auto-detect** (browser geolocation).
   - Fallback: **manual** city/address → geocode with Nominatim.
3. **Item → store type mapping:**
   - Map search term to OSM shop/amenity types (e.g. "supermarket", "convenience", "electronics").  
   - Use a small **mapping table or AI** (e.g. "milk" → supermarkets, convenience).
4. **Fetch stores:**
   - **Overpass API** query: store types + user's location (bbox or radius) → list of nodes with coordinates, name, tags.
5. **AI ranking:**
   - Input: list of stores + distances (+ optional crowd-sourced availability/price).
   - Output: ranked list + "best" store + 1–2 sentence summary.
6. **Map + list:**
   - Leaflet: pins for each store; highlight "best" store.
   - List view: same order, with AI summary for the best option.
7. **Optional feedback:**
   - User submits "in stock" / "out of stock" (and optionally price) → your API/database → used in future ranking.

---

## 4. Data Sources & Limitations

| Data              | Source        | Limitation                                      |
|-------------------|---------------|--------------------------------------------------|
| Store locations   | OSM (Overpass)| No product-level inventory; store type only      |
| Geocoding         | Nominatim     | Rate limits; use responsibly                     |
| Distance          | Computed      | Straight-line or use a routing service for time  |
| Availability      | Heuristic/AI  | Inferred, not real-time inventory                |
| Price             | Not in OSM    | Only via crowd-sourcing or external APIs         |
| Open/closed hours | OSM (optional)| Sometimes in tags; not always present            |

Set expectations in the UI: e.g. "We show stores that typically carry this kind of item" and "Availability is estimated."

---

## 5. UX / UI Flow

- **Landing:** Large search bar ("What do you need?"). Optional toggles: category, max distance. (Omit price filter unless you have data.)
- **Search results:** Map (pins) + list; "best" store clearly highlighted (pin + list).
- **Store detail:** Click store → address, distance, link to directions (Google Maps or OSRM).
- **No / few results:** Message + AI-suggested substitutes or nearby alternatives.
- **Optional:** "Mark in stock / out of stock" for crowd-sourcing.

Consider **mobile-first** and **permission flows** (location denied → prompt for manual address).

---

## 6. AI Integration

- **Prompt 1 – Ranking:** Given user location, item, and list of stores (with distance and type), rank by distance, estimated availability, and convenience. No fabricated prices.
- **Prompt 2 – Substitutes:** If item is unlikely at nearby stores, suggest substitute items or next-best store clusters.
- **Prompt 3 – Summary:** One or two sentences for the best option, e.g. "Walmart is closest and typically carries this; about 10 min drive. Local hardware store is 20 min but often has better selection."

**Rule:** AI does not invent prices or availability; it reasons over distance, store type, and any data you provide (e.g. crowd-sourced flags).

---

## 7. Hackathon MVP Scope (e.g. 48h)

| Phase | Scope |
|-------|--------|
| **1 – Minimal map search** | (1) Geocode user location (or manual address). (2) Map item → store types. (3) Overpass query for those types near location. (4) Leaflet map with pins; popup: name, address, distance. |
| **2 – AI ranking** | Send store list + distances to LLM; get top 3 and "best" store; highlight on map and list; show short AI summary. |
| **3 – Alternatives** | If no/few stores: AI suggests substitute items or "try searching X" / "expand radius". |
| **4 – Optional crowdsourcing** | Simple "in stock / out of stock" (and optionally price) per store; store in your DB; feed into ranking when present. |

**Edge cases to handle:** Location denied; Overpass/Nominatim down or rate-limited; zero results (clear message + suggestions).

---

## 8. Optional Stretch

- Travel time by mode (walk/drive) via OSRM or similar.
- Filter by open/closed (if OSM hours available).
- Integrate reviews (e.g. external API).
- "Trending" or "rare finds" (would need your own or external data).

---

## 9. Demo Strategy for Judges

1. Search for a common item (e.g. "AA batteries", "milk").
2. Show map populating with stores and a clear "best" option with AI explanation.
3. Click store → directions to show end-to-end usefulness.
4. Optional: "Item not in stock? Here's a substitute" flow.
5. **Impact:** "We save time and reduce frustration for everyday shopping by combining maps and AI—no fake prices, clear expectations."

---

## 10. Summary of Fixes vs. Original Plan

- **Data roles:** Nominatim = geocoding; Overpass = nearby stores by type. Both specified.
- **Item search:** Explicit "item → store type" step; no assumption that OSM has product-level data.
- **Price:** Only when you have data; no price filter in MVP unless you add a source.
- **Availability:** Framed as heuristic/estimated, not real-time inventory.
- **Edge cases:** Location denied, API errors, zero results called out.
- **Scope:** Phases and data sources aligned so the MVP is buildable in a hackathon.

Use this as the single source of truth for scope and implementation decisions.
