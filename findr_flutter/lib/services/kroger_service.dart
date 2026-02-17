/// Kroger API integration for real in-store product prices and store locations.
///
/// Uses OAuth2 client_credentials flow for authentication, then queries:
///   - Locations API: find nearby Kroger-family stores
///   - Products API: get actual in-store prices at a specific location
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'distance_util.dart';
import 'nearby_stores_service.dart';

// ---------------------------------------------------------------------------
// OAuth2 token management
// ---------------------------------------------------------------------------

String? _accessToken;
DateTime? _tokenExpiry;

/// Whether the Kroger integration is configured (both client ID and secret).
bool get krogerEnabled =>
    kKrogerClientId.isNotEmpty && kKrogerClientSecret.isNotEmpty;

/// Get a valid access token, refreshing if needed.
Future<String?> _getAccessToken() async {
  if (!krogerEnabled) return null;

  // Return cached token if still valid (with 60s buffer).
  if (_accessToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(seconds: 60)))) {
    return _accessToken;
  }

  try {
    final credentials =
        base64Encode(utf8.encode('$kKrogerClientId:$kKrogerClientSecret'));

    final tokenUrl = kIsWeb
        ? Uri.parse(
            'https://corsproxy.io/?${Uri.encodeComponent('$kKrogerBaseUrl/connect/oauth2/token')}')
        : Uri.parse('$kKrogerBaseUrl/connect/oauth2/token');

    final res = await http.post(
      tokenUrl,
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials&scope=product.compact',
    ).timeout(kKrogerTimeout);

    if (res.statusCode != 200) {
      debugPrint('Kroger OAuth failed: HTTP ${res.statusCode} ${res.body}');
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _accessToken = data['access_token']?.toString();
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 1800;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

    debugPrint('Kroger OAuth: got token, expires in ${expiresIn}s');
    return _accessToken;
  } catch (e) {
    debugPrint('Kroger OAuth error: $e');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Locations API
// ---------------------------------------------------------------------------

/// A Kroger store location.
class KrogerLocation {
  final String locationId;
  final String name;
  final String chain; // e.g. "Kroger", "Ralphs", "Fred Meyer"
  final double lat;
  final double lng;
  final String address;
  final String? phone;
  final double distanceKm;

  const KrogerLocation({
    required this.locationId,
    required this.name,
    required this.chain,
    required this.lat,
    required this.lng,
    required this.address,
    this.phone,
    required this.distanceKm,
  });
}

/// Find Kroger-family stores near [lat],[lng] within [radiusMiles].
Future<List<KrogerLocation>?> fetchKrogerLocations({
  required double lat,
  required double lng,
  int radiusMiles = 10,
}) async {
  final token = await _getAccessToken();
  if (token == null) return null;

  try {
    final params = <String, String>{
      'filter.lat.near': lat.toString(),
      'filter.lon.near': lng.toString(),
      'filter.radiusInMiles': radiusMiles.toString(),
      'filter.limit': '10',
    };

    final directUrl = Uri.parse('$kKrogerBaseUrl/locations')
        .replace(queryParameters: params);
    final url = kIsWeb
        ? Uri.parse(
            'https://corsproxy.io/?${Uri.encodeComponent(directUrl.toString())}')
        : directUrl;

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    }).timeout(kKrogerTimeout);

    if (res.statusCode != 200) {
      debugPrint('Kroger Locations: HTTP ${res.statusCode}');
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['data'] as List<dynamic>?;
    if (items == null || items.isEmpty) return null;

    return items.map((item) {
      final m = item as Map<String, dynamic>;
      final locId = m['locationId']?.toString() ?? '';
      final name = m['name']?.toString() ?? 'Kroger Store';
      final chain = m['chain']?.toString() ?? 'Kroger';
      final addr = m['address'] as Map<String, dynamic>?;
      final storeLat = (m['geolocation']?['latitude'] as num?)?.toDouble() ?? lat;
      final storeLng = (m['geolocation']?['longitude'] as num?)?.toDouble() ?? lng;
      final street = addr?['addressLine1']?.toString() ?? '';
      final city = addr?['city']?.toString() ?? '';
      final state = addr?['state']?.toString() ?? '';
      final zip = addr?['zipCode']?.toString() ?? '';
      final phone = m['phone']?.toString();
      final fullAddress = [street, city, state, zip]
          .where((s) => s.isNotEmpty)
          .join(', ');

      return KrogerLocation(
        locationId: locId,
        name: name,
        chain: chain,
        lat: storeLat,
        lng: storeLng,
        address: fullAddress,
        phone: phone,
        distanceKm: haversineKm(lat, lng, storeLat, storeLng),
      );
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  } catch (e) {
    debugPrint('Kroger Locations error: $e');
    return null;
  }
}

/// Convert a list of [KrogerLocation] to [OverpassStore] for unified handling.
List<OverpassStore> krogerLocationsToStores(List<KrogerLocation> locations) {
  return locations.map((loc) => OverpassStore(
    id: 'kroger/${loc.locationId}',
    name: '${loc.chain} - ${loc.name}',
    lat: loc.lat,
    lng: loc.lng,
    address: loc.address,
    distanceKm: (loc.distanceKm * 100).round() / 100,
    phone: loc.phone,
    shopType: 'supermarket',
    brand: loc.chain,
  )).toList();
}

// ---------------------------------------------------------------------------
// Products API
// ---------------------------------------------------------------------------

/// A product found at a specific Kroger location with its price.
class KrogerProduct {
  final String productId;
  final String name;
  final String? brand;
  final double? price;         // regular price
  final double? promoPrice;    // sale / promo price
  final String? size;          // e.g. "16 oz"
  final String? imageUrl;
  final bool inStock;

  const KrogerProduct({
    required this.productId,
    required this.name,
    this.brand,
    this.price,
    this.promoPrice,
    this.size,
    this.imageUrl,
    this.inStock = true,
  });

  /// The best (lowest) available price.
  double? get bestPrice => promoPrice ?? price;
}

/// Aggregated Kroger price data for a search term at a specific location.
class KrogerPriceData {
  final String locationId;
  final List<KrogerProduct> products;
  final double? avgPrice;
  final double? lowPrice;
  final double? highPrice;

  const KrogerPriceData({
    required this.locationId,
    required this.products,
    this.avgPrice,
    this.lowPrice,
    this.highPrice,
  });
}

/// Search for products at a specific Kroger [locationId].
///
/// Returns price data with actual in-store prices.
Future<KrogerPriceData?> fetchKrogerProducts({
  required String query,
  required String locationId,
}) async {
  final token = await _getAccessToken();
  if (token == null) return null;

  try {
    final params = <String, String>{
      'filter.term': query,
      'filter.locationId': locationId,
      'filter.limit': '10',
    };

    final directUrl = Uri.parse('$kKrogerBaseUrl/products')
        .replace(queryParameters: params);
    final url = kIsWeb
        ? Uri.parse(
            'https://corsproxy.io/?${Uri.encodeComponent(directUrl.toString())}')
        : directUrl;

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    }).timeout(kKrogerTimeout);

    if (res.statusCode != 200) {
      debugPrint('Kroger Products: HTTP ${res.statusCode}');
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['data'] as List<dynamic>?;
    if (items == null || items.isEmpty) return null;

    final products = <KrogerProduct>[];
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      final productId = m['productId']?.toString() ?? '';
      final desc = m['description']?.toString() ?? 'Unknown Product';
      final brand = m['brand']?.toString();

      // Parse price from items array.
      final itemsList = m['items'] as List<dynamic>?;
      double? price;
      double? promoPrice;
      String? size;
      bool inStock = false;

      if (itemsList != null && itemsList.isNotEmpty) {
        final firstItem = itemsList.first as Map<String, dynamic>;
        final priceObj = firstItem['price'] as Map<String, dynamic>?;
        price = (priceObj?['regular'] as num?)?.toDouble();
        promoPrice = (priceObj?['promo'] as num?)?.toDouble();
        if (promoPrice == 0) promoPrice = null;
        size = firstItem['size']?.toString();

        final fulfillment = firstItem['fulfillment'] as Map<String, dynamic>?;
        inStock = fulfillment?['inStore'] == true;
      }

      // Get first image.
      String? imageUrl;
      final images = m['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        final firstImg = images.first as Map<String, dynamic>;
        final sizes = firstImg['sizes'] as List<dynamic>?;
        if (sizes != null && sizes.isNotEmpty) {
          // Try to get medium or small thumbnail.
          for (final s in sizes) {
            final sizeMap = s as Map<String, dynamic>;
            if (sizeMap['size'] == 'medium' || sizeMap['size'] == 'small') {
              imageUrl = sizeMap['url']?.toString();
              break;
            }
          }
          imageUrl ??= (sizes.first as Map<String, dynamic>)['url']?.toString();
        }
      }

      if (price != null || promoPrice != null) {
        products.add(KrogerProduct(
          productId: productId,
          name: desc,
          brand: brand,
          price: price,
          promoPrice: promoPrice,
          size: size,
          imageUrl: imageUrl,
          inStock: inStock,
        ));
      }
    }

    if (products.isEmpty) return null;

    final prices = products
        .map((p) => p.bestPrice)
        .whereType<double>()
        .toList();
    final avg = prices.isEmpty
        ? null
        : prices.reduce((a, b) => a + b) / prices.length;
    final low = prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
    final high = prices.isEmpty ? null : prices.reduce((a, b) => a > b ? a : b);

    return KrogerPriceData(
      locationId: locationId,
      products: products,
      avgPrice: avg,
      lowPrice: low,
      highPrice: high,
    );
  } catch (e) {
    debugPrint('Kroger Products error: $e');
    return null;
  }
}
