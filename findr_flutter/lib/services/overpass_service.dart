import 'dart:convert';
import 'package:http/http.dart' as http;
import 'distance_util.dart';

const _overpassBase = 'https://overpass-api.de/api/interpreter';
const _defaultRadiusM = 5000;
const _timeout = Duration(seconds: 20);

class OverpassStore {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final double distanceKm;

  OverpassStore({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    required this.distanceKm,
  });
}

String _getDisplayName(Map<String, dynamic>? tags) {
  if (tags == null) return 'Unnamed store';
  return tags['name']?.toString() ?? tags['brand']?.toString() ?? 'Unnamed store';
}

String _getAddress(Map<String, dynamic>? tags) {
  if (tags == null) return '';
  final parts = <String?>[
    tags['addr:street']?.toString(),
    tags['addr:housenumber']?.toString(),
    tags['addr:city'] ?? tags['addr:town'] ?? tags['addr:village'],
    tags['addr:state']?.toString(),
    tags['addr:postcode']?.toString(),
  ];
  return parts.whereType<String>().join(', ');
}

Future<List<OverpassStore>> fetchNearbyStores(
  double lat,
  double lng, {
  int radiusM = _defaultRadiusM,
}) async {
  final query = '''
[out:json][timeout:12];
(
  nwr["shop"](around:$radiusM,$lat,$lng);
  nwr["amenity"~"marketplace|pharmacy|fuel"](around:$radiusM,$lat,$lng);
);
out center;
''';
  final res = await http
      .post(
        Uri.parse(_overpassBase),
        body: query,
        headers: {'Content-Type': 'text/plain'},
      )
      .timeout(_timeout);
  if (res.statusCode != 200) throw Exception('Overpass failed: ${res.statusCode}');
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final elements = data['elements'] as List<dynamic>? ?? [];
  final stores = <OverpassStore>[];
  final seen = <String>{};

  for (final el in elements) {
    final m = el as Map<String, dynamic>;
    final type = m['type']?.toString() ?? '';
    final idNum = m['id'];
    final elLat = m['lat'] ?? (m['center'] as Map?)?['lat'];
    final elLon = m['lon'] ?? (m['center'] as Map?)?['lon'];
    if (elLat == null || elLon == null) continue;
    final latV = (elLat is num) ? elLat.toDouble() : double.tryParse(elLat.toString());
    final lngV = (elLon is num) ? elLon.toDouble() : double.tryParse(elLon.toString());
    if (latV == null || lngV == null) continue;
    final id = '$type/$idNum';
    if (seen.contains(id)) continue;
    seen.add(id);
    final tags = m['tags'] as Map<String, dynamic>?;
    final name = _getDisplayName(tags);
    final address = _getAddress(tags);
    final distanceKm = haversineKm(lat, lng, latV, lngV);
    stores.add(OverpassStore(
      id: id,
      name: name,
      lat: latV,
      lng: lngV,
      address: address,
      distanceKm: (distanceKm * 100).round() / 100,
    ));
  }
  stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return stores;
}
