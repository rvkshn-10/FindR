'use client'

import { useSupplyMapSettings } from '@/components/supply-map/SupplyMapSettingsProvider'
import { formatDistance } from '@/lib/supply-map/distance'
import { formatPrice } from '@/lib/supply-map/currency'

export interface StorePopupProps {
  name: string
  address: string
  distanceKm: number
  durationMinutes?: number
  reportedPrice?: number
  lat: number
  lng: number
  summary?: string
}

function directionsUrl(lat: number, lng: number): string {
  return `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`
}

export default function StorePopup({
  name,
  address,
  distanceKm,
  durationMinutes,
  reportedPrice,
  lat,
  lng,
  summary,
}: StorePopupProps) {
  const { distanceUnit, currency } = useSupplyMapSettings()
  return (
    <div className="min-w-[200px] max-w-[280px] p-1">
      <h3 className="font-semibold text-primary-900 mb-1">{name}</h3>
      {address && (
        <p className="text-sm text-primary-700 mb-1">{address}</p>
      )}
      <p className="text-sm text-primary-600 mb-1">
        {formatDistance(distanceKm, distanceUnit)} away
        {durationMinutes != null && (
          <span className="text-primary-600"> · ~{durationMinutes} min drive</span>
        )}
      </p>
      {reportedPrice != null && (
        <p className="text-sm font-medium text-primary-700 mb-2">Reported: {formatPrice(reportedPrice, currency)}</p>
      )}
      {summary && (
        <p className="text-sm text-primary-800 mb-2 italic">{summary}</p>
      )}
      <a
        href={directionsUrl(lat, lng)}
        target="_blank"
        rel="noopener noreferrer"
        className="text-sm font-medium text-primary-600 hover:text-primary-800 underline"
      >
        Get directions
      </a>
    </div>
  )
}
