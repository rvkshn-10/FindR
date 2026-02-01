/**
 * Currency display for Supply Map. Reported prices are stored in USD.
 * Static rates for display only (MVP).
 */

export type CurrencyCode = 'USD' | 'EUR' | 'GBP' | 'CAD' | 'MXN'

const RATES_FROM_USD: Record<CurrencyCode, number> = {
  USD: 1,
  EUR: 0.92,
  GBP: 0.79,
  CAD: 1.36,
  MXN: 17,
}

export function convertFromUsd(amountUsd: number, currency: CurrencyCode): number {
  return amountUsd * (RATES_FROM_USD[currency] ?? 1)
}

/**
 * Format a price (stored in USD) for display in the user's chosen currency.
 */
export function formatPrice(amountUsd: number, currency: CurrencyCode = 'USD'): string {
  const amount = convertFromUsd(amountUsd, currency)
  const code = currency
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: code,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

export function getCurrencyLabel(code: CurrencyCode): string {
  const labels: Record<CurrencyCode, string> = {
    USD: 'US Dollar ($)',
    EUR: 'Euro (€)',
    GBP: 'British Pound (£)',
    CAD: 'Canadian Dollar ($)',
    MXN: 'Mexican Peso ($)',
  }
  return labels[code] ?? code
}

export const CURRENCY_OPTIONS: CurrencyCode[] = ['USD', 'EUR', 'GBP', 'CAD', 'MXN']
