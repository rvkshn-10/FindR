import 'dart:convert';
import 'package:http/http.dart' as http;

const _nominatimBase = 'https://nominatim.openstreetmap.org/search';
const _userAgent = 'FindR/1.0 (Flutter; contact via project repo)';

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
  final uri = Uri.parse(_nominatimBase).replace(
    queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '1',
      'addressdetails': '0',
    },
  );
  final res = await http.get(
    uri,
    headers: {'User-Agent': _userAgent},
  );
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
