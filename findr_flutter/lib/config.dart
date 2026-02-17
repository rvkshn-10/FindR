// Centralised configuration constants for FindR.
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

const String kHttpUserAgent = 'FindR/1.0 (Flutter; contact via project repo)';

// ---------------------------------------------------------------------------
// Timeouts
// ---------------------------------------------------------------------------

const Duration kGeocodeTimeout = Duration(seconds: 10);
const Duration kOverpassTimeout = Duration(seconds: 12);
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
// Search radius bounds (miles, user-facing)
// ---------------------------------------------------------------------------

const double kMinRadiusMiles = 1;
const double kMaxRadiusMiles = 25;
const double kDefaultRadiusMiles = 5;

// ---------------------------------------------------------------------------
// Input limits
// ---------------------------------------------------------------------------

const int kMaxLocationLength = 200;

// ---------------------------------------------------------------------------
// AI (Gemini)
// ---------------------------------------------------------------------------

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

/// CORS proxies to try in order on web.  Each wraps the SerpApi URL
/// differently, so we template them with {URL} as a placeholder.
const List<String> kCorsProxies = [
  'https://corsproxy.io/?{URL}',
  'https://api.allorigins.win/raw?url={URL}',
  'https://api.codetabs.com/v1/proxy?quest={URL}',
];

/// On web, try multiple CORS proxies to reach SerpApi.
/// On native, calls serpapi.com directly.
/// Returns the proxy-wrapped URI to use, or the direct URI on native.
List<Uri> buildSerpApiUris(Map<String, String> params) {
  final directUrl = buildSerpApiUri(params);

  if (!kIsWeb) return [directUrl];

  // Once Firebase is on Blaze plan, switch to the Cloud Function proxy:
  //   final cleanParams = Map<String, String>.from(params)..remove('api_key');
  //   return [Uri(path: '/api/serpapi', queryParameters: cleanParams)];

  final encoded = Uri.encodeComponent(directUrl.toString());
  return kCorsProxies
      .map((template) => Uri.parse(template.replaceAll('{URL}', encoded)))
      .toList();
}
