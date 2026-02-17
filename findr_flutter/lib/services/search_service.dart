import 'package:flutter/foundation.dart';
import 'distance_util.dart';
import 'store_filters.dart';
import 'nearby_stores_service.dart';
import 'google_maps_search_service.dart';
import 'kroger_service.dart';
import 'product_store_mapper.dart';
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
  final filterInfo = filtersForItem(item);
  final isDining = filterInfo.isDining;
  final isService = filterInfo.isService;

  List<OverpassStore> allStores = [];

  // --- Fire SerpApi, Kroger, AND Overpass all in parallel ---
  // This way if SerpApi/Kroger fail (CORS), Overpass results still come through
  // without the user waiting for sequential timeouts.
  final serpFuture = fetchStoresFromGoogleMaps(
    item: item, lat: lat, lng: lng, maxDistanceKm: maxDistanceKm,
  ).catchError((e) {
    debugPrint('Google Maps search failed: $e');
    return null;
  });

  final krogerFuture = (krogerEnabled && !isDining && !isService)
      ? fetchKrogerLocations(
          lat: lat, lng: lng, radiusMiles: (maxDistanceKm * 0.621371).ceil(),
        ).catchError((e) {
          debugPrint('Kroger Locations failed: $e');
          return null;
        })
      : Future<List<KrogerLocation>?>.value(null);

  final overpassFuture = fetchNearbyStores(
    lat, lng, radiusM: radiusM.toInt(), item: item,
  ).then((stores) {
    print('[Wayvio] Overpass success: ${stores.length} stores');
    return stores;
  }).catchError((e, st) {
    print('[Wayvio] Overpass FAILED: $e');
    print('[Wayvio] Overpass stack: $st');
    return <OverpassStore>[];
  });

  print('[Wayvio] searchFast: waiting for SerpApi + Kroger + Overpass...');
  final results = await Future.wait([serpFuture, krogerFuture, overpassFuture]);
  print('[Wayvio] searchFast: Future.wait completed');
  final gmStores = results[0] as List<OverpassStore>?;
  final krogerLocs = results[1] as List<KrogerLocation>?;
  final overpassStores = results[2] as List<OverpassStore>;

  print('[Wayvio] SerpApi: ${gmStores?.length ?? "null"} stores');
  print('[Wayvio] Kroger: ${krogerLocs?.length ?? "null"} locations');
  print('[Wayvio] Overpass: ${overpassStores.length} stores');

  // Prefer SerpApi (best quality), then merge Kroger + Overpass.
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

  // Merge Overpass stores (avoid duplicates by proximity).
  if (overpassStores.isNotEmpty) {
    debugPrint('Overpass: found ${overpassStores.length} stores');
    for (final os in overpassStores) {
      // Skip if a SerpApi/Kroger store already exists within 100m with similar name.
      final isDuplicate = allStores.any((existing) {
        final dist = haversineKm(existing.lat, existing.lng, os.lat, os.lng);
        if (dist > 0.1) return false; // > 100m apart
        final eName = existing.name.toLowerCase();
        final oName = os.name.toLowerCase();
        return eName.contains(oName) || oName.contains(eName);
      });
      if (!isDuplicate) allStores.add(os);
    }
  }

  if (allStores.isEmpty) {
    final verb = isDining ? 'serving' : isService ? 'for' : 'that sell';
    return SearchResult(
      stores: const [],
      bestOptionId: '',
      summary: 'No places found $verb "$item" nearby.',
      alternatives: [
        if (isDining)
          'Try a more general term (e.g. "pizza" instead of a specific restaurant)'
        else if (isService)
          'Try a more general term (e.g. "dentist" instead of a specific clinic)'
        else
          'Try a broader search term (e.g. "laptop" instead of a specific model)',
        'Increase the search radius',
        'Try searching while on a stronger network connection',
      ],
    );
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
