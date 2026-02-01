const KM_TO_MILES = 0.621371
const MILES_TO_KM = 1.60934
const EARTH_RADIUS_KM = 6371

/**
 * Great-circle distance between two points (haversine) in km.
 */
export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLng = ((lng2 - lng1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return EARTH_RADIUS_KM * c
}

export function kmToMiles(km: number): number {
  return km * KM_TO_MILES
}

export function milesToKm(mi: number): number {
  return mi * MILES_TO_KM
}

/**
 * Format distance in km as a short miles string for display (e.g. "1.2 mi", "0.5 mi").
 */
export function formatMiles(km: number): string {
  const mi = kmToMiles(km)
  if (mi < 0.1) return '< 0.1 mi'
  if (mi < 1) return `${mi.toFixed(1)} mi`
  if (mi < 10) return `${Math.round(mi * 10) / 10} mi`
  return `${Math.round(mi)} mi`
}

export type DistanceUnit = 'mi' | 'km'

/**
 * Format distance for display in the user's chosen unit.
 */
export function formatDistance(km: number, unit: DistanceUnit): string {
  if (unit === 'km') {
    if (km < 0.1) return '< 0.1 km'
    if (km < 1) return `${km.toFixed(1)} km`
    if (km < 10) return `${Math.round(km * 10) / 10} km`
    return `${Math.round(km)} km`
  }
  return formatMiles(km)
}

/**
 * Format a distance given in miles (e.g. filter "5 mi") in the user's chosen unit.
 */
export function formatDistanceFromMiles(miles: number, unit: DistanceUnit): string {
  if (unit === 'km') {
    const km = milesToKm(miles)
    return km < 1 ? `${km.toFixed(1)} km` : `${Math.round(km)} km`
  }
  return `${miles} mi`
}
