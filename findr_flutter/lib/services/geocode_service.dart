import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class GeocodeResult {
  final double lat;
  final double lng;
  final String displayName;

  GeocodeResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });
}

Future<GeocodeResult?> geocode(String query) async {
  print('[Wayvio] Geocoding: "$query"');
  try {
    final uri = Uri.parse(kNominatimBase).replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '1',
        'addressdetails': '0',
      },
    );
    print('[Wayvio] Geocode URL: $uri');
    final res = await http
        .get(uri, headers: {'User-Agent': kHttpUserAgent})
        .timeout(kGeocodeTimeout);
    print('[Wayvio] Geocode HTTP ${res.statusCode}, body length=${res.body.length}');
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null || list.isEmpty) {
      print('[Wayvio] Geocode: empty results for "$query"');
      return null;
    }
    final first = list.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) {
      print('[Wayvio] Geocode: could not parse lat/lon');
      return null;
    }
    print('[Wayvio] Geocode success: $lat, $lon');
    return GeocodeResult(
      lat: lat,
      lng: lon,
      displayName: first['display_name']?.toString() ?? '',
    );
  } catch (e) {
    print('[Wayvio] Geocode error: $e');
    return null;
  }
}
