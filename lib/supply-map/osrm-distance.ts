/**
 * OSRM Table API – road distance and duration (driving) from one origin to many destinations.
 * Free, no API key. Uses public demo server: router.project-osrm.org
 * Coordinates: longitude,latitude (OSRM order).
 */

const OSRM_BASE = 'https://router.project-osrm.org/table/v1/driving'
const MAX_DESTINATIONS_PER_REQUEST = 25
const FETCH_TIMEOUT_MS = 12000 // 12s per request

export interface RoadDistanceResult {
  distanceKm: number
  durationMinutes?: number
}

interface OSRMTableResponse {
  code: string
  durations?: number[][]
  distances?: number[][]
}

async function fetchOsrmChunk(
  origin: { lat: number; lng: number },
  chunk: Array<{ lat: number; lng: number }>
): Promise<RoadDistanceResult[] | null> {
  const coords = [
    `${origin.lng},${origin.lat}`,
    ...chunk.map((d) => `${d.lng},${d.lat}`),
  ].join(';')
  const params = new URLSearchParams({
    sources: '0',
    destinations: Array.from({ length: chunk.length }, (_, i) => i + 1).join(';'),
    annotations: 'duration,distance',
  })
  const url = `${OSRM_BASE}/${coords}?${params.toString()}`

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)
  const res = await fetch(url, { signal: controller.signal })
  clearTimeout(timeoutId)
  if (!res.ok) return null
  const data = (await res.json()) as OSRMTableResponse
  if (data.code !== 'Ok' || !data.durations?.[0] || !data.distances?.[0]) return null

  const durations = data.durations[0]
  const distances = data.distances[0]
  if (durations.length !== chunk.length || distances.length !== chunk.length) return null

  // OSRM Table API: durations in seconds, distances in meters (row = source, col = destination).
  // When no route is found, distance can be null but duration may still be present (or both null).
  return durations.map((durationSec, i) => {
    const distMeters = distances[i]
    const distanceKm = distMeters != null && Number.isFinite(distMeters)
      ? Math.round((distMeters / 1000) * 100) / 100
      : 0
    const durationMinutes =
      durationSec != null && Number.isFinite(durationSec) ? Math.round(durationSec / 60) : undefined
    return { distanceKm, durationMinutes }
  })
}

/**
 * Fetch road distances (and duration) from one origin to many destinations via OSRM.
 * Free, no API key. Returns null if request fails or response is invalid.
 */
export async function getRoadDistancesOSRM(
  origin: { lat: number; lng: number },
  destinations: Array<{ lat: number; lng: number }>
): Promise<RoadDistanceResult[] | null> {
  if (destinations.length === 0) return null

  const allResults: RoadDistanceResult[] = []
  for (let i = 0; i < destinations.length; i += MAX_DESTINATIONS_PER_REQUEST) {
    const chunk = destinations.slice(i, i + MAX_DESTINATIONS_PER_REQUEST)
    const chunkResults = await fetchOsrmChunk(origin, chunk)
    if (!chunkResults) return null
    allResults.push(...chunkResults)
  }
  return allResults
}
