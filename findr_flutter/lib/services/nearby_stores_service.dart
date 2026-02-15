import 'dart:convert';
import 'package:http/http.dart' as http;
import 'distance_util.dart';

import '../config.dart';

class OverpassStore {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final double distanceKm;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? brand;

  OverpassStore({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    required this.distanceKm,
    this.phone,
    this.website,
    this.openingHours,
    this.brand,
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

/// Returns true if the Overpass JSON response indicates an error (e.g. remark with "runtime error").
bool _isErrorResponse(Map<String, dynamic> data) {
  final remark = data['remark']?.toString() ?? '';
  if (remark.toLowerCase().contains('runtime error') ||
      remark.toLowerCase().contains('rate limit') ||
      remark.toLowerCase().contains('timeout')) {
    return true;
  }
  return false;
}

Future<List<OverpassStore>> _fetchFromEndpoint(
  String baseUrl,
  String query,
  double lat,
  double lng,
) async {
  final res = await http
      .post(
        Uri.parse(baseUrl),
        body: query,
        headers: {'Content-Type': 'text/plain'},
      )
      .timeout(kOverpassTimeout);
  if (res.statusCode != 200) {
    throw Exception('Overpass failed: ${res.statusCode}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (_isErrorResponse(data)) {
    final remark = data['remark']?.toString() ?? 'Unknown error';
    throw Exception('Overpass error: $remark');
  }
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
      phone: tags?['phone']?.toString() ?? tags?['contact:phone']?.toString(),
      website: tags?['website']?.toString() ?? tags?['contact:website']?.toString(),
      openingHours: tags?['opening_hours']?.toString(),
      brand: tags?['brand']?.toString(),
    ));
  }
  stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return stores;
}

/// Race all Overpass endpoints in parallel and return the first success.
Future<List<OverpassStore>> fetchNearbyStores(
  double lat,
  double lng, {
  int radiusM = kDefaultOverpassRadiusM,
}) async {
  final query = '''
[out:json][timeout:10];
(
  nwr["shop"](around:$radiusM,$lat,$lng);
  nwr["amenity"~"marketplace|pharmacy|fuel"](around:$radiusM,$lat,$lng);
);
out center;
''';

  // Fire all endpoints in parallel, return the first successful result.
  final futures = kOverpassEndpoints.map(
    (url) => _fetchFromEndpoint(url, query, lat, lng),
  );

  // Use Future.any to get the first one that completes successfully.
  // If all fail, we need to catch and throw.
  Object? lastError;
  try {
    return await Future.any(futures);
  } catch (e) {
    lastError = e;
  }

  // Future.any throws if the first future to complete throws, but others
  // may still succeed. Fall back to sequential if Future.any fails fast.
  for (final baseUrl in kOverpassEndpoints) {
    try {
      return await _fetchFromEndpoint(baseUrl, query, lat, lng);
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? Exception('Overpass failed');
}
