/**
 * Overpass API wrapper for Supply Map.
 * Fetches nearby shops and amenities (POIs) by radius.
 * See: https://wiki.openstreetmap.org/wiki/Overpass_API
 */

import { haversineKm } from './distance'

const OVERPASS_BASE = 'https://overpass-api.de/api/interpreter'
const DEFAULT_RADIUS_M = 5000 // 5 km
const FETCH_TIMEOUT_MS = 20000 // 20s

export interface OverpassStore {
  id: string
  name: string
  lat: number
  lng: number
  address: string
  distanceKm: number
  osmTags?: Record<string, string>
}

function getDisplayName(element: OverpassElement): string {
  return element.tags?.name ?? element.tags?.brand ?? 'Unnamed store'
}

function getAddress(element: OverpassElement): string {
  const t = element.tags
  if (!t) return ''
  const parts = [
    t['addr:street'],
    t['addr:housenumber'] ? `${t['addr:housenumber']}` : null,
    t['addr:city'] ?? t['addr:town'] ?? t['addr:village'],
    t['addr:state'],
    t['addr:postcode'],
  ].filter(Boolean)
  return parts.join(', ') || ''
}

interface OverpassElement {
  type: string
  id: number
  lat?: number
  lon?: number
  center?: { lat: number; lon: number }
  tags?: Record<string, string>
}

interface OverpassResponse {
  elements: OverpassElement[]
}

export async function fetchNearbyStores(
  lat: number,
  lng: number,
  radiusM: number = DEFAULT_RADIUS_M
): Promise<OverpassStore[]> {
  // Query shops and key amenities (supermarket, convenience, pharmacy, etc.)
  const query = `
[out:json][timeout:12];
(
  nwr["shop"](around:${radiusM},${lat},${lng});
  nwr["amenity"~"marketplace|pharmacy|fuel"](around:${radiusM},${lat},${lng});
);
out center;
  `.trim()

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)
  const res = await fetch(OVERPASS_BASE, {
    method: 'POST',
    body: query,
    headers: { 'Content-Type': 'text/plain' },
    signal: controller.signal,
  })
  clearTimeout(timeoutId)
  if (!res.ok) throw new Error(`Overpass request failed: ${res.status}`)
  const data = (await res.json()) as OverpassResponse
  const elements = data.elements ?? []

  const stores: OverpassStore[] = []
  const seen = new Set<string>()

  for (const el of elements) {
    const elLat = el.lat ?? el.center?.lat
    const elLng = el.lon ?? el.center?.lon
    if (elLat == null || elLng == null) continue
    const id = `${el.type}/${el.id}`
    if (seen.has(id)) continue
    seen.add(id)
    const name = getDisplayName(el)
    const address = getAddress(el)
    const distanceKm = haversineKm(lat, lng, elLat, elLng)
    stores.push({
      id,
      name,
      lat: elLat,
      lng: elLng,
      address,
      distanceKm: Math.round(distanceKm * 100) / 100,
      osmTags: el.tags,
    })
  }

  stores.sort((a, b) => a.distanceKm - b.distanceKm)
  return stores
}
