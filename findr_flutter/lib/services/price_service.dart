/// SerpApi Google Shopping integration for real product prices.
///
/// Fetches prices from Google Shopping results and matches them to nearby
/// stores so users see actual price data instead of placeholders.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/search_models.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// A single product price from Google Shopping.
class ShoppingPrice {
  final String title;
  final double price;
  final String storeName;
  final String? link;
  final double? rating;
  final int? reviews;

  const ShoppingPrice({
    required this.title,
    required this.price,
    required this.storeName,
    this.link,
    this.rating,
    this.reviews,
  });
}

/// Aggregated price data for a product search.
class PriceData {
  /// All individual prices found.
  final List<ShoppingPrice> prices;

  /// Average price across all results.
  final double avgPrice;

  /// Lowest price found.
  final double lowPrice;

  /// Highest price found.
  final double highPrice;

  /// Map of lowercase store name → best (lowest) price at that store.
  final Map<String, ShoppingPrice> priceByStore;

  const PriceData({
    required this.prices,
    required this.avgPrice,
    required this.lowPrice,
    required this.highPrice,
    required this.priceByStore,
  });
}

// ---------------------------------------------------------------------------
// SerpApi call
// ---------------------------------------------------------------------------

/// Fetch Google Shopping prices for [query] near [lat],[lng].
///
/// Returns null if the API key is not configured or the request fails.
/// This is best-effort — the search continues even if prices aren't available.
Future<PriceData?> fetchProductPrices(String query, {double? lat, double? lng}) async {
  if (kSerpApiKey.isEmpty) {
    debugPrint('SerpApi: no API key configured, skipping price lookup.');
    return null;
  }

  try {
    final params = <String, String>{
      'engine': 'google_shopping',
      'q': query,
      'api_key': kSerpApiKey,
      'num': '20',
      'hl': 'en',
      'gl': 'us',
    };

    // Add location bias if coordinates are available.
    if (lat != null && lng != null) {
      params['location'] = '$lat,$lng';
    }

    final uri = buildSerpApiUri(params);
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(kSerpApiTimeout);

    if (res.statusCode != 200) {
      debugPrint('SerpApi: HTTP ${res.statusCode}');
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['shopping_results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      debugPrint('SerpApi: no shopping results for "$query"');
      return null;
    }

    return _parsePrices(results);
  } catch (e) {
    debugPrint('SerpApi price fetch failed: $e');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

PriceData _parsePrices(List<dynamic> results) {
  final prices = <ShoppingPrice>[];

  for (final r in results) {
    final m = r as Map<String, dynamic>;

    // SerpApi provides extracted_price as a number, or price as a string.
    double? price = (m['extracted_price'] as num?)?.toDouble();
    if (price == null) {
      final priceStr = m['price']?.toString() ?? '';
      final cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
      price = double.tryParse(cleaned);
    }
    if (price == null || price <= 0) continue;

    final title = m['title']?.toString() ?? '';
    final source = m['source']?.toString() ?? '';
    if (source.isEmpty) continue;

    prices.add(ShoppingPrice(
      title: title,
      price: price,
      storeName: source,
      link: m['link']?.toString(),
      rating: (m['rating'] as num?)?.toDouble(),
      reviews: (m['reviews'] as num?)?.toInt(),
    ));
  }

  if (prices.isEmpty) {
    return const PriceData(
      prices: [],
      avgPrice: 0,
      lowPrice: 0,
      highPrice: 0,
      priceByStore: {},
    );
  }

  prices.sort((a, b) => a.price.compareTo(b.price));

  final sum = prices.fold<double>(0, (s, p) => s + p.price);
  final avg = (sum / prices.length * 100).round() / 100;
  final low = prices.first.price;
  final high = prices.last.price;

  // Build a lookup: lowercase store name → lowest price from that store.
  final byStore = <String, ShoppingPrice>{};
  for (final p in prices) {
    final key = _normalizeStoreName(p.storeName);
    if (!byStore.containsKey(key)) {
      byStore[key] = p; // prices are sorted, so first is cheapest.
    }
  }

  return PriceData(
    prices: prices,
    avgPrice: avg,
    lowPrice: low,
    highPrice: high,
    priceByStore: byStore,
  );
}

// ---------------------------------------------------------------------------
// Store name matching
// ---------------------------------------------------------------------------

/// Normalize a store name for fuzzy matching.
String _normalizeStoreName(String name) {
  return name
      .toLowerCase()
      .replaceAll('.com', '')
      .replaceAll('.org', '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Common name aliases so "Walmart Supercenter" matches "Walmart.com", etc.
const Map<String, List<String>> _storeAliases = {
  'walmart': ['walmart', 'wal-mart', 'walmart supercenter', 'walmart neighborhood'],
  'target': ['target'],
  'cvs': ['cvs', 'cvs pharmacy', 'cvs health'],
  'walgreens': ['walgreens'],
  'costco': ['costco', 'costco wholesale'],
  'kroger': ['kroger'],
  'safeway': ['safeway'],
  'amazon': ['amazon', 'amazoncom'],
  'best buy': ['best buy', 'bestbuy'],
  'home depot': ['home depot', 'the home depot'],
  'lowes': ['lowes', "lowe's"],
  'aldi': ['aldi'],
  'dollar general': ['dollar general'],
  'dollar tree': ['dollar tree'],
  'rite aid': ['rite aid'],
  'publix': ['publix'],
  'heb': ['h-e-b', 'heb'],
  'meijer': ['meijer'],
  'whole foods': ['whole foods', 'whole foods market'],
  'trader joes': ["trader joe's", 'trader joes'],
  'sams club': ["sam's club", 'sams club'],
  'bjs': ["bj's", 'bjs', "bj's wholesale"],
};

/// Try to match a nearby store name to a price from Google Shopping.
///
/// Returns the matched [ShoppingPrice] or null if no match is found.
ShoppingPrice? matchPriceToStore(Store store, PriceData priceData) {
  if (priceData.prices.isEmpty) return null;

  final storeLower = _normalizeStoreName(store.name);
  final brandLower = store.brand != null ? _normalizeStoreName(store.brand!) : null;

  // 1. Direct lookup in priceByStore.
  for (final entry in priceData.priceByStore.entries) {
    final priceStore = entry.key;
    if (storeLower.contains(priceStore) || priceStore.contains(storeLower)) {
      return entry.value;
    }
    if (brandLower != null &&
        (brandLower.contains(priceStore) || priceStore.contains(brandLower))) {
      return entry.value;
    }
  }

  // 2. Alias-based matching.
  for (final aliasEntry in _storeAliases.entries) {
    final canonical = aliasEntry.key;
    final aliases = aliasEntry.value;

    final storeMatches = aliases.any((a) => storeLower.contains(a)) ||
        (brandLower != null && aliases.any((a) => brandLower.contains(a)));

    if (storeMatches) {
      // See if any shopping result store matches this alias group.
      for (final priceEntry in priceData.priceByStore.entries) {
        final priceStore = priceEntry.key;
        if (priceStore.contains(canonical) ||
            aliases.any((a) => priceStore.contains(a))) {
          return priceEntry.value;
        }
      }
    }
  }

  return null;
}

/// Format a price as a currency string.
String formatPrice(double price, String currency) {
  final formatted = price.toStringAsFixed(2);
  switch (currency) {
    case 'EUR':
      return '€$formatted';
    case 'GBP':
      return '£$formatted';
    case 'CAD':
      return 'C\$$formatted';
    case 'MXN':
      return 'MX\$$formatted';
    default:
      return '\$$formatted';
  }
}
