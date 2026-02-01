import { NextRequest } from 'next/server'
import { setFeedback, setPrice } from '@/lib/supply-map/feedback'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const storeId = typeof body.storeId === 'string' ? body.storeId.trim() : ''
    const item = typeof body.item === 'string' ? body.item.trim() : ''
    const inStock = body.inStock !== undefined
      ? (typeof body.inStock === 'boolean' ? body.inStock : body.inStock === 'true')
      : undefined
    const price =
      typeof body.price === 'number'
        ? body.price
        : typeof body.price === 'string'
          ? parseFloat(body.price)
          : undefined

    if (!storeId || !item) {
      return Response.json(
        { message: 'Missing storeId or item' },
        { status: 400 }
      )
    }

    const hasValidPrice = price !== undefined && Number.isFinite(price) && price >= 0
    if (inStock !== undefined) {
      setFeedback(storeId, item, inStock)
    }
    if (hasValidPrice) {
      setPrice(storeId, item, price as number)
    }

    if (inStock === undefined && !hasValidPrice) {
      return Response.json(
        { message: 'Provide inStock and/or price' },
        { status: 400 }
      )
    }

    return Response.json({ ok: true })
  } catch {
    return Response.json({ message: 'Feedback failed' }, { status: 500 })
  }
}
