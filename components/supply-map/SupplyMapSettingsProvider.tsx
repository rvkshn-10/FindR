'use client'

import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import type { DistanceUnit } from '@/lib/supply-map/distance'
import type { CurrencyCode } from '@/lib/supply-map/currency'

const STORAGE_KEY = 'supply-map-settings'

export interface SupplyMapSettings {
  distanceUnit: DistanceUnit
  currency: CurrencyCode
}

const DEFAULT_SETTINGS: SupplyMapSettings = {
  distanceUnit: 'mi',
  currency: 'USD',
}

const VALID_CURRENCIES: CurrencyCode[] = ['EUR', 'GBP', 'CAD', 'MXN']

function loadSettings(): SupplyMapSettings {
  if (typeof window === 'undefined') return DEFAULT_SETTINGS
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return DEFAULT_SETTINGS
    const parsed = JSON.parse(raw) as Partial<SupplyMapSettings>
    const currency: CurrencyCode =
      parsed.currency !== undefined && VALID_CURRENCIES.includes(parsed.currency)
        ? parsed.currency
        : 'USD'
    return {
      distanceUnit: parsed.distanceUnit === 'km' ? 'km' : 'mi',
      currency,
    }
  } catch {
    return DEFAULT_SETTINGS
  }
}

function saveSettings(settings: SupplyMapSettings) {
  if (typeof window === 'undefined') return
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings))
  } catch {
    // ignore
  }
}

interface SettingsContextValue extends SupplyMapSettings {
  setDistanceUnit: (unit: DistanceUnit) => void
  setCurrency: (currency: CurrencyCode) => void
}

const SettingsContext = createContext<SettingsContextValue | null>(null)

export function SupplyMapSettingsProvider({ children }: { children: React.ReactNode }) {
  const [settings, setSettings] = useState<SupplyMapSettings>(DEFAULT_SETTINGS)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setSettings(loadSettings())
    setMounted(true)
  }, [])

  const setDistanceUnit = useCallback((distanceUnit: DistanceUnit) => {
    setSettings((prev) => {
      const next = { ...prev, distanceUnit }
      saveSettings(next)
      return next
    })
  }, [])

  const setCurrency = useCallback((currency: CurrencyCode) => {
    setSettings((prev) => {
      const next = { ...prev, currency }
      saveSettings(next)
      return next
    })
  }, [])

  const value: SettingsContextValue = mounted
    ? { ...settings, setDistanceUnit, setCurrency }
    : { ...DEFAULT_SETTINGS, setDistanceUnit, setCurrency }

  return (
    <SettingsContext.Provider value={value}>
      {children}
    </SettingsContext.Provider>
  )
}

export function useSupplyMapSettings(): SettingsContextValue {
  const ctx = useContext(SettingsContext)
  if (!ctx) {
    throw new Error('useSupplyMapSettings must be used within SupplyMapSettingsProvider')
  }
  return ctx
}
