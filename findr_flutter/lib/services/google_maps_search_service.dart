/// SerpApi Google Maps integration for finding stores that sell a product.
///
/// Uses the Google Maps Local Results engine to find nearby businesses.
/// Google Maps already knows which stores sell what, so searching
/// "batteries near 37.77,-122.41" returns hardware stores, supermarkets,
/// electronics shops — not bakeries or hair salons.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'distance_util.dart';
import 'nearby_stores_service.dart';

/// Search Google Maps via SerpApi for stores that sell [item] near [lat],[lng].
///
/// Returns a list of [OverpassStore] (same model used by Overpass) so the
/// rest of the app doesn't need to know where the data came from.
/// Returns null if SerpApi key is missing or the request fails.
Future<List<OverpassStore>?> fetchStoresFromGoogleMaps({
  required String item,
  required double lat,
  required double lng,
  double maxDistanceKm = 8.0,
}) async {
  if (kSerpApiKey.isEmpty) return null;

  try {
    final query = '$item near me';
    final params = <String, String>{
      'engine': 'google_maps',
      'q': query,
      'api_key': kSerpApiKey,
      'll': '@$lat,$lng,${_zoomForRadius(maxDistanceKm)}z',
      'type': 'search',
      'hl': 'en',
    };

    final uri = buildSerpApiUri(params);
    debugPrint('SerpApi Maps: searching "$query" near ($lat,$lng) via ${uri.toString().substring(0, 40)}...');

    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(kSerpApiTimeout);

    if (res.statusCode != 200) {
      debugPrint('SerpApi Maps: HTTP ${res.statusCode}');
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    // Check for errors in the response.
    if (data.containsKey('error')) {
      debugPrint('SerpApi Maps error: ${data['error']}');
      return null;
    }

    final localResults = data['local_results'] as List<dynamic>?;
    if (localResults == null || localResults.isEmpty) {
      debugPrint('SerpApi Maps: no local_results for "$query"');
      return null;
    }

    return _parseLocalResults(localResults, lat, lng, maxDistanceKm);
  } catch (e) {
    debugPrint('SerpApi Maps search failed: $e');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

List<OverpassStore> _parseLocalResults(
  List<dynamic> results,
  double userLat,
  double userLng,
  double maxDistanceKm,
) {
  final stores = <OverpassStore>[];
  final seen = <String>{};

  for (final r in results) {
    final m = r as Map<String, dynamic>;

    final name = m['title']?.toString();
    if (name == null || name.isEmpty) continue;

    // Extract GPS coordinates.
    final gps = m['gps_coordinates'] as Map<String, dynamic>?;
    final storeLat = (gps?['latitude'] as num?)?.toDouble();
    final storeLng = (gps?['longitude'] as num?)?.toDouble();
    if (storeLat == null || storeLng == null) continue;

    // Build a dedup key from name + approximate location.
    final dedupKey = '${name.toLowerCase()}_${storeLat.toStringAsFixed(4)}_${storeLng.toStringAsFixed(4)}';
    if (seen.contains(dedupKey)) continue;
    seen.add(dedupKey);

    final distanceKm = haversineKm(userLat, userLng, storeLat, storeLng);

    // Skip results that are too far.
    if (distanceKm > maxDistanceKm) continue;

    // Build address from structured fields.
    final address = m['address']?.toString() ?? '';

    // Extract type/category.
    final type = m['type']?.toString();
    final types = m['types'] as List<dynamic>?;
    final shopType = type ?? (types != null && types.isNotEmpty ? types.first.toString() : null);

    // Place ID as our unique ID.
    final placeId = m['place_id']?.toString() ?? 'gm_${stores.length}';

    // Extract opening hours.
    final hours = m['hours']?.toString();
    final operatingHours = m['operating_hours'] as Map<String, dynamic>?;
    String? openingHours = hours;
    if (openingHours == null && operatingHours != null) {
      // Try to get today's hours.
      final days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      final today = days[DateTime.now().weekday % 7];
      openingHours = operatingHours[today]?.toString();
    }

    // Extract rating, reviews, price level, thumbnail.
    final rating = (m['rating'] as num?)?.toDouble();
    final reviewCount = (m['reviews'] as num?)?.toInt();
    final priceLevel = m['price']?.toString(); // "$", "$$", "$$$"
    final thumbnail = m['thumbnail']?.toString();

    // Extract service options (e.g. "In-store shopping", "Delivery", "Curbside pickup").
    final svcOpts = <String>[];
    final svcMap = m['service_options'] as Map<String, dynamic>?;
    if (svcMap != null) {
      svcMap.forEach((key, value) {
        if (value == true) {
          // Convert key like "dine_in" → "Dine in"
          final label = key
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' ');
          svcOpts.add(label);
        }
      });
    }

    stores.add(OverpassStore(
      id: 'gm/$placeId',
      name: name,
      lat: storeLat,
      lng: storeLng,
      address: address,
      distanceKm: (distanceKm * 100).round() / 100,
      phone: m['phone']?.toString(),
      website: m['website']?.toString(),
      openingHours: openingHours,
      brand: null,
      shopType: shopType,
      amenityType: null,
      rating: rating,
      reviewCount: reviewCount,
      priceLevel: priceLevel,
      thumbnail: thumbnail,
      serviceOptions: svcOpts,
    ));
  }

  stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return stores;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convert a search radius in km to a Google Maps zoom level.
/// Smaller radius = higher zoom (more zoomed in).
double _zoomForRadius(double km) {
  if (km <= 1) return 15;
  if (km <= 2) return 14;
  if (km <= 5) return 13;
  if (km <= 10) return 12;
  if (km <= 20) return 11;
  return 10;
}
