import { NextRequest } from 'next/server'
import { geocode } from '@/lib/supply-map/geocode'

export async function GET(request: NextRequest) {
  const q = request.nextUrl.searchParams.get('q')
  if (!q?.trim()) {
    return Response.json({ message: 'Missing query q' }, { status: 400 })
  }
  try {
    const result = await geocode(q.trim())
    if (!result) {
      return Response.json({ message: 'Location not found' }, { status: 404 })
    }
    return Response.json({ lat: result.lat, lng: result.lng, displayName: result.displayName })
  } catch {
    return Response.json({ message: 'Geocoding failed' }, { status: 500 })
  }
}
