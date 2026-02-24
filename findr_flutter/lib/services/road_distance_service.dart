import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class RoadDistanceResult {
  final double distanceKm;
  final int? durationMinutes;

  const RoadDistanceResult({required this.distanceKm, this.durationMinutes});
}

/// Fetch a single chunk of road distances from OSRM.
Future<List<RoadDistanceResult>?> _fetchChunk(
  double originLat,
  double originLng,
  List<MapEntry<double, double>> chunk,
) async {
  try {
    final coords = [
      '$originLng,$originLat',
      ...chunk.map((e) => '${e.value},${e.key}'),
    ].join(';');
    final destIndices = List.generate(chunk.length, (j) => j + 1).join(';');

    Uri uri = Uri.parse('$kOsrmBase/$coords').replace(
      queryParameters: {'sources': '0', 'destinations': destIndices, 'annotations': 'duration,distance'},
    );
    var res = await http.get(uri).timeout(kOsrmTimeout);
    var data = res.statusCode == 200 ? jsonDecode(res.body) as Map<String, dynamic>? : null;

    // If server rejects the request, retry without annotations.
    if (data == null || data['code'] != 'Ok') {
      uri = Uri.parse('$kOsrmBase/$coords').replace(
        queryParameters: {'sources': '0', 'destinations': destIndices},
      );
      res = await http.get(uri).timeout(kOsrmTimeout);
      if (res.statusCode != 200) return null;
      data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
    }

    final durations = data['durations'] as List<dynamic>?;
    final distances = data['distances'] as List<dynamic>?;
    if (durations == null) return null;
    final durRow = durations[0] as List<dynamic>?;
    final distRow = distances != null ? distances[0] as List<dynamic>? : null;
    if (durRow == null || durRow.length != chunk.length) return null;

    final results = <RoadDistanceResult>[];
    for (var j = 0; j < chunk.length; j++) {
      final distM = distRow?[j];
      final durS = durRow[j];
      final distanceKm = (distM != null && distM is num)
          ? ((distM / 1000) * 100).round() / 100
          : 0.0;
      final durationMinutes = (durS != null && durS is num) ? (durS / 60).round() : null;
      results.add(RoadDistanceResult(distanceKm: distanceKm, durationMinutes: durationMinutes));
    }
    return results;
  } catch (e) {
    debugPrint('[Wayvio] OSRM chunk error: $e');
    return null;
  }
}

/// Get road distances for all destinations, chunking into groups of [kMaxOsrmDest]
/// and running all chunks in parallel.
Future<List<RoadDistanceResult>?> getRoadDistancesOsrm(
  double originLat,
  double originLng,
  List<MapEntry<double, double>> destinations,
) async {
  if (destinations.isEmpty) return null;

  // Split into chunks
  final chunks = <List<MapEntry<double, double>>>[];
  for (var i = 0; i < destinations.length; i += kMaxOsrmDest) {
    final end = (i + kMaxOsrmDest > destinations.length) ? destinations.length : i + kMaxOsrmDest;
    chunks.add(destinations.sublist(i, end));
  }

  // Run all chunks in parallel
  final futures = chunks.map((chunk) => _fetchChunk(originLat, originLng, chunk));
  final chunkResults = await Future.wait(futures);

  // Merge results in order
  final allResults = <RoadDistanceResult>[];
  for (final result in chunkResults) {
    if (result == null) return null;
    allResults.addAll(result);
  }
  return allResults;
}
