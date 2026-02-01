/**
 * Client-side feedback store using localStorage (for static export).
 * Same logical API as lib/supply-map/feedback.ts but persists in the browser.
 */

const FEEDBACK_PREFIX = 'supplymap_fb_'
const PRICE_PREFIX = 'supplymap_price_'

function key(storeId: string, item: string): string {
  return `${storeId}:${item.trim().toLowerCase()}`
}

export function setFeedback(storeId: string, item: string, inStock: boolean): void {
  try {
    localStorage.setItem(FEEDBACK_PREFIX + key(storeId, item), String(inStock))
  } catch {
    // quota or private mode
  }
}

export function setPrice(storeId: string, item: string, price: number): void {
  if (!Number.isFinite(price) || price < 0) return
  try {
    localStorage.setItem(PRICE_PREFIX + key(storeId, item), String(price))
  } catch {
    // quota or private mode
  }
}

export function getFeedbackForStores(
  item: string,
  storeIds: string[]
): Record<string, boolean> {
  const result: Record<string, boolean> = {}
  const normalizedItem = item.trim().toLowerCase()
  try {
    for (const id of storeIds) {
      const v = localStorage.getItem(FEEDBACK_PREFIX + `${id}:${normalizedItem}`)
      if (v === 'true') result[id] = true
      if (v === 'false') result[id] = false
    }
  } catch {
    // ignore
  }
  return result
}

export function getPricesForStores(
  item: string,
  storeIds: string[]
): Record<string, number> {
  const result: Record<string, number> = {}
  const normalizedItem = item.trim().toLowerCase()
  try {
    for (const id of storeIds) {
      const v = localStorage.getItem(PRICE_PREFIX + `${id}:${normalizedItem}`)
      if (v != null) {
        const n = parseFloat(v)
        if (Number.isFinite(n) && n >= 0) result[id] = n
      }
    }
  } catch {
    // ignore
  }
  return result
}
