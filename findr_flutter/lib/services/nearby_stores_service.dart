import 'dart:convert';
import 'package:http/http.dart' as http;
import 'distance_util.dart';
import 'product_store_mapper.dart';

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
  final String? shopType;   // OSM shop=* tag value (e.g. "supermarket", "bakery")
  final String? amenityType; // OSM amenity=* tag value (e.g. "pharmacy", "fuel")
  final double? rating;      // Google Maps rating (1-5)
  final int? reviewCount;    // Google Maps review count
  final String? priceLevel;  // Google Maps price level ("$", "$$", "$$$")
  final String? thumbnail;   // URL to store photo
  final List<String> serviceOptions; // e.g. ["In-store shopping", "Delivery"]

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
    this.shopType,
    this.amenityType,
    this.rating,
    this.reviewCount,
    this.priceLevel,
    this.thumbnail,
    this.serviceOptions = const [],
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
    if (idNum == null) continue;
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
      shopType: tags?['shop']?.toString(),
      amenityType: tags?['amenity']?.toString(),
    ));
  }
  stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return stores;
}

/// Race all Overpass endpoints in parallel and return the first success.
///
/// When [item] is provided, the Overpass query is narrowed to shop/amenity
/// types that are relevant to that product (e.g. "batteries" will search
/// electronics stores, hardware stores, supermarkets -- but NOT bakeries).
Future<List<OverpassStore>> fetchNearbyStores(
  double lat,
  double lng, {
  int radiusM = kDefaultOverpassRadiusM,
  String? item,
}) async {
  // Build targeted shop & amenity regex filters based on the search term.
  final filterResult = (item != null && item.trim().isNotEmpty)
      ? filtersForItem(item)
      : const ItemFilterResult(matched: false);

  // Build Overpass union clauses based on what the mapper returned.
  final clauses = <String>[];

  if ((filterResult.isDining || filterResult.isService) && item != null) {
    // --- DINING / SERVICE SEARCH ---
    // Do NOT use broad "amenity~restaurant|fast_food" — that returns every
    // restaurant/service in the area (thousands) and causes Overpass to timeout.
    // Instead use targeted searches: name match, brand match, and type match.
    final lower = item.toLowerCase().trim();

    if (filterResult.amenityFilter != null) {
      final amenities = filterResult.amenityFilter!;
      // 1. Match by name.
      clauses.add('nwr["amenity"~"$amenities"]["name"~"$lower",i](around:$radiusM,$lat,$lng);');
      // 2. Match by brand tag.
      clauses.add('nwr["amenity"~"$amenities"]["brand"~"$lower",i](around:$radiusM,$lat,$lng);');
      if (filterResult.isDining) {
        // 3. Match by cuisine tag for dining.
        clauses.add('nwr["amenity"~"$amenities"]["cuisine"~"$lower",i](around:$radiusM,$lat,$lng);');
      }
      // 4. Also get all nearby places of the exact amenity type (limited scope).
      //    For services like "dentist" or "bank", the amenity type IS specific enough.
      if (filterResult.isService) {
        clauses.add('nwr["amenity"~"$amenities"](around:$radiusM,$lat,$lng);');
      }
    }
    // 5. Match shop types if relevant (e.g. "cookie" → shop=bakery, "salon" → shop=beauty).
    if (filterResult.shopFilter != null) {
      clauses.add('nwr["shop"~"${filterResult.shopFilter}"](around:$radiusM,$lat,$lng);');
    }
  } else {
    // --- PRODUCT / RETAIL SEARCH ---
    if (filterResult.shopFilter != null) {
      clauses.add('nwr["shop"~"${filterResult.shopFilter}"](around:$radiusM,$lat,$lng);');
    } else {
      const fallbackShop =
          'department_store|variety_store|general|wholesale|mall|discount|electronics|hardware|doityourself';
      clauses.add('nwr["shop"~"$fallbackShop"](around:$radiusM,$lat,$lng);');
    }

    if (filterResult.amenityFilter != null) {
      clauses.add('nwr["amenity"~"${filterResult.amenityFilter}"](around:$radiusM,$lat,$lng);');
    } else {
      clauses.add('nwr["amenity"~"marketplace"](around:$radiusM,$lat,$lng);');
    }

    // Also search by store name for retail products (catches lumber yards,
    // specialty suppliers, etc. whose OSM tags don't match but names do).
    if (item != null && item.trim().isNotEmpty) {
      final lower = item.toLowerCase().trim();
      clauses.add('nwr["shop"]["name"~"$lower",i](around:$radiusM,$lat,$lng);');
      clauses.add('nwr["trade"]["name"~"$lower",i](around:$radiusM,$lat,$lng);');
    }
  }

  // Use a longer timeout when many shop types are queried (e.g. construction).
  final timeoutSec = clauses.length > 4 ? 15 : 10;

  final query = '''
[out:json][timeout:$timeoutSec];
(
  ${clauses.join('\n  ')}
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
