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

/// Build a SerpApi URL.
///
/// On **web** the request routes through a CORS proxy because browsers block
/// direct cross-origin requests to serpapi.com.
/// When the Firebase project is upgraded to the Blaze plan, the Cloud Function
/// proxy at `/api/serpapi` can be used instead (uncomment the block below).
///
/// On **native** (macOS, iOS, Android) we call serpapi.com directly because
/// there are no CORS restrictions.
Uri buildSerpApiUri(Map<String, String> params) {
  final fullParams = Map<String, String>.from(params);
  fullParams['api_key'] = kSerpApiKey;
  final directUrl = Uri.https('serpapi.com', '/search.json', fullParams);

  if (kIsWeb) {
    // Route through a CORS proxy on web.
    // Once Firebase is on Blaze plan, switch to the Cloud Function proxy:
    //   final cleanParams = Map<String, String>.from(params)..remove('api_key');
    //   return Uri(path: '/api/serpapi', queryParameters: cleanParams);
    return Uri.parse(
      'https://corsproxy.io/?${Uri.encodeComponent(directUrl.toString())}',
    );
  }

  return directUrl;
}
