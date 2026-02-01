'use client'

import 'leaflet/dist/leaflet.css'
import { useEffect, useRef } from 'react'
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet'
import L from 'leaflet'
import StorePopup from './StorePopup'
import GoogleMapView from './GoogleMapView'

// Fix default marker icon in Next/Leaflet
const createIcon = (isBest: boolean) =>
  L.divIcon({
    className: 'custom-marker',
    html: `<div style="width:24px;height:24px;border-radius:50%;background:${isBest ? '#534a3f' : '#9d8b73'};border:2px solid white;box-shadow:0 1px 3px rgba(0,0,0,0.3)"></div>`,
    iconSize: [24, 24],
    iconAnchor: [12, 12],
  })

const userLocationIcon = L.divIcon({
  className: 'custom-marker user-location-marker',
  html: `<div style="width:20px;height:20px;border-radius:50%;background:#2563eb;border:3px solid white;box-shadow:0 1px 4px rgba(0,0,0,0.4)"></div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10],
})

export interface MapStore {
  id: string
  name: string
  lat: number
  lng: number
  address: string
  distanceKm: number
  durationMinutes?: number
  reportedPrice?: number
}

interface MapViewProps {
  /** When set, use Google Maps instead of Leaflet (from /api/supply-map/map-key at runtime). */
  googleMapsApiKey?: string
  userLat: number
  userLng: number
  stores: MapStore[]
  bestOptionId: string
  selectedId: string | null
  onSelectStore: (id: string | null) => void
  bestSummary?: string
}

function FitBounds({ stores, userLat, userLng }: { stores: MapStore[]; userLat: number; userLng: number }) {
  const map = useMap()
  const done = useRef(false)
  useEffect(() => {
    if (done.current || !map) return
    const points: [number, number][] = [[userLat, userLng]]
    stores.forEach((s) => points.push([s.lat, s.lng]))
    if (points.length === 1) {
      map.setView([userLat, userLng], 14)
    } else {
      map.fitBounds(points as L.LatLngBoundsLiteral, { padding: [40, 40], maxZoom: 14 })
    }
    done.current = true
  }, [map, stores, userLat, userLng])
  return null
}

function PanToSelected({ selectedId, stores }: { selectedId: string | null; stores: MapStore[] }) {
  const map = useMap()
  useEffect(() => {
    if (!map || !selectedId) return
    const store = stores.find((s) => s.id === selectedId)
    if (store) {
      map.panTo([store.lat, store.lng], { animate: true })
      map.setZoom(Math.max(map.getZoom() ?? 14, 15))
    }
  }, [map, selectedId, stores])
  return null
}

function SelectedStorePopup({
  selectedStore,
  bestOptionId,
  bestSummary,
  onClose,
}: {
  selectedStore: MapStore | null
  bestOptionId: string
  bestSummary?: string
  onClose: () => void
}) {
  if (!selectedStore) return null
  return (
    <Popup position={[selectedStore.lat, selectedStore.lng]} eventHandlers={{ remove: onClose }}>
      <StorePopup
        name={selectedStore.name}
        address={selectedStore.address}
        distanceKm={selectedStore.distanceKm}
        durationMinutes={selectedStore.durationMinutes}
        reportedPrice={selectedStore.reportedPrice}
        lat={selectedStore.lat}
        lng={selectedStore.lng}
        summary={selectedStore.id === bestOptionId ? bestSummary : undefined}
      />
    </Popup>
  )
}

export default function MapView({
  googleMapsApiKey,
  userLat,
  userLng,
  stores,
  bestOptionId,
  selectedId,
  onSelectStore,
  bestSummary,
}: MapViewProps) {
  const useGoogleMaps = Boolean(googleMapsApiKey)
  if (useGoogleMaps && googleMapsApiKey) {
    return (
      <div className="h-full w-full min-h-[300px] rounded-lg z-0">
        <GoogleMapView
          googleMapsApiKey={googleMapsApiKey}
          userLat={userLat}
          userLng={userLng}
          stores={stores}
          bestOptionId={bestOptionId}
          selectedId={selectedId}
          onSelectStore={onSelectStore}
          bestSummary={bestSummary}
        />
      </div>
    )
  }
  return (
    <MapContainer
      center={[userLat, userLng]}
      zoom={13}
      className="h-full w-full min-h-[300px] rounded-lg z-0"
      scrollWheelZoom={true}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <FitBounds stores={stores} userLat={userLat} userLng={userLng} />
      <PanToSelected selectedId={selectedId} stores={stores} />
      <SelectedStorePopup
        selectedStore={selectedId ? stores.find((s) => s.id === selectedId) ?? null : null}
        bestOptionId={bestOptionId}
        bestSummary={bestSummary}
        onClose={() => onSelectStore(null)}
      />
      <Marker position={[userLat, userLng]} icon={userLocationIcon} zIndexOffset={1000}>
        <Popup>
          <span className="text-sm font-medium text-primary-900">You are here</span>
        </Popup>
      </Marker>
      {stores.map((store) => (
        <Marker
          key={store.id}
          position={[store.lat, store.lng]}
          icon={createIcon(store.id === bestOptionId)}
          eventHandlers={{
            click: () => onSelectStore(store.id === selectedId ? null : store.id),
          }}
        />
      ))}
    </MapContainer>
  )
}
