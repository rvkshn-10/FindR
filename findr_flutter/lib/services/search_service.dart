import 'package:flutter/foundation.dart';
import 'distance_util.dart';
import 'store_filters.dart';
import 'nearby_stores_service.dart';
import 'google_maps_search_service.dart';
import 'kroger_service.dart';
import 'road_distance_service.dart';
import '../models/search_models.dart';
import '../config.dart';

bool _passesFilters(OverpassStore s, SearchFilters? filters) {
  if (filters == null || !filters.hasFilters) return true;
  if (filters.qualityTier != null && filters.qualityTier!.isNotEmpty) {
    if (!storeMatchesQualityTier(s.name, filters.qualityTier!)) return false;
  }
  if (filters.membershipsOnly && !storeIsMembership(s.name)) return false;
  if (filters.storeNames.isNotEmpty &&
      !storeMatchesSpecificStores(s.name, filters.storeNames)) {
    return false;
  }
  return true;
}

/// Build a SearchResult from a list of Store candidates.
SearchResult _buildResult(List<Store> candidates, double lat, double lng) {
  final stores = candidates.take(kMaxStoresDisplay).toList();
  if (stores.isEmpty) {
    return const SearchResult(
      stores: [],
      bestOptionId: '',
      summary: 'No nearby stores found.',
      alternatives: ['Try a different item or increase max distance'],
    );
  }
  final best = stores.first;
  final summary = '${best.name} is the closest option (${formatDistance(best.distanceKm)} away).';
  return SearchResult(
    stores: stores,
    bestOptionId: best.id,
    summary: summary,
  );
}

/// Phase 1: Find nearby stores, filter, return haversine-sorted results.
///
/// Strategy:
///   1. Try SerpApi Google Maps first — Google already knows which stores
///      sell what, so results are highly relevant.
///   2. Fall back to Overpass (OpenStreetMap) + our product-type mapper
///      if SerpApi is unavailable or returns nothing.
Future<SearchResult> searchFast({
  required String item,
  required double lat,
  required double lng,
  double maxDistanceKm = 8.0,
  SearchFilters? filters,
}) async {
  final radiusM = (maxDistanceKm * 1000).clamp(1000.0, 25000.0);

  List<OverpassStore> allStores = [];

  // --- Fire SerpApi + Kroger in parallel ---
  final serpFuture = fetchStoresFromGoogleMaps(
    item: item, lat: lat, lng: lng, maxDistanceKm: maxDistanceKm,
  ).catchError((e) {
    debugPrint('Google Maps search failed: $e');
    return null;
  });

  final krogerFuture = krogerEnabled
      ? fetchKrogerLocations(
          lat: lat, lng: lng, radiusMiles: (maxDistanceKm * 0.621371).ceil(),
        ).catchError((e) {
          debugPrint('Kroger Locations failed: $e');
          return null;
        })
      : Future<List<KrogerLocation>?>.value(null);

  final results = await Future.wait([serpFuture, krogerFuture]);
  final gmStores = results[0] as List<OverpassStore>?;
  final krogerLocs = results[1] as List<KrogerLocation>?;

  if (gmStores != null && gmStores.isNotEmpty) {
    debugPrint('Using Google Maps results: ${gmStores.length} stores');
    allStores = gmStores;
  }

  // Merge Kroger stores (avoid duplicates by name similarity).
  if (krogerLocs != null && krogerLocs.isNotEmpty) {
    final krogerStores = krogerLocationsToStores(krogerLocs);
    debugPrint('Kroger: found ${krogerStores.length} stores');
    final existingNames = allStores.map((s) => s.name.toLowerCase()).toSet();
    for (final ks in krogerStores) {
      if (!existingNames.any((n) => n.contains(ks.brand?.toLowerCase() ?? '') &&
          n.contains(ks.name.split(' - ').last.toLowerCase().trim()))) {
        allStores.add(ks);
      }
    }
  }

  // --- Fallback: Overpass (OpenStreetMap) ---
  if (allStores.isEmpty) {
    try {
      debugPrint('Falling back to Overpass for store search');
      allStores = await fetchNearbyStores(lat, lng, radiusM: radiusM.toInt(), item: item);
    } catch (e) {
      debugPrint('Overpass targeted search failed: $e');
    }

    // If product-specific Overpass query returned nothing, try broad search.
    if (allStores.isEmpty) {
      try {
        debugPrint('Trying broad Overpass search (no product filter)');
        allStores = await fetchNearbyStores(lat, lng, radiusM: radiusM.toInt());
      } catch (e) {
        debugPrint('Broad Overpass search also failed: $e');
        return const SearchResult(
          stores: [],
          bestOptionId: '',
          summary: 'Stores service is temporarily unavailable.',
          alternatives: ['Try again in a moment or try a different location.'],
        );
      }
    }
  }

  final filtered = allStores.where((s) => _passesFilters(s, filters)).toList();
  final candidates = filtered
      .where((s) => s.distanceKm <= maxDistanceKm)
      .map((s) => Store(
            id: s.id,
            name: s.name,
            lat: s.lat,
            lng: s.lng,
            address: s.address,
            distanceKm: s.distanceKm,
            phone: s.phone,
            website: s.website,
            openingHours: s.openingHours,
            brand: s.brand,
            shopType: s.shopType,
            amenityType: s.amenityType,
            rating: s.rating,
            reviewCount: s.reviewCount,
            priceLevel: s.priceLevel,
            thumbnail: s.thumbnail,
            serviceOptions: s.serviceOptions,
          ))
      .toList()
    ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  return _buildResult(candidates, lat, lng);
}

/// Phase 2: Take the fast results and enrich with OSRM road distances.
/// Returns an updated SearchResult with road distances and durations.
Future<SearchResult> enrichWithRoadDistances({
  required SearchResult fastResult,
  required double lat,
  required double lng,
  double maxDistanceKm = 8.0,
}) async {
  if (fastResult.stores.isEmpty) return fastResult;

  final forRoad = fastResult.stores.take(kMaxStoresForRoad).toList();
  final dests = forRoad.map((s) => MapEntry(s.lat, s.lng)).toList();
  final roadResults = await getRoadDistancesOsrm(lat, lng, dests);

  if (roadResults != null && roadResults.length == forRoad.length) {
    final withRoad = <Store>[];
    for (var i = 0; i < forRoad.length; i++) {
      final s = forRoad[i];
      var roadKm = roadResults[i].distanceKm;
      final durMin = roadResults[i].durationMinutes;
      if (roadKm <= 0 && durMin != null && durMin > 0) {
        roadKm = ((durMin / 60) * kAvgSpeedKmh * 100).round() / 100;
      }
      final straightKm = haversineKm(lat, lng, s.lat, s.lng);
      final useRoad = roadKm > 0 &&
          roadKm >= straightKm * 0.5 &&
          roadKm <= straightKm * 15 &&
          roadKm <= maxDistanceKm;
      withRoad.add(s.copyWith(
        distanceKm: useRoad ? roadKm : s.distanceKm,
        durationMinutes: useRoad ? durMin : null,
      ));
    }
    withRoad.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return _buildResult(withRoad, lat, lng);
  }

  // OSRM failed — return fast results as-is.
  return fastResult;
}
