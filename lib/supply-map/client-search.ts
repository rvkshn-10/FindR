/**
 * Client-side search for static export: Overpass + OSRM (or haversine fallback).
 * No Google Maps API, no OpenAI; feedback/prices from localStorage.
 */

import { fetchNearbyStores } from '@/lib/supply-map/overpass'
import { getFeedbackForStores, getPricesForStores } from '@/lib/supply-map/feedback-client'
import { formatMiles, haversineKm } from '@/lib/supply-map/distance'
import { getRoadDistancesOSRM } from '@/lib/supply-map/osrm-distance'

const RADIUS_M = 5000
const MAX_NEARBY_STORES = 10
const MAX_STORES_FOR_ROAD = 25
const AVG_SPEED_KMH = 50

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
  _debug?: {
    distanceSource: 'google' | 'osrm' | 'haversine'
    googleKeySet: boolean
    googleError?: string
  }
}

export async function clientSearch(
  item: string,
  lat: number,
  lng: number,
  options?: { maxDistanceKm?: number }
): Promise<SearchResponse> {
  const maxDistanceKm = options?.maxDistanceKm ?? RADIUS_M / 1000
  const radiusM = Math.min((maxDistanceKm ?? 5) * 1000, 25000)

  const stores = await fetchNearbyStores(lat, lng, radiusM)
  const storeIds = stores.map((s) => s.id)
  const prices = getPricesForStores(item, storeIds)

  let searchStores: SearchStore[] = stores
    .filter((s) => s.distanceKm <= maxDistanceKm)
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

  if (dests.length > 0) {
    try {
      roadDistances = await getRoadDistancesOSRM({ lat, lng }, dests)
      if (roadDistances) distanceSource = 'osrm'
    } catch {
      roadDistances = null
    }
  }

  if (roadDistances && roadDistances.length > 0) {
    const roadCount = Math.min(roadDistances.length, storesForRoad.length)
    const withRoad = storesForRoad.slice(0, roadCount).map((s, i) => {
      let roadKm = roadDistances![i].distanceKm
      const durationMin = roadDistances![i].durationMinutes
      if (roadKm <= 0 && durationMin != null && durationMin > 0) {
        roadKm = Math.round((durationMin / 60) * AVG_SPEED_KMH * 100) / 100
      }
      const straightKm = haversineKm(lat, lng, s.lat, s.lng)
      const useRoad =
        roadKm > 0 &&
        roadKm >= straightKm * 0.5 &&
        roadKm <= straightKm * 15
      return {
        ...s,
        distanceKm: useRoad ? roadKm : 0,
        durationMinutes: useRoad ? durationMin : undefined,
        hadApiValue: useRoad,
      } as SearchStore & { hadApiValue: boolean }
    })
    searchStores = withRoad
      .filter((s) => s.hadApiValue && s.distanceKm > 0 && s.distanceKm <= maxDistanceKm)
      .map(({ hadApiValue: _, ...s }) => s)
      .sort((a, b) => a.distanceKm - b.distanceKm)
  } else {
    searchStores = []
  }

  searchStores = searchStores.slice(0, MAX_NEARBY_STORES)

  const bestOptionId = searchStores.length > 0 ? searchStores[0].id : ''
  const summary =
    searchStores.length > 0
      ? `${searchStores[0].name} is the closest option (${formatMiles(searchStores[0].distanceKm)} away).`
      : 'No nearby stores found.'

  return {
    stores: searchStores,
    bestOptionId,
    summary,
    _debug: {
      distanceSource,
      googleKeySet: false,
      googleError: 'Static build: no server',
    },
  }
}
