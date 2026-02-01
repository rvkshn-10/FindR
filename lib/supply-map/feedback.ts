/**
 * In-memory store for crowd-sourced stock and price feedback (Phase 4).
 * Stock key: `${storeId}:${item}` → boolean.
 * Price key: `${storeId}:${item}` → number (USD).
 */

const feedbackStore = new Map<string, boolean>()
const priceStore = new Map<string, number>()

function key(storeId: string, item: string): string {
  return `${storeId}:${item.trim().toLowerCase()}`
}

export function setFeedback(storeId: string, item: string, inStock: boolean): void {
  feedbackStore.set(key(storeId, item), inStock)
}

export function setPrice(storeId: string, item: string, price: number): void {
  if (Number.isFinite(price) && price >= 0) {
    priceStore.set(key(storeId, item), price)
  }
}

export function getFeedbackForStores(
  item: string,
  storeIds: string[]
): Record<string, boolean> {
  const result: Record<string, boolean> = {}
  const normalizedItem = item.trim().toLowerCase()
  for (const id of storeIds) {
    const v = feedbackStore.get(`${id}:${normalizedItem}`)
    if (v !== undefined) result[id] = v
  }
  return result
}

export function getPricesForStores(
  item: string,
  storeIds: string[]
): Record<string, number> {
  const result: Record<string, number> = {}
  const normalizedItem = item.trim().toLowerCase()
  for (const id of storeIds) {
    const v = priceStore.get(`${id}:${normalizedItem}`)
    if (v !== undefined && Number.isFinite(v)) result[id] = v
  }
  return result
}
