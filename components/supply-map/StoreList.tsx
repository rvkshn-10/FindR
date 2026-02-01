'use client'

import { useState } from 'react'
import { useSupplyMapSettings } from '@/components/supply-map/SupplyMapSettingsProvider'
import { formatDistance } from '@/lib/supply-map/distance'
import { formatPrice } from '@/lib/supply-map/currency'
import { setFeedback, setPrice } from '@/lib/supply-map/feedback-client'

export interface StoreListItem {
  id: string
  name: string
  address: string
  distanceKm: number
  durationMinutes?: number
  reportedPrice?: number
  lat: number
  lng: number
}

interface StoreListProps {
  stores: StoreListItem[]
  bestOptionId: string
  selectedId: string | null
  onSelectStore: (id: string | null) => void
  item?: string
  onPriceReported?: (storeId: string, price: number) => void
}

export default function StoreList({
  stores,
  bestOptionId,
  selectedId,
  onSelectStore,
  item = '',
  onPriceReported,
}: StoreListProps) {
  const { distanceUnit, currency } = useSupplyMapSettings()
  const [feedbackSent, setFeedbackSent] = useState<Record<string, 'in' | 'out'>>({})
  const [priceInput, setPriceInput] = useState<Record<string, string>>({})
  const [priceSubmitting, setPriceSubmitting] = useState<Record<string, boolean>>({})

  function submitFeedback(storeId: string, inStock: boolean) {
    if (!item.trim()) return
    try {
      setFeedback(storeId, item.trim(), inStock)
      setFeedbackSent((prev) => ({ ...prev, [storeId]: inStock ? 'in' : 'out' }))
    } catch {
      // silent fail for MVP
    }
  }

  function submitPrice(storeId: string) {
    const raw = priceInput[storeId]?.trim().replace(/^\$/, '')
    const value = parseFloat(raw)
    if (!item.trim() || !Number.isFinite(value) || value < 0) return
    setPriceSubmitting((prev) => ({ ...prev, [storeId]: true }))
    try {
      setPrice(storeId, item.trim(), value)
      onPriceReported?.(storeId, value)
      setPriceInput((prev) => ({ ...prev, [storeId]: '' }))
    } catch {
      // silent fail
    } finally {
      setPriceSubmitting((prev) => ({ ...prev, [storeId]: false }))
    }
  }

  if (stores.length === 0) {
    return (
      <div className="p-4 text-primary-600 text-center">
        No nearby stores found.
      </div>
    )
  }

  return (
    <ul className="divide-y divide-primary-100">
      {stores.map((store) => {
        const isBest = store.id === bestOptionId
        const isSelected = store.id === selectedId
        const sent = feedbackSent[store.id]
        return (
          <li
            key={store.id}
            className={`p-4 cursor-pointer transition ${
              isSelected ? 'bg-primary-100 ring-1 ring-primary-300' : 'hover:bg-cream-100'
            } ${isBest ? 'border-l-4 border-primary-500' : ''}`}
            onClick={() => onSelectStore(isSelected ? null : store.id)}
          >
            <div className="flex justify-between items-start gap-2">
              <div className="min-w-0 flex-1">
                <h3 className="font-semibold text-primary-900 flex items-center gap-2">
                  {store.name}
                  {isBest && (
                    <span className="text-xs bg-primary-200 text-primary-800 px-2 py-0.5 rounded">
                      Best option
                    </span>
                  )}
                </h3>
                {store.address && (
                  <p className="text-sm text-primary-600 truncate">{store.address}</p>
                )}
                <p className="text-sm text-primary-500">
                  {formatDistance(store.distanceKm, distanceUnit)} away
                  {store.durationMinutes != null && (
                    <span className="text-primary-500"> · ~{store.durationMinutes} min drive</span>
                  )}
                </p>
                {store.reportedPrice != null && (
                  <p className="text-sm font-medium text-primary-700">Reported: {formatPrice(store.reportedPrice, currency)}</p>
                )}
                {item.trim() && (
                  <div className="mt-2 flex flex-wrap gap-2" onClick={(e) => e.stopPropagation()}>
                    <button
                      type="button"
                      onClick={() => submitFeedback(store.id, true)}
                      className={`text-xs px-2 py-1 rounded border ${
                        sent === 'in'
                          ? 'bg-green-100 border-green-300 text-green-800'
                          : 'border-primary-200 text-primary-700 hover:bg-cream-200'
                      }`}
                    >
                      In stock
                    </button>
                    <button
                      type="button"
                      onClick={() => submitFeedback(store.id, false)}
                      className={`text-xs px-2 py-1 rounded border ${
                        sent === 'out'
                          ? 'bg-amber-100 border-amber-300 text-amber-800'
                          : 'border-primary-200 text-primary-700 hover:bg-cream-200'
                      }`}
                    >
                      Out of stock
                    </button>
                    <div className="flex items-center gap-1 w-full sm:w-auto">
                      <label htmlFor={`price-${store.id}`} className="sr-only">Report price</label>
                      <input
                        id={`price-${store.id}`}
                        type="text"
                        inputMode="decimal"
                        placeholder="Report price $"
                        value={priceInput[store.id] ?? ''}
                        onChange={(e) => setPriceInput((prev) => ({ ...prev, [store.id]: e.target.value }))}
                        onKeyDown={(e) => e.key === 'Enter' && submitPrice(store.id)}
                        className="w-24 text-xs px-2 py-1 border border-primary-200 rounded bg-white text-primary-900 placeholder-primary-400"
                      />
                      <button
                        type="button"
                        onClick={() => submitPrice(store.id)}
                        disabled={priceSubmitting[store.id]}
                        className="text-xs px-2 py-1 rounded border border-primary-200 text-primary-700 hover:bg-cream-200 disabled:opacity-50"
                      >
                        {priceSubmitting[store.id] ? '…' : 'Report'}
                      </button>
                    </div>
                  </div>
                )}
              </div>
              <a
                href={directionsUrl(store.lat, store.lng)}
                target="_blank"
                rel="noopener noreferrer"
                className="shrink-0 text-sm font-medium text-primary-600 hover:text-primary-800 underline"
                onClick={(e) => e.stopPropagation()}
              >
                Directions
              </a>
            </div>
          </li>
        )
      })}
    </ul>
  )
}

function directionsUrl(lat: number, lng: number): string {
  return `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`
}
