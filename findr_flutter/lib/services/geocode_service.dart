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
  final uri = Uri.parse(kNominatimBase).replace(
    queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '1',
      'addressdetails': '0',
    },
  );
  final res = await http
      .get(uri, headers: {'User-Agent': kHttpUserAgent})
      .timeout(kGeocodeTimeout);
  if (res.statusCode != 200) return null;
  final list = jsonDecode(res.body) as List<dynamic>?;
  if (list == null || list.isEmpty) return null;
  final first = list.first as Map<String, dynamic>;
  final lat = double.tryParse(first['lat']?.toString() ?? '');
  final lon = double.tryParse(first['lon']?.toString() ?? '');
  if (lat == null || lon == null) return null;
  return GeocodeResult(
    lat: lat,
    lng: lon,
    displayName: first['display_name']?.toString() ?? '',
  );
}
