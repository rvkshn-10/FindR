import { NextResponse } from 'next/server'

/**
 * GET /api/supply-map/status
 * Check if GOOGLE_MAPS_API_KEY is set and if Google Distance Matrix responds.
 * Use this to debug "distances still not working" – open in browser or curl.
 */
export async function GET() {
  const keySet = Boolean(process.env.GOOGLE_MAPS_API_KEY)
  if (!keySet) {
    return NextResponse.json({
      googleKeySet: false,
      message: 'GOOGLE_MAPS_API_KEY is not set. Add it to .env.local and restart the dev server.',
    })
  }

  // Minimal test: one origin, one destination (San Francisco to Oakland)
  const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=37.7749,-122.4194&destinations=37.8044,-122.2712&mode=driving&key=${process.env.GOOGLE_MAPS_API_KEY}`
  try {
    const res = await fetch(url)
    const data = (await res.json()) as { status: string; error_message?: string }
    if (data.status === 'OK') {
      return NextResponse.json({
        googleKeySet: true,
        googleStatus: 'OK',
        message: 'Google Distance Matrix is working. Road distances should use Google.',
      })
    }
    return NextResponse.json({
      googleKeySet: true,
      googleStatus: data.status,
      errorMessage: data.error_message ?? undefined,
      message:
        data.status === 'REQUEST_DENIED'
          ? 'Key rejected. Enable "Distance Matrix API" in Google Cloud Console and check key restrictions (do not restrict to HTTP referrer only – server has no referrer).'
          : data.status === 'OVER_QUERY_LIMIT'
            ? 'Quota exceeded. Check billing and quotas in Google Cloud Console.'
            : `Google returned: ${data.status}. ${data.error_message ?? ''}`,
    })
  } catch (err) {
    return NextResponse.json({
      googleKeySet: true,
      googleStatus: 'ERROR',
      message: err instanceof Error ? err.message : 'Request failed',
    })
  }
}
