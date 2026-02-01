'use client'

import { useSearchParams } from 'next/navigation'
import { useCallback, useEffect, useState, Suspense } from 'react'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import StoreList from '@/components/supply-map/StoreList'
import BestOptionCard from '@/components/supply-map/BestOptionCard'
import { useSupplyMapSettings } from '@/components/supply-map/SupplyMapSettingsProvider'
import { milesToKm, formatDistanceFromMiles } from '@/lib/supply-map/distance'

const MapView = dynamic(() => import('@/components/supply-map/MapView'), { ssr: false })

interface Store {
  id: string
  name: string
  lat: number
  lng: number
  address: string
  distanceKm: number
  durationMinutes?: number
  reportedPrice?: number
}

interface SearchResult {
  stores: Store[]
  bestOptionId: string
  summary: string
  alternatives?: string[]
  _debug?: {
    distanceSource: 'google' | 'osrm' | 'haversine'
    googleKeySet: boolean
    googleError?: string
  }
}

function ResultsContent() {
  const searchParams = useSearchParams()
  const item = searchParams.get('item') ?? ''
  const latParam = searchParams.get('lat')
  const lngParam = searchParams.get('lng')
  const maxDistanceParam = searchParams.get('maxDistance')
  const maxDistanceMiles = maxDistanceParam ? parseFloat(maxDistanceParam) : 5
  const maxDistanceKm = milesToKm(maxDistanceMiles)

  const [data, setData] = useState<SearchResult | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [googleMapsApiKey, setGoogleMapsApiKey] = useState<string | null>(null)

  useEffect(() => {
    fetch('/api/supply-map/map-key')
      .then((r) => r.json())
      .then((body: { googleMapsApiKey?: string }) => setGoogleMapsApiKey(body.googleMapsApiKey ?? ''))
      .catch(() => setGoogleMapsApiKey(''))
  }, [])

  const lat = latParam ? parseFloat(latParam) : NaN
  const lng = lngParam ? parseFloat(lngParam) : NaN

  const fetchResults = useCallback(async () => {
    if (!item || Number.isNaN(lat) || Number.isNaN(lng)) {
      setError('Missing search parameters.')
      setLoading(false)
      return
    }
    setLoading(true)
    setError(null)
    try {
      const res = await fetch('/api/supply-map/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          item,
          lat,
          lng,
          filters: Number.isFinite(maxDistanceKm) ? { maxDistanceKm } : undefined,
        }),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.message ?? 'Search failed')
      }
      const result: SearchResult = await res.json()
      setData(result)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong.')
    } finally {
      setLoading(false)
    }
  }, [item, lat, lng, maxDistanceKm])

  useEffect(() => {
    fetchResults()
  }, [fetchResults])

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto px-4 py-12 sm:py-16">
        <div className="flex flex-col items-center justify-center gap-4 text-primary-700">
          <div className="w-10 h-10 border-2 border-primary-300 border-t-primary-600 rounded-full animate-spin" aria-hidden />
          <p>Finding nearby stores…</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="max-w-6xl mx-auto px-4 py-12 sm:py-16">
        <div className="max-w-md mx-auto text-center">
          <p className="text-red-600 mb-4" role="alert">{error}</p>
          <Link
            href="/supply-map"
            className="inline-block px-4 py-2 bg-primary-100 text-primary-800 font-medium rounded-lg hover:bg-primary-200 transition"
          >
            Back to search
          </Link>
        </div>
      </div>
    )
  }

  if (!data) return null

  const { distanceUnit } = useSupplyMapSettings()
  const { stores, bestOptionId, summary, alternatives } = data
  const bestStore = stores.find((s) => s.id === bestOptionId)
  const priceComparison = stores
    .filter((s) => s.reportedPrice != null)
    .map((s) => ({ storeName: s.name, price: s.reportedPrice! }))
    .sort((a, b) => a.price - b.price)

  function handlePriceReported(storeId: string, price: number) {
    setData((prev) =>
      prev
        ? {
            ...prev,
            stores: prev.stores.map((s) =>
              s.id === storeId ? { ...s, reportedPrice: price } : s
            ),
          }
        : null
    )
  }

  return (
    <div className="max-w-6xl mx-auto px-4 py-4 sm:py-6">
      <div className="mb-4 flex items-center justify-between gap-4 flex-wrap">
        <h1 className="text-xl sm:text-2xl font-bold text-primary-900 font-serif">
          Results for &ldquo;{item}&rdquo;
        </h1>
        <Link
          href="/supply-map"
          className="text-primary-600 hover:text-primary-800 text-sm font-medium"
        >
          New search
        </Link>
      </div>

      <div className="mb-4 p-3 sm:p-4 bg-primary-50 border border-primary-200 rounded-xl">
        <p className="text-primary-800 font-medium">
          You searched for: <span className="text-primary-900 font-semibold">&ldquo;{item}&rdquo;</span>
          <span className="text-primary-600 font-normal"> · Within {formatDistanceFromMiles(maxDistanceMiles, distanceUnit)}</span>
        </p>
        <p className="text-primary-500 text-xs mt-1">
          Stores that typically carry this kind of item. Availability is estimated.
        </p>
      </div>

      {stores.length === 0 && alternatives && alternatives.length > 0 && (
        <div className="mb-4 p-4 bg-cream-200 rounded-xl border border-cream-300">
          <p className="text-primary-800 font-medium mb-2">No nearby results for &ldquo;{item}&rdquo;</p>
          <p className="text-primary-700 text-sm mb-2">Try instead:</p>
          <ul className="list-disc list-inside text-primary-700 text-sm space-y-1">
            {alternatives.map((alt, i) => (
              <li key={i}>{alt}</li>
            ))}
          </ul>
        </div>
      )}

      {stores.length > 0 && (
        <div className="mb-4">
          <BestOptionCard
            summary={summary}
            storeName={bestStore?.name}
            priceComparison={priceComparison.length > 0 ? priceComparison : undefined}
          />
        </div>
      )}

      <div className="grid lg:grid-cols-2 gap-4 lg:gap-6">
        <div className="h-[320px] sm:h-[400px] lg:h-[500px] rounded-xl overflow-hidden border border-primary-200 bg-primary-50 order-2 lg:order-1">
          {googleMapsApiKey === null ? (
            <div className="h-full w-full flex items-center justify-center text-primary-600">Loading map…</div>
          ) : (
            <MapView
              googleMapsApiKey={googleMapsApiKey}
              userLat={lat}
              userLng={lng}
              stores={stores}
              bestOptionId={bestOptionId}
              selectedId={selectedId}
              onSelectStore={setSelectedId}
              bestSummary={summary}
            />
          )}
        </div>
        <div className="border border-primary-200 rounded-xl overflow-hidden bg-white max-h-[400px] lg:max-h-[500px] flex flex-col order-1 lg:order-2">
          <div className="p-3 sm:p-4 border-b border-primary-200 font-semibold text-primary-900 shrink-0">
            Nearby stores
          </div>
          <div className="overflow-y-auto flex-1 min-h-0">
            <StoreList
              stores={stores}
              bestOptionId={bestOptionId}
              selectedId={selectedId}
              onSelectStore={setSelectedId}
              item={item}
              onPriceReported={handlePriceReported}
            />
          </div>
        </div>
      </div>
    </div>
  )
}

export default function ResultsPage() {
  return (
    <Suspense fallback={
      <div className="max-w-6xl mx-auto px-4 py-16 text-center text-primary-700">
        Loading…
      </div>
    }>
      <ResultsContent />
    </Suspense>
  )
}
