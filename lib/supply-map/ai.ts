/**
 * OpenAI helpers for Supply Map: rank stores, summarize best option, suggest alternatives.
 */

import OpenAI from 'openai'
import { kmToMiles } from './distance'

export interface StoreForAI {
  id: string
  name: string
  address: string
  distanceKm: number
  reportedPrice?: number
  osmTags?: Record<string, string>
}

export interface RankResult {
  orderedIds: string[]
  reasons?: Record<string, string>
}

export interface FeedbackEntry {
  storeId: string
  inStock: boolean
}

export async function rankStores(
  item: string,
  stores: StoreForAI[],
  feedback?: Record<string, boolean>
): Promise<RankResult | null> {
  const apiKey = process.env.OPENAI_API_KEY
  if (!apiKey || stores.length === 0) return null

  const client = new OpenAI({ apiKey })
  const storeList = stores
    .map((s) => {
      const mi = kmToMiles(s.distanceKm)
      const distStr = mi < 1 ? `${mi.toFixed(1)} mi` : `${Math.round(mi * 10) / 10} mi`
      const priceStr = s.reportedPrice != null ? `, reported price: $${s.reportedPrice.toFixed(2)}` : ''
      return `- id: "${s.id}", name: "${s.name}", distance: ${distStr}${priceStr}${s.address ? `, address: ${s.address}` : ''}`
    })
    .join('\n')

  const feedbackLine =
    feedback && Object.keys(feedback).length > 0
      ? `\nUser-reported stock for "${item}": ${Object.entries(feedback)
          .map(([id, inStock]) => {
            const name = stores.find((s) => s.id === id)?.name ?? id
            return `${name} – ${inStock ? 'in stock' : 'out of stock'}`
          })
          .join('; ')}. Prefer stores reported in stock.\n`
      : ''

  const prompt = `The user is looking for: "${item}".${feedbackLine}

Nearby stores (with id, name, distance in miles):
${storeList}

Distances are in miles. When reported prices are shown, prefer lower price when similar distance. ${feedbackLine ? 'Account for user-reported stock when ranking.' : ''} Rank by convenience, likely availability, and value (when price is reported). Return a JSON object with exactly:
- "orderedIds": array of store ids in best-to-worst order (use the exact id strings from the list above)
- "reasons": optional object mapping store id to a one-line reason (e.g. "Closest and likely has stock")

Return only valid JSON, no markdown or extra text.`

  try {
    const completion = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.2,
      max_tokens: 500,
    })
    const text = completion.choices[0]?.message?.content?.trim()
    if (!text) return null
    const parsed = JSON.parse(text) as { orderedIds?: string[]; reasons?: Record<string, string> }
    const orderedIds = Array.isArray(parsed.orderedIds) ? parsed.orderedIds : []
    return { orderedIds, reasons: parsed.reasons ?? undefined }
  } catch {
    return null
  }
}

export async function summarizeBestOption(
  item: string,
  store: StoreForAI,
  allStores?: StoreForAI[]
): Promise<string | null> {
  const apiKey = process.env.OPENAI_API_KEY
  if (!apiKey) return null

  const client = new OpenAI({ apiKey })
  const mi = kmToMiles(store.distanceKm)
  const distStr = mi < 1 ? `${mi.toFixed(1)} mi` : `${Math.round(mi * 10) / 10} mi`
  const priceContext =
    store.reportedPrice != null
      ? ` Reported price at this store: $${store.reportedPrice.toFixed(2)}.`
      : ''
  const otherWithPrice = allStores?.filter((s) => s.reportedPrice != null && s.id !== store.id) ?? []
  const comparisonContext =
    otherWithPrice.length > 0
      ? ` Other reported prices: ${otherWithPrice.map((s) => `${s.name} $${s.reportedPrice!.toFixed(2)}`).join(', ')}.`
      : ''
  const prompt = `In 1–2 short sentences, explain why "${store.name}" (${distStr} away) is a good option for someone looking for "${item}".${priceContext}${comparisonContext} Use miles for distance. Only mention prices that are explicitly reported above; do not invent prices. No markdown, no quotes.`

  try {
    const completion = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      max_tokens: 80,
    })
    const text = completion.choices[0]?.message?.content?.trim()
    return text ?? null
  } catch {
    return null
  }
}

export async function suggestAlternatives(item: string): Promise<string[]> {
  const apiKey = process.env.OPENAI_API_KEY
  if (!apiKey) return []

  const client = new OpenAI({ apiKey })
  const prompt = `The user searched for "${item}" but found no or very few nearby results. Suggest 2–3 substitute products or store types they could try instead. Return a JSON object with a single key "alternatives" whose value is an array of short strings (e.g. ["AA batteries", "general electronics store"]). Return only valid JSON.`

  try {
    const completion = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      max_tokens: 150,
    })
    const text = completion.choices[0]?.message?.content?.trim()
    if (!text) return []
    const parsed = JSON.parse(text) as { alternatives?: string[] }
    return Array.isArray(parsed.alternatives) ? parsed.alternatives.slice(0, 3) : []
  } catch {
    return []
  }
}
