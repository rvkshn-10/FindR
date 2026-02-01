import { NextRequest } from 'next/server'
import { fetchNearbyStores } from '@/lib/supply-map/overpass'
import { rankStores, summarizeBestOption, suggestAlternatives } from '@/lib/supply-map/ai'
import { getFeedbackForStores, getPricesForStores } from '@/lib/supply-map/feedback'
import { formatMiles, haversineKm } from '@/lib/supply-map/distance'
import { getRoadDistances } from '@/lib/supply-map/google-distance'
import { getRoadDistancesOSRM } from '@/lib/supply-map/osrm-distance'

const RADIUS_M = 5000 // 5 km
const ALTERNATIVES_THRESHOLD = 2 // suggest alternatives when stores < this
const MAX_NEARBY_STORES = 10 // number of stores to return
const MAX_STORES_FOR_ROAD = 25 // request road distances for more candidates (Google/OSRM limit allows 25)

export interface SearchStore {
  id: string
  name: string
  lat: number
  lng: number
  address: string
  distanceKm: number
  durationMinutes?: number
  reportedPrice?: number
  osmTags?: Record<string, string>
}

export interface SearchResponse {
  stores: SearchStore[]
  bestOptionId: string
  summary: string
  alternatives?: string[]
  /** Debug: API connection and which source was used for distances */
  _debug?: {
    distanceSource: 'google' | 'osrm' | 'haversine'
    googleKeySet: boolean
    /** Reason Google wasn't used (only when distanceSource !== 'google') */
    googleError?: string
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const item = typeof body.item === 'string' ? body.item.trim() : ''
    const lat = typeof body.lat === 'number' ? body.lat : parseFloat(body.lat)
    const lng = typeof body.lng === 'number' ? body.lng : parseFloat(body.lng)

    if (!item || Number.isNaN(lat) || Number.isNaN(lng)) {
      return Response.json(
        { message: 'Missing or invalid item, lat, or lng' },
        { status: 400 }
      )
    }

    const maxDistanceKm = body.filters?.maxDistanceKm
    const radiusM = maxDistanceKm != null ? Math.min(maxDistanceKm * 1000, 25000) : RADIUS_M

    const stores = await fetchNearbyStores(lat, lng, radiusM)
    const limitKm = maxDistanceKm != null ? maxDistanceKm : RADIUS_M / 1000
    const storeIds = stores.map((s) => s.id)
    const prices = getPricesForStores(item, storeIds)
    let searchStores: SearchStore[] = stores
      .filter((s) => s.distanceKm <= limitKm)
      .map((s) => ({
        id: s.id,
        name: s.name,
        lat: s.lat,
        lng: s.lng,
        address: s.address,
        distanceKm: Math.round(haversineKm(lat, lng, s.lat, s.lng) * 100) / 100,
        durationMinutes: undefined,
        reportedPrice: prices[s.id],
        osmTags: s.osmTags,
      }))
      .sort((a, b) => a.distanceKm - b.distanceKm)

    const storesForRoad = searchStores.slice(0, MAX_STORES_FOR_ROAD)
    const dests = storesForRoad.map((s) => ({ lat: s.lat, lng: s.lng }))
    let roadDistances: Array<{ distanceKm: number; durationMinutes?: number }> | null = null
    let distanceSource: 'google' | 'osrm' | 'haversine' = 'haversine'
    let googleError: string | undefined
    const googleKeySet = Boolean(process.env.GOOGLE_MAPS_API_KEY)
    if (dests.length > 0) {
      if (googleKeySet) {
        const googleResult = await getRoadDistances({ lat, lng }, dests)
        if (googleResult.results) {
          roadDistances = googleResult.results
          distanceSource = 'google'
          const hasGaps = roadDistances.some((r) => r.distanceKm <= 0)
          if (hasGaps) {
            try {
              const osrmResults = await getRoadDistancesOSRM({ lat, lng }, dests)
              if (osrmResults && osrmResults.length === roadDistances.length) {
                roadDistances = roadDistances.map((g, i) => {
                  const o = osrmResults[i]
                  if (g.distanceKm > 0) return g
                  if (o?.distanceKm > 0) return o
                  return g
                })
              }
            } catch {
              // keep Google results with gaps
            }
          }
        } else {
          googleError = googleResult.error
          if (googleError) console.warn('[Supply Map] Google:', googleError)
        }
      } else {
        googleError = 'GOOGLE_MAPS_API_KEY not set'
        console.warn('[Supply Map]', googleError)
      }
      if (!roadDistances) {
        try {
          roadDistances = await getRoadDistancesOSRM({ lat, lng }, dests)
          if (roadDistances) distanceSource = 'osrm'
        } catch (err) {
          console.error('[Supply Map] OSRM threw:', err)
          roadDistances = null
        }
      }
    }
    if (roadDistances && roadDistances.length > 0) {
      // When API returns duration but distance=0 (e.g. OSRM null cell), estimate distance from drive time
      const AVG_SPEED_KMH = 50
      const roadCount = Math.min(roadDistances.length, storesForRoad.length)
      const withRoad = storesForRoad.slice(0, roadCount).map((s, i) => {
        let roadKm = roadDistances![i].distanceKm
        const durationMin = roadDistances![i].durationMinutes
        if (roadKm <= 0 && durationMin != null && durationMin > 0) {
          roadKm = Math.round((durationMin / 60) * AVG_SPEED_KMH * 100) / 100
        }
        const straightKm = haversineKm(lat, lng, s.lat, s.lng)
        // Road distance must be >= straight-line; if API returns nonsense, reject
        const useRoad =
          roadKm > 0 &&
          roadKm >= straightKm * 0.5 &&
          roadKm <= straightKm * 15
        return {
          ...s,
          distanceKm: useRoad ? roadKm : 0,
          durationMinutes: useRoad ? durationMin : undefined,
          hadApiValue: useRoad,
        }
      })
      // Only include stores that have a valid road API value; exclude fallback/haversine-only
      searchStores = withRoad
        .filter((s) => s.hadApiValue && s.distanceKm > 0 && s.distanceKm <= limitKm)
        .map(({ hadApiValue: _, ...s }) => s)
        .sort((a, b) => a.distanceKm - b.distanceKm)
    } else {
      // No road API data: exclude all stores so we don't show straight-line estimates
      searchStores = []
    }
    searchStores = searchStores.slice(0, MAX_NEARBY_STORES)

    let bestOptionId = searchStores.length > 0 ? searchStores[0].id : ''
    let summary =
      searchStores.length > 0
        ? `${searchStores[0].name} is the closest option (${formatMiles(searchStores[0].distanceKm)} away).`
        : 'No nearby stores found.'

    // Phase 2: AI ranking and summary when OPENAI_API_KEY is set (uses stock + price when available)
    if (process.env.OPENAI_API_KEY && searchStores.length > 0) {
      const feedback = getFeedbackForStores(item, searchStores.map((s) => s.id))
      const rankResult = await rankStores(item, searchStores, feedback)
      if (rankResult?.orderedIds?.length) {
        const idToStore = new Map(searchStores.map((s) => [s.id, s]))
        const ordered = rankResult.orderedIds
          .map((id) => idToStore.get(id))
          .filter(Boolean) as SearchStore[]
        if (ordered.length) {
          const rest = searchStores.filter((s) => !rankResult.orderedIds!.includes(s.id))
          searchStores = [...ordered, ...rest]
          bestOptionId = ordered[0].id
          const aiSummary = await summarizeBestOption(item, ordered[0], searchStores)
          if (aiSummary) summary = aiSummary
        }
      }
    }

    // Phase 3: alternative suggestions when no or few results
    let alternatives: string[] | undefined
    if (searchStores.length < ALTERNATIVES_THRESHOLD && item) {
      alternatives = await suggestAlternatives(item)
    }

    const response: SearchResponse = {
      stores: searchStores,
      bestOptionId,
      summary,
      _debug: {
        distanceSource,
        googleKeySet,
        ...(googleError ? { googleError } : {}),
      },
      ...(alternatives?.length ? { alternatives } : {}),
    }
    return Response.json(response)
  } catch (err) {
    console.error('Supply map search error:', err)
    return Response.json(
      { message: err instanceof Error ? err.message : 'Search failed' },
      { status: 500 }
    )
  }
}
