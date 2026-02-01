'use client'

import { useState, FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useSupplyMapSettings } from '@/components/supply-map/SupplyMapSettingsProvider'
import { formatDistanceFromMiles } from '@/lib/supply-map/distance'

const MAX_DISTANCE_MILES = [5, 10, 15] as const

export default function SearchBar() {
  const router = useRouter()
  const { distanceUnit } = useSupplyMapSettings()
  const [item, setItem] = useState('')
  const [locationQuery, setLocationQuery] = useState('')
  const [useMyLocation, setUseMyLocation] = useState(true)
  const [maxDistanceMiles, setMaxDistanceMiles] = useState(5)
  const [showFilters, setShowFilters] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    const trimmed = item.trim()
    if (!trimmed) {
      setError('Enter what you need.')
      return
    }

    setLoading(true)
    try {
      let lat: number
      let lng: number

      if (useMyLocation) {
        const pos = await new Promise<GeolocationPosition>((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 60000,
          })
        })
        lat = pos.coords.latitude
        lng = pos.coords.longitude
      } else {
        const locationTrimmed = locationQuery.trim()
        if (!locationTrimmed) {
          setError('Enter a city or address, or use "Use my location".')
          setLoading(false)
          return
        }
        const res = await fetch(
          `/api/supply-map/geocode?q=${encodeURIComponent(locationTrimmed)}`
        )
        if (!res.ok) {
          const err = await res.json().catch(() => ({}))
          throw new Error(err.message ?? 'Could not find that location.')
        }
        const data = await res.json()
        lat = data.lat
        lng = data.lng
      }

      const params = new URLSearchParams({
        item: trimmed,
        lat: String(lat),
        lng: String(lng),
        maxDistance: String(maxDistanceMiles),
      })
      router.push(`/supply-map/results?${params.toString()}`)
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Something went wrong.'
      if (message.toLowerCase().includes('denied') || message.toLowerCase().includes('permission')) {
        setError('Location denied. Enter a city or address below to search instead.')
      } else {
        setError(message)
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label htmlFor="item" className="sr-only">
          What do you need?
        </label>
        <input
          id="item"
          type="text"
          value={item}
          onChange={(e) => setItem(e.target.value)}
          placeholder="e.g. AA batteries, milk, bandages"
          className="w-full px-4 py-3.5 text-lg border border-primary-200 rounded-xl focus:ring-2 focus:ring-primary-400 focus:border-primary-400 outline-none bg-white text-primary-900 placeholder-primary-400"
          disabled={loading}
          autoComplete="off"
        />
      </div>

      <div className="flex flex-col sm:flex-row gap-3">
        <label className="flex items-center gap-2 cursor-pointer shrink-0">
          <input
            type="checkbox"
            checked={useMyLocation}
            onChange={(e) => {
              setUseMyLocation(e.target.checked)
              setError(null)
            }}
            className="rounded border-primary-300 text-primary-600 focus:ring-primary-400"
          />
          <span className="text-primary-700 text-sm sm:text-base">Use my location</span>
        </label>
        {!useMyLocation && (
          <input
            type="text"
            value={locationQuery}
            onChange={(e) => setLocationQuery(e.target.value)}
            placeholder="City or address"
            className="flex-1 min-w-0 px-4 py-2.5 border border-primary-200 rounded-lg focus:ring-2 focus:ring-primary-400 focus:border-primary-400 outline-none bg-white text-primary-900 placeholder-primary-400"
            disabled={loading}
          />
        )}
      </div>

      <div className="border-t border-primary-100 pt-3">
        <button
          type="button"
          onClick={() => setShowFilters((s) => !s)}
          className="text-primary-600 hover:text-primary-800 text-sm font-medium flex items-center gap-1"
        >
          {showFilters ? 'Hide filters' : 'Filters'}
          <span className="text-primary-400" aria-hidden>{showFilters ? '−' : '+'}</span>
        </button>
        {showFilters && (
            <div className="mt-3 flex flex-wrap gap-4">
            <div>
              <label htmlFor="maxDistance" className="block text-xs font-medium text-primary-600 mb-1">
                Max distance
              </label>
              <select
                id="maxDistance"
                value={maxDistanceMiles}
                onChange={(e) => setMaxDistanceMiles(Number(e.target.value) as 5 | 10 | 15)}
                className="px-3 py-2 border border-primary-200 rounded-lg bg-white text-primary-900 text-sm focus:ring-2 focus:ring-primary-400 outline-none"
              >
                {MAX_DISTANCE_MILES.map((miles) => (
                  <option key={miles} value={miles}>
                    Within {formatDistanceFromMiles(miles, distanceUnit)}
                  </option>
                ))}
              </select>
            </div>
          </div>
        )}
      </div>

      {error && (
        <p className="text-red-600 text-sm" role="alert">
          {error}
        </p>
      )}

      <button
        type="submit"
        disabled={loading}
        className="w-full sm:w-auto min-w-[140px] px-6 py-3.5 bg-primary-700 text-white font-semibold rounded-xl hover:bg-primary-800 focus:ring-2 focus:ring-primary-400 focus:ring-offset-2 disabled:opacity-50 transition shadow-sm"
      >
        {loading ? 'Finding…' : 'Find nearby'}
      </button>
    </form>
  )
}
