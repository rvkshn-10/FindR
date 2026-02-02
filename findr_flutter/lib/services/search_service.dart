import 'distance_util.dart';
import 'filter_constants.dart';
import 'overpass_service.dart';
import 'osrm_service.dart';
import '../models/store.dart';

const _maxStores = 10;
const _maxStoresForRoad = 25;
const _avgSpeedKmh = 50.0;

bool _passesFilters(OverpassStore s, SearchFilters? filters) {
  if (filters == null || !filters.hasFilters) return true;
  if (filters.qualityTier != null && filters.qualityTier!.isNotEmpty) {
    if (!storeMatchesQualityTier(s.name, filters.qualityTier!)) return false;
  }
  if (filters.membershipsOnly && !storeIsMembership(s.name)) return false;
  if (filters.storeNames.isNotEmpty &&
      !storeMatchesSpecificStores(s.name, filters.storeNames)) return false;
  return true;
}

/// Runs search: Overpass → filters → distance → OSRM road distances → build Store list.
Future<SearchResult> search({
  required String item,
  required double lat,
  required double lng,
  double maxDistanceKm = 8.0,
  SearchFilters? filters,
}) async {
  final radiusM = (maxDistanceKm * 1000).clamp(1000.0, 25000.0);
  List<OverpassStore> overpassStores;
  try {
    overpassStores = await fetchNearbyStores(lat, lng, radiusM: radiusM.toInt());
  } catch (e) {
    return const SearchResult(
      stores: [],
      bestOptionId: '',
      summary: 'Stores service is temporarily unavailable.',
      alternatives: ['Try again in a moment or try a different location.'],
    );
  }
  var filtered = overpassStores.where((s) => _passesFilters(s, filters)).toList();
  var candidates = filtered
      .where((s) => s.distanceKm <= maxDistanceKm)
      .map((s) => Store(
            id: s.id,
            name: s.name,
            lat: s.lat,
            lng: s.lng,
            address: s.address,
            distanceKm: s.distanceKm,
          ))
      .toList()
    ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  if (candidates.isEmpty) {
    final alternatives = <String>[
      'Try a different item or increase max distance',
      if (filters?.hasFilters == true) 'Try loosening or clearing filters',
    ];
    return SearchResult(
      stores: [],
      bestOptionId: '',
      summary: 'No nearby stores found.',
      alternatives: alternatives,
    );
  }

  final forRoad = candidates.take(_maxStoresForRoad).toList();
  final dests = forRoad.map((s) => MapEntry(s.lat, s.lng)).toList();
  final roadResults = await getRoadDistancesOsrm(lat, lng, dests);

  if (roadResults != null && roadResults.length == forRoad.length) {
    final withRoad = <Store>[];
    for (var i = 0; i < forRoad.length; i++) {
      final s = forRoad[i];
      var roadKm = roadResults[i].distanceKm;
      final durMin = roadResults[i].durationMinutes;
      if (roadKm <= 0 && durMin != null && durMin > 0) {
        roadKm = ((durMin / 60) * _avgSpeedKmh * 100).round() / 100;
      }
      final straightKm = haversineKm(lat, lng, s.lat, s.lng);
      final useRoad = roadKm > 0 &&
          roadKm >= straightKm * 0.5 &&
          roadKm <= straightKm * 15 &&
          roadKm <= maxDistanceKm;
      if (useRoad) {
        withRoad.add(Store(
          id: s.id,
          name: s.name,
          lat: s.lat,
          lng: s.lng,
          address: s.address,
          distanceKm: roadKm,
          durationMinutes: useRoad ? durMin : null,
        ));
      }
    }
    withRoad.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    candidates = withRoad;
  }

  final stores = candidates.take(_maxStores).toList();
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
