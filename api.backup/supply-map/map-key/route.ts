import { NextResponse } from 'next/server'

/**
 * GET /api/supply-map/map-key
 * Returns the Google Maps API key for the map (client). Uses GOOGLE_MAPS_API_KEY
 * or NEXT_PUBLIC_GOOGLE_MAPS_API_KEY so one key in .env.local works for both
 * Distance Matrix and the map.
 */
export async function GET() {
  const key =
    process.env.GOOGLE_MAPS_API_KEY ??
    process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY ??
    ''
  return NextResponse.json({ googleMapsApiKey: key })
}
