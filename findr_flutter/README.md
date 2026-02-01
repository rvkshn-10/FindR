# FindR Flutter (Dart)

Supply Map rewritten in **Dart/Flutter**: find items nearby, see stores on a map, get road distances via OSRM.

## Complete setup and run

**→ See [SETUP.md](SETUP.md) for step-by-step instructions** to finish the conversion and get the app running (Flutter create, pub get, run, and optional location permissions).

Quick version:

```bash
cd findr_flutter
flutter create . --project-name findr_flutter   # first time only: adds android/ios/web
flutter pub get
flutter run -d chrome
```

## Requirements

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0+)

## Run

- **Web:** `flutter run -d chrome`
- **Android:** `flutter run -d android`
- **iOS:** `flutter run -d ios`

## Features (Dart implementation)

- **Search:** Item + “Use my location” or city/address (Nominatim geocoding)
- **Stores:** Overpass API (shops/amenities nearby)
- **Distances:** OSRM Table API (road distance/duration, no API key)
- **Map:** flutter_map + OpenStreetMap tiles
- **Settings:** Distance unit (mi/km), currency (in-memory)

AI ranking and Google Maps are not included in this Dart version; use the Next.js app or add a small backend if you need them.

## Project layout

- `lib/main.dart` – App entry, Provider, MaterialApp
- `lib/models/store.dart` – Store, SearchResult
- `lib/services/` – geocode, overpass, OSRM, distance, search
- `lib/providers/settings_provider.dart` – Distance unit, currency
- `lib/screens/` – Search, Results (map + list), Settings
