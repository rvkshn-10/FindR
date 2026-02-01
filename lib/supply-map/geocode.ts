/**
 * Nominatim geocoding wrapper for Supply Map.
 * Converts address/city query to lat/lng.
 * See: https://nominatim.org/release-docs/develop/api/Search/
 */

const NOMINATIM_BASE = 'https://nominatim.openstreetmap.org/search'
const USER_AGENT = 'SupplyMap/1.0 (hackathon app; contact via project repo)'

export interface GeocodeResult {
  lat: number
  lng: number
  displayName: string
}

export async function geocode(query: string): Promise<GeocodeResult | null> {
  const params = new URLSearchParams({
    q: query,
    format: 'json',
    limit: '1',
    addressdetails: '0',
  })
  const url = `${NOMINATIM_BASE}?${params.toString()}`
  const res = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT },
  })
  if (!res.ok) return null
  const data = (await res.json()) as Array<{ lat: string; lon: string; display_name: string }>
  if (!data?.length) return null
  const first = data[0]
  return {
    lat: parseFloat(first.lat),
    lng: parseFloat(first.lon),
    displayName: first.display_name ?? '',
  }
}
