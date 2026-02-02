import 'dart:convert';
import 'package:http/http.dart' as http;

const _osrmBase = 'https://router.project-osrm.org/table/v1/driving';
const _maxDest = 25;
const _timeout = Duration(seconds: 12);

class RoadDistanceResult {
  final double distanceKm;
  final int? durationMinutes;

  RoadDistanceResult({required this.distanceKm, this.durationMinutes});
}

Future<List<RoadDistanceResult>?> getRoadDistancesOsrm(
  double originLat,
  double originLng,
  List<MapEntry<double, double>> destinations,
) async {
  if (destinations.isEmpty) return null;
  final allResults = <RoadDistanceResult>[];
  for (var i = 0; i < destinations.length; i += _maxDest) {
    final end = (i + _maxDest > destinations.length) ? destinations.length : i + _maxDest;
    final chunk = destinations.sublist(i, end);
    final coords = [
      '$originLng,$originLat',
      ...chunk.map((e) => '${e.value},${e.key}'),
    ].join(';');
    final destIndices = List.generate(chunk.length, (j) => j + 1).join(';');
    // Request duration and distance; some OSRM servers only support duration.
    Uri uri = Uri.parse('$_osrmBase/$coords').replace(
      queryParameters: {'sources': '0', 'destinations': destIndices, 'annotations': 'duration,distance'},
    );
    var res = await http.get(uri).timeout(_timeout);
    var data = res.statusCode == 200 ? jsonDecode(res.body) as Map<String, dynamic>? : null;
    // If server rejects annotations (e.g. "annotations has an error"), retry without it.
    if (data == null || data['code'] != 'Ok' || data['annotations'] == 'error') {
      uri = Uri.parse('$_osrmBase/$coords').replace(
        queryParameters: {'sources': '0', 'destinations': destIndices},
      );
      res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
    }
    final durations = data['durations'] as List<dynamic>?;
    final distances = data['distances'] as List<dynamic>?;
    if (durations == null || distances == null) return null;
    final durRow = durations[0] as List<dynamic>?;
    final distRow = distances[0] as List<dynamic>?;
    if (durRow == null || distRow == null || durRow.length != chunk.length) return null;
    for (var j = 0; j < chunk.length; j++) {
      final distM = distRow[j];
      final durS = durRow[j];
      final distanceKm = (distM != null && distM is num)
          ? ((distM / 1000) * 100).round() / 100
          : 0.0;
      final durationMinutes = (durS != null && durS is num) ? (durS / 60).round() : null;
      allResults.add(RoadDistanceResult(distanceKm: distanceKm, durationMinutes: durationMinutes));
    }
  }
  return allResults;
}
