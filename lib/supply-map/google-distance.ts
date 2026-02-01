/**
 * Google Distance Matrix API – road distance and duration from one origin to many destinations.
 * Requires GOOGLE_MAPS_API_KEY and Distance Matrix API enabled.
 * Falls back to haversine when key is missing or API fails.
 */

const BASE_URL = 'https://maps.googleapis.com/maps/api/distancematrix/json'
const MAX_DESTINATIONS_PER_REQUEST = 25 // stay under 100 elements (1 origin × N destinations)
const MODE = 'driving'
const FETCH_TIMEOUT_MS = 12000 // 12s per request

export interface RoadDistanceResult {
  distanceKm: number
  durationMinutes?: number
}

export interface GoogleDistanceResult {
  results: RoadDistanceResult[] | null
  /** Set when results is null so callers can show why (e.g. REQUEST_DENIED, error_message) */
  error?: string
}

interface DistanceMatrixElement {
  status: string
  distance?: { value: number; text: string }
  duration?: { value: number; text: string }
}

interface DistanceMatrixResponse {
  status: string
  error_message?: string
  rows?: Array<{ elements: DistanceMatrixElement[] }>
}

/**
 * Fetch road distances (and duration) from one origin to many destinations.
 * Returns { results, error } so callers can show why Google wasn't used when results is null.
 */
export async function getRoadDistances(
  origin: { lat: number; lng: number },
  destinations: Array<{ lat: number; lng: number }>
): Promise<GoogleDistanceResult> {
  const key = process.env.GOOGLE_MAPS_API_KEY
  if (!key || destinations.length === 0) {
    return { results: null, error: !key ? 'GOOGLE_MAPS_API_KEY not set' : 'No destinations' }
  }

  const originStr = `${origin.lat},${origin.lng}`
  const allResults: RoadDistanceResult[] = []

  for (let i = 0; i < destinations.length; i += MAX_DESTINATIONS_PER_REQUEST) {
    const chunk = destinations.slice(i, i + MAX_DESTINATIONS_PER_REQUEST)
    const destStr = chunk.map((d) => `${d.lat},${d.lng}`).join('|')
    const params = new URLSearchParams({
      origins: originStr,
      destinations: destStr,
      mode: MODE,
      key,
    })
    const url = `${BASE_URL}?${params.toString()}`

    try {
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)
      const res = await fetch(url, { signal: controller.signal })
      clearTimeout(timeoutId)
      if (!res.ok) {
        const err = `HTTP ${res.status}`
        console.error('[Supply Map] Google Distance Matrix', err)
        return { results: null, error: err }
      }
      const data = (await res.json()) as DistanceMatrixResponse
      if (data.status !== 'OK' || !data.rows?.[0]?.elements) {
        const err = [data.status, data.error_message].filter(Boolean).join(' – ')
        console.error('[Supply Map] Google Distance Matrix:', err)
        return { results: null, error: err }
      }

      for (const el of data.rows[0].elements) {
        if (el.status !== 'OK' || el.distance?.value == null) {
          allResults.push({ distanceKm: 0, durationMinutes: undefined })
          continue
        }
        // Google Distance Matrix: distance.value is always in meters (see API docs)
        const distanceKm = Math.round((el.distance.value / 1000) * 100) / 100
        const durationMinutes =
          el.duration?.value != null ? Math.round(el.duration.value / 60) : undefined
        allResults.push({ distanceKm, durationMinutes })
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err)
      console.error('[Supply Map] Google Distance Matrix request failed:', err)
      return { results: null, error: msg }
    }
  }

  if (allResults.length !== destinations.length) {
    return { results: null, error: 'Result count mismatch' }
  }
  return { results: allResults }
}
