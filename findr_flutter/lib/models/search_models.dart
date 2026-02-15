/// A store/POI from Overpass with distance and optional drive time.
class Store {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final double distanceKm;
  final int? durationMinutes;

  const Store({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    required this.distanceKm,
    this.durationMinutes,
  });

  Store copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    String? address,
    double? distanceKm,
    int? durationMinutes,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

/// Result of a search: stores + best option summary.
class SearchResult {
  final List<Store> stores;
  final String bestOptionId;
  final String summary;
  final List<String>? alternatives;

  const SearchResult({
    required this.stores,
    required this.bestOptionId,
    required this.summary,
    this.alternatives,
  });
}

/// Filters applied to search: quality tier, membership-only, specific store names.
class SearchFilters {
  final String? qualityTier; // null or '' = All; 'Premium' | 'Standard' | 'Budget'
  final bool membershipsOnly;
  final List<String> storeNames; // empty = any; non-empty = only stores matching any

  const SearchFilters({
    this.qualityTier,
    this.membershipsOnly = false,
    this.storeNames = const [],
  });

  bool get hasFilters =>
      (qualityTier != null && qualityTier!.isNotEmpty) ||
      membershipsOnly ||
      storeNames.isNotEmpty;
}
