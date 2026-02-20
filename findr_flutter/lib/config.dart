// Centralised configuration constants for Wayvio.
//
// Keep all API URLs, timeouts, default values, and magic numbers here so
// there is a single source of truth and they are easy to tune.

import 'package:flutter/foundation.dart' show kIsWeb;

// ---------------------------------------------------------------------------
// API endpoints
// ---------------------------------------------------------------------------

const String kNominatimBase = 'https://nominatim.openstreetmap.org/search';
const String kOsrmBase = 'https://router.project-osrm.org/table/v1/driving';
const List<String> kOverpassEndpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];
const String kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kTileUserAgent = 'com.findr.findr_flutter';

// ---------------------------------------------------------------------------
// HTTP user-agent
// ---------------------------------------------------------------------------

const String kHttpUserAgent = 'Wayvio/1.0 (Flutter; contact via project repo)';

// ---------------------------------------------------------------------------
// Timeouts
// ---------------------------------------------------------------------------

const Duration kGeocodeTimeout = Duration(seconds: 10);
const Duration kOverpassTimeout = Duration(seconds: 20);
const Duration kOsrmTimeout = Duration(seconds: 10);

// ---------------------------------------------------------------------------
// Store search defaults
// ---------------------------------------------------------------------------

const int kMaxStoresDisplay = 10;
const int kMaxStoresForRoad = 25;
const int kMaxOsrmDest = 25;
const double kAvgSpeedKmh = 50.0;
const int kDefaultOverpassRadiusM = 5000;

// ---------------------------------------------------------------------------
// Map defaults
// ---------------------------------------------------------------------------

const double kMapInitialZoom = 14.0;
const double kMapSelectZoom = 17.5;

// ---------------------------------------------------------------------------
// AI (Gemini)
// ---------------------------------------------------------------------------

const String kGeminiApiKey = 'AIzaSyBtmZKzv2ZSBuXv4PHcVHbKHxxBfGUrZtw';
const Duration kAiTimeout = Duration(seconds: 10);

// ---------------------------------------------------------------------------
// SerpApi (Google Shopping prices)
// ---------------------------------------------------------------------------

/// Your SerpApi API key.  Sign up free at https://serpapi.com (100 searches/mo).
/// Leave empty to disable price lookups and Google Maps store search.
const String kSerpApiKey = '3c98c1ad2a12891b404f04b5183fc31781b0fd08aed9da9a2d5a21cb296426c0';

const Duration kSerpApiTimeout = Duration(seconds: 15);

// ---------------------------------------------------------------------------
// Kroger API (Locations + Products)
// ---------------------------------------------------------------------------

/// Kroger API Client ID.  Register at https://developer.kroger.com
const String kKrogerClientId = 'findr-bbccpcdg';

/// Kroger API Client Secret.
const String kKrogerClientSecret = '61jjPy8_xnYsa8jQWb-FqGIBW9KI-fJVeiNzXBoY';

const String kKrogerBaseUrl = 'https://api.kroger.com/v1';
const Duration kKrogerTimeout = Duration(seconds: 12);

/// Build a SerpApi URL (direct, without proxy).
///
/// On **web**, use [fetchSerpApiWithProxy] instead which tries multiple
/// CORS proxies.  On **native** (macOS, iOS, Android) we call serpapi.com
/// directly because there are no CORS restrictions.
Uri buildSerpApiUri(Map<String, String> params) {
  final fullParams = Map<String, String>.from(params);
  fullParams['api_key'] = kSerpApiKey;
  return Uri.https('serpapi.com', '/search.json', fullParams);
}

/// On web, SerpApi is unavailable (CORS). Returns empty list so callers
/// skip SerpApi gracefully. On native, calls serpapi.com directly.
///
/// To re-enable on web, deploy the Cloud Function proxy (requires Blaze plan)
/// and return [Uri(path: '/api/serpapi', queryParameters: cleanParams)].
List<Uri> buildSerpApiUris(Map<String, String> params) {
  if (kIsWeb) return [];  // no server-side proxy available yet
  return [buildSerpApiUri(params)];
}
