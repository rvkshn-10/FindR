import 'dart:math';

const double earthRadiusKm = 6371.0;
const double kmToMiles = 0.621371;
const double milesToKm = 1.60934;

/// Great-circle distance (haversine) in km.
double haversineKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _rad(double deg) => deg * pi / 180;

double kmToMilesFn(double km) => km * kmToMiles;
double milesToKmFn(double mi) => mi * milesToKm;

/// Format distance in km as short string (e.g. "1.2 mi" or "2 km").
String formatDistance(double km, {bool useKm = false}) {
  if (useKm) {
    if (km < 0.1) return '< 0.1 km';
    if (km < 1) return '${km.toStringAsFixed(1)} km';
    if (km < 10) return '${(km * 10).round() / 10} km';
    return '${km.round()} km';
  }
  final mi = km * kmToMiles;
  if (mi < 0.1) return '< 0.1 mi';
  if (mi < 1) return '${mi.toStringAsFixed(1)} mi';
  if (mi < 10) return '${(mi * 10).round() / 10} mi';
  return '${mi.round()} mi';
}

/// Format max distance filter (e.g. "5 mi" or "8 km").
String formatMaxDistance(double miles, {bool useKm = false}) {
  if (useKm) {
    final km = miles * milesToKm;
    return km < 1 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }
  return '${miles.round()} mi';
}
