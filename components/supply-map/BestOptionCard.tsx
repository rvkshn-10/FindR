'use client'

import { useSupplyMapSettings } from '@/components/supply-map/SupplyMapSettingsProvider'
import { formatPrice } from '@/lib/supply-map/currency'

interface PriceEntry {
  storeName: string
  price: number
}

interface BestOptionCardProps {
  summary: string
  storeName?: string
  priceComparison?: PriceEntry[]
}

export default function BestOptionCard({ summary, storeName, priceComparison }: BestOptionCardProps) {
  const { currency } = useSupplyMapSettings()
  return (
    <div className="bg-primary-100 border-2 border-primary-400 rounded-xl p-4 shadow-sm">
      <div className="flex items-center gap-2 mb-2">
        <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-primary-600 text-white text-xs font-bold" aria-hidden>
          ✓
        </span>
        <h3 className="font-semibold text-primary-900">
          Best option{storeName ? `: ${storeName}` : ''}
        </h3>
      </div>
      <p className="text-primary-800 text-sm sm:text-base leading-relaxed">{summary}</p>
      {priceComparison && priceComparison.length > 0 && (
        <div className="mt-3 pt-3 border-t border-primary-200">
          <p className="text-xs font-medium text-primary-600 mb-1">Price comparison (reported)</p>
          <ul className="text-sm text-primary-800 space-y-0.5">
            {priceComparison.map(({ storeName: name, price }) => (
              <li key={name}>
                {name}: {formatPrice(price, currency)}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
