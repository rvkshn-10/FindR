import 'distance_util.dart';
import 'overpass_service.dart';
import 'osrm_service.dart';
import '../models/store.dart';

const _maxStores = 10;
const _maxStoresForRoad = 25;
const _avgSpeedKmh = 50.0;

/// Runs search: Overpass → filter by distance → OSRM road distances → build Store list.
Future<SearchResult> search({
  required String item,
  required double lat,
  required double lng,
  double maxDistanceKm = 8.0,
}) async {
  final radiusM = (maxDistanceKm * 1000).clamp(1000.0, 25000.0);
  final overpassStores = await fetchNearbyStores(lat, lng, radiusM: radiusM.toInt());
  var candidates = overpassStores
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
    return SearchResult(
      stores: [],
      bestOptionId: '',
      summary: 'No nearby stores found.',
      alternatives: ['Try a different item or increase max distance'],
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
    return SearchResult(
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
