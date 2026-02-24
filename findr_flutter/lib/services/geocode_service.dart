import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class GeocodeResult {
  final double lat;
  final double lng;
  final String displayName;

  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });
}

Future<GeocodeResult?> geocode(String query) async {
  debugPrint('[Wayvio] Geocoding: "$query"');
  try {
    final uri = Uri.parse(kNominatimBase).replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '1',
        'addressdetails': '0',
      },
    );
    debugPrint('[Wayvio] Geocode URL: $uri');
    final res = await http
        .get(uri, headers: {'User-Agent': kHttpUserAgent})
        .timeout(kGeocodeTimeout);
    debugPrint('[Wayvio] Geocode HTTP ${res.statusCode}, body length=${res.body.length}');
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null || list.isEmpty) {
      debugPrint('[Wayvio] Geocode: empty results for "$query"');
      return null;
    }
    final first = list.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) {
      debugPrint('[Wayvio] Geocode: could not parse lat/lon');
      return null;
    }
    debugPrint('[Wayvio] Geocode success: $lat, $lon');
    return GeocodeResult(
      lat: lat,
      lng: lon,
      displayName: first['display_name']?.toString() ?? '',
    );
  } catch (e) {
    debugPrint('[Wayvio] Geocode error: $e');
    return null;
  }
}
