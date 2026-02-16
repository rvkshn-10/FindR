// Centralised configuration constants for FindR.
//
// Keep all API URLs, timeouts, default values, and magic numbers here so
// there is a single source of truth and they are easy to tune.

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
