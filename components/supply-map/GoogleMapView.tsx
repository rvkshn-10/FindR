'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useJsApiLoader, GoogleMap, Marker, InfoWindow } from '@react-google-maps/api'
import StorePopup from './StorePopup'

const DEFAULT_ZOOM = 13

function getUserLocationIcon(): google.maps.Symbol {
  return {
    path: google.maps.SymbolPath.CIRCLE,
    scale: 10,
    fillColor: '#2563eb',
    fillOpacity: 1,
    strokeColor: '#ffffff',
    strokeWeight: 3,
  }
}

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

interface GoogleMapViewProps {
  googleMapsApiKey: string
  userLat: number
  userLng: number
  stores: MapStore[]
  bestOptionId: string
  selectedId: string | null
  onSelectStore: (id: string | null) => void
  bestSummary?: string
}

function MapContent({
  userLat,
  userLng,
  stores,
  bestOptionId,
  selectedId,
  onSelectStore,
  bestSummary,
}: GoogleMapViewProps) {
  const mapRef = useRef<google.maps.Map | null>(null)
  const markerRefs = useRef<Record<string, google.maps.Marker>>({})
  const [userMarkerOpen, setUserMarkerOpen] = useState(false)

  const onMapLoad = useCallback((map: google.maps.Map) => {
    mapRef.current = map
    const bounds = new google.maps.LatLngBounds()
    bounds.extend({ lat: userLat, lng: userLng })
    stores.forEach((s) => bounds.extend({ lat: s.lat, lng: s.lng }))
    if (stores.length > 0) {
      map.fitBounds(bounds, { top: 40, right: 40, bottom: 40, left: 40 })
      const listener = google.maps.event.addListener(map, 'idle', () => {
        if (map.getZoom() && map.getZoom()! > 14) map.setZoom(14)
        google.maps.event.removeListener(listener)
      })
    } else {
      map.setCenter({ lat: userLat, lng: userLng })
      map.setZoom(14)
    }
  }, [userLat, userLng, stores])

  const selectedStore = selectedId ? stores.find((s) => s.id === selectedId) : null
  const selectedMarker = selectedId ? markerRefs.current[selectedId] : null
  const userLocationIcon = useMemo(getUserLocationIcon, [])

  useEffect(() => {
    if (!mapRef.current || !selectedStore) return
    mapRef.current.panTo({ lat: selectedStore.lat, lng: selectedStore.lng })
    const z = mapRef.current.getZoom()
    if (z != null && z < 15) mapRef.current.setZoom(15)
  }, [selectedId, selectedStore])

  return (
    <GoogleMap
      mapContainerStyle={{ width: '100%', height: '100%', borderRadius: '0.5rem' }}
      center={{ lat: userLat, lng: userLng }}
      zoom={DEFAULT_ZOOM}
      onLoad={onMapLoad}
      onClick={() => onSelectStore(null)}
      options={{ scrollwheel: true }}
    >
      <Marker
        position={{ lat: userLat, lng: userLng }}
        title="You are here"
        zIndex={1000}
        icon={userLocationIcon}
        onClick={() => setUserMarkerOpen((open) => !open)}
      />
      {userMarkerOpen && (
        <InfoWindow
          position={{ lat: userLat, lng: userLng }}
          onCloseClick={() => setUserMarkerOpen(false)}
        >
          <span className="text-sm font-medium text-primary-900">You are here</span>
        </InfoWindow>
      )}
      {stores.map((store) => (
        <Marker
          key={store.id}
          position={{ lat: store.lat, lng: store.lng }}
          title={store.name}
          onClick={() => onSelectStore(store.id === selectedId ? null : store.id)}
          onLoad={(marker) => {
            markerRefs.current[store.id] = marker
          }}
          onUnmount={(marker) => {
            delete markerRefs.current[store.id]
          }}
        />
      ))}
      {selectedStore && selectedMarker && (
        <InfoWindow
          key={selectedId}
          anchor={selectedMarker}
          onCloseClick={() => onSelectStore(null)}
        >
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
        </InfoWindow>
      )}
    </GoogleMap>
  )
}

export default function GoogleMapView(props: GoogleMapViewProps) {
  const { googleMapsApiKey: key, ...rest } = props
  const { isLoaded, loadError } = useJsApiLoader({
    googleMapsApiKey: key,
  })

  if (!key) return null
  if (loadError) return <div className="p-4 text-red-600">Google Maps failed to load.</div>
  if (!isLoaded) {
    return (
      <div className="h-full w-full min-h-[300px] rounded-lg bg-primary-100 flex items-center justify-center">
        <span className="text-primary-600">Loading map…</span>
      </div>
    )
  }

  return (
    <div className="h-full w-full min-h-[300px] rounded-lg overflow-hidden">
      <MapContent {...rest} googleMapsApiKey={key} />
    </div>
  )
}
