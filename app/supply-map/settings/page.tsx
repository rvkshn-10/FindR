'use client'

import { useSupplyMapSettings } from '@/components/supply-map/SupplyMapSettingsProvider'
import { CURRENCY_OPTIONS, getCurrencyLabel } from '@/lib/supply-map/currency'
import type { CurrencyCode } from '@/lib/supply-map/currency'
import Link from 'next/link'

export default function SupplyMapSettingsPage() {
  const { distanceUnit, currency, setDistanceUnit, setCurrency } = useSupplyMapSettings()

  return (
    <div className="max-w-xl mx-auto px-4 py-10 sm:py-16">
      <div className="mb-8">
        <Link
          href="/supply-map"
          className="text-primary-600 hover:text-primary-800 text-sm font-medium"
        >
          ← Back to search
        </Link>
      </div>
      <h1 className="text-2xl sm:text-3xl font-bold text-primary-900 font-serif mb-2">
        Settings
      </h1>
      <p className="text-primary-600 text-sm mb-8">
        Choose how distances and prices are displayed. Your choices are saved in this browser.
      </p>

      <div className="space-y-8">
        <section className="bg-white rounded-xl border border-primary-200 p-5 sm:p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-primary-900 mb-3">Distance unit</h2>
          <p className="text-primary-600 text-sm mb-4">
            Show distances in miles or kilometers.
          </p>
          <div className="flex gap-4">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                name="distanceUnit"
                checked={distanceUnit === 'mi'}
                onChange={() => setDistanceUnit('mi')}
                className="text-primary-600 focus:ring-primary-400"
              />
              <span className="text-primary-800">Miles (mi)</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                name="distanceUnit"
                checked={distanceUnit === 'km'}
                onChange={() => setDistanceUnit('km')}
                className="text-primary-600 focus:ring-primary-400"
              />
              <span className="text-primary-800">Kilometers (km)</span>
            </label>
          </div>
        </section>

        <section className="bg-white rounded-xl border border-primary-200 p-5 sm:p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-primary-900 mb-3">Currency</h2>
          <p className="text-primary-600 text-sm mb-4">
            Reported prices are stored in US dollars and converted for display. Rates are approximate.
          </p>
          <label htmlFor="currency" className="block text-sm font-medium text-primary-700 mb-2">
            Display prices in
          </label>
          <select
            id="currency"
            value={currency}
            onChange={(e) => setCurrency(e.target.value as CurrencyCode)}
            className="w-full max-w-xs px-4 py-2 border border-primary-200 rounded-lg bg-white text-primary-900 focus:ring-2 focus:ring-primary-400 focus:border-primary-400 outline-none"
          >
            {CURRENCY_OPTIONS.map((code) => (
              <option key={code} value={code}>
                {getCurrencyLabel(code)}
              </option>
            ))}
          </select>
        </section>
      </div>
    </div>
  )
}
