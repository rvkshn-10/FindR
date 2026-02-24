import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'distance_util.dart';

/// A point along a route.
class RoutePoint {
  final double lat;
  final double lng;
  const RoutePoint(this.lat, this.lng);
}

/// Result of evaluating a candidate store against a route.
class DeviationResult {
  final String storeId;
  final double detourMinutes;
  final double minDistToRouteKm;

  const DeviationResult({
    required this.storeId,
    required this.detourMinutes,
    required this.minDistToRouteKm,
  });
}

/// Fetch the full route from OSRM and decode the polyline into waypoints.
Future<List<RoutePoint>?> fetchRouteWaypoints(
    double originLat, double originLng,
    double destLat, double destLng) async {
  try {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '$originLng,$originLat;$destLng,$destLat'
        '?overview=full&geometries=geojson';
    final res = await http.get(Uri.parse(url)).timeout(kOsrmTimeout);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') return null;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return null;
    final coords = geometry['coordinates'] as List<dynamic>?;
    if (coords == null) return null;
    return coords.map((c) {
      final pair = c as List<dynamic>;
      return RoutePoint(
          (pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
  } catch (e) {
    debugPrint('[Wayvio] fetchRouteWaypoints error: $e');
    return null;
  }
}

/// Get the direct route duration in minutes.
Future<double?> fetchDirectDuration(
    double originLat, double originLng,
    double destLat, double destLng) async {
  try {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '$originLng,$originLat;$destLng,$destLat'
        '?overview=false';
    final res = await http.get(Uri.parse(url)).timeout(kOsrmTimeout);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') return null;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final dur = routes[0]['duration'] as num?;
    return dur != null ? dur.toDouble() / 60.0 : null;
  } catch (_) {
    return null;
  }
}

/// Sample waypoints along the route every ~1km.
List<RoutePoint> sampleWaypoints(List<RoutePoint> fullRoute,
    {double intervalKm = 1.0}) {
  if (fullRoute.length <= 2) return fullRoute;
  final sampled = <RoutePoint>[fullRoute.first];
  double accum = 0;
  for (var i = 1; i < fullRoute.length; i++) {
    final d = haversineKm(
        fullRoute[i - 1].lat, fullRoute[i - 1].lng,
        fullRoute[i].lat, fullRoute[i].lng);
    accum += d;
    if (accum >= intervalKm) {
      sampled.add(fullRoute[i]);
      accum = 0;
    }
  }
  if (sampled.last != fullRoute.last) sampled.add(fullRoute.last);
  return sampled;
}

/// Compute minimum haversine distance from a point to any route waypoint.
double minDistToRoute(
    double lat, double lng, List<RoutePoint> waypoints) {
  double minD = double.infinity;
  for (final wp in waypoints) {
    final d = haversineKm(lat, lng, wp.lat, wp.lng);
    if (d < minD) minD = d;
  }
  return minD;
}

/// Compute the detour time for going origin -> store -> destination
/// versus origin -> destination directly, using OSRM table API.
Future<double?> computeDetourMinutes(
    double originLat, double originLng,
    double storeLat, double storeLng,
    double destLat, double destLng,
    double? directMinutes) async {
  try {
    final coords =
        '$originLng,$originLat;$storeLng,$storeLat;$destLng,$destLat';
    final url =
        'https://router.project-osrm.org/table/v1/driving/$coords'
        '?sources=0;1&destinations=1;2';
    final res = await http.get(Uri.parse(url)).timeout(kOsrmTimeout);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') return null;
    final durations = data['durations'] as List<dynamic>?;
    if (durations == null || durations.length < 2) return null;
    final row0 = durations[0] as List<dynamic>;
    final row1 = durations[1] as List<dynamic>;
    final toStore = (row0[0] as num?)?.toDouble() ?? 0;
    final storeToEnd = (row1[1] as num?)?.toDouble() ?? 0;
    final totalVia = (toStore + storeToEnd) / 60.0;
    final direct = directMinutes ?? totalVia;
    return totalVia - direct;
  } catch (_) {
    return null;
  }
}

/// Evaluate multiple store candidates against a route.
/// Returns results sorted by detour time (ascending).
Future<List<DeviationResult>> evaluateStoresOnRoute({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  required List<({String id, double lat, double lng})> stores,
  double maxDetourMinutes = 10,
}) async {
  final waypoints = await fetchRouteWaypoints(
      originLat, originLng, destLat, destLng);
  if (waypoints == null || waypoints.isEmpty) return [];

  final sampled = sampleWaypoints(waypoints);
  final directMin = await fetchDirectDuration(
      originLat, originLng, destLat, destLng);

  // Filter candidates close to the route first (within ~3km)
  final nearby = stores.where((s) {
    final d = minDistToRoute(s.lat, s.lng, sampled);
    return d <= 3.0;
  }).toList();

  final results = <DeviationResult>[];
  for (final s in nearby) {
    final detour = await computeDetourMinutes(
        originLat, originLng, s.lat, s.lng,
        destLat, destLng, directMin);
    if (detour != null && detour <= maxDetourMinutes) {
      results.add(DeviationResult(
        storeId: s.id,
        detourMinutes: detour,
        minDistToRouteKm: minDistToRoute(s.lat, s.lng, sampled),
      ));
    }
  }

  results.sort((a, b) => a.detourMinutes.compareTo(b.detourMinutes));
  return results;
}
