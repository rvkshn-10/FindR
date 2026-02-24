/// A store/POI from Overpass with distance and optional drive time.
class Store {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final double distanceKm;
  final int? durationMinutes;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? brand;
  final String? shopType;   // OSM shop type (e.g. "supermarket", "electronics")
  final String? amenityType; // OSM amenity type (e.g. "pharmacy", "fuel")

  // Price data from Google Shopping (populated asynchronously).
  final double? price;         // matched or average price in USD
  final String? priceLabel;    // e.g. "$8.99" or "avg ~$9.50"
  final bool priceIsAvg;       // true if this is an average, not a store-specific match

  // Google Maps store details
  final double? rating;        // 1-5 star rating
  final int? reviewCount;      // number of Google reviews
  final String? priceLevel;    // "$", "$$", "$$$"
  final String? thumbnail;     // URL to store photo
  final List<String> serviceOptions; // e.g. ["In-store shopping", "Delivery"]

  // Data-source confidence
  final StoreConfidence confidence;
  final Set<String> dataSources; // e.g. {"serpapi", "kroger", "overpass"}

  const Store({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    required this.distanceKm,
    this.durationMinutes,
    this.phone,
    this.website,
    this.openingHours,
    this.brand,
    this.shopType,
    this.amenityType,
    this.price,
    this.priceLabel,
    this.priceIsAvg = false,
    this.rating,
    this.reviewCount,
    this.priceLevel,
    this.thumbnail,
    this.serviceOptions = const [],
    this.confidence = StoreConfidence.low,
    this.dataSources = const {},
  });

  Store copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    String? address,
    double? distanceKm,
    int? durationMinutes,
    String? phone,
    String? website,
    String? openingHours,
    String? brand,
    String? shopType,
    String? amenityType,
    double? price,
    String? priceLabel,
    bool? priceIsAvg,
    double? rating,
    int? reviewCount,
    String? priceLevel,
    String? thumbnail,
    List<String>? serviceOptions,
    StoreConfidence? confidence,
    Set<String>? dataSources,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      brand: brand ?? this.brand,
      shopType: shopType ?? this.shopType,
      amenityType: amenityType ?? this.amenityType,
      price: price ?? this.price,
      priceLabel: priceLabel ?? this.priceLabel,
      priceIsAvg: priceIsAvg ?? this.priceIsAvg,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      priceLevel: priceLevel ?? this.priceLevel,
      thumbnail: thumbnail ?? this.thumbnail,
      serviceOptions: serviceOptions ?? this.serviceOptions,
      confidence: confidence ?? this.confidence,
      dataSources: dataSources ?? this.dataSources,
    );
  }
}

/// Result of a search: stores + best option summary.
class SearchResult {
  final List<Store> stores;
  final String bestOptionId;
  final String summary;
  final List<String>? alternatives;

  /// AI-generated recommendation (populated asynchronously after results load).
  final String? aiRecommendation;

  /// AI reasoning for the recommendation.
  final String? aiReasoning;

  /// AI tips for the user.
  final List<String>? aiTips;

  const SearchResult({
    required this.stores,
    required this.bestOptionId,
    required this.summary,
    this.alternatives,
    this.aiRecommendation,
    this.aiReasoning,
    this.aiTips,
  });

  SearchResult copyWith({
    List<Store>? stores,
    String? bestOptionId,
    String? summary,
    List<String>? alternatives,
    String? aiRecommendation,
    String? aiReasoning,
    List<String>? aiTips,
  }) {
    return SearchResult(
      stores: stores ?? this.stores,
      bestOptionId: bestOptionId ?? this.bestOptionId,
      summary: summary ?? this.summary,
      alternatives: alternatives ?? this.alternatives,
      aiRecommendation: aiRecommendation ?? this.aiRecommendation,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      aiTips: aiTips ?? this.aiTips,
    );
  }
}

/// Confidence level for a store result based on data-source coverage.
enum StoreConfidence { high, medium, low }

/// Filters applied to search: quality tier, membership-only, specific store names.
class SearchFilters {
  final String? qualityTier; // null or '' = All; 'Premium' | 'Standard' | 'Budget'
  final bool membershipsOnly;
  final List<String> storeNames; // empty = any; non-empty = only stores matching any
  final String? sortHint;   // 'distance' | 'priceLow' | 'rating' — pre-set by scenario chips
  final bool openNowOnly;

  const SearchFilters({
    this.qualityTier,
    this.membershipsOnly = false,
    this.storeNames = const [],
    this.sortHint,
    this.openNowOnly = false,
  });

  bool get hasFilters =>
      (qualityTier != null && qualityTier!.isNotEmpty) ||
      membershipsOnly ||
      storeNames.isNotEmpty;

  SearchFilters copyWith({
    String? qualityTier,
    bool? membershipsOnly,
    List<String>? storeNames,
    String? sortHint,
    bool? openNowOnly,
  }) {
    return SearchFilters(
      qualityTier: qualityTier ?? this.qualityTier,
      membershipsOnly: membershipsOnly ?? this.membershipsOnly,
      storeNames: storeNames ?? this.storeNames,
      sortHint: sortHint ?? this.sortHint,
      openNowOnly: openNowOnly ?? this.openNowOnly,
    );
  }
}
