/// Local storage service for persisting user data on-device.
///
/// Uses shared_preferences with JSON-encoded lists.
/// Data keys:
///   findr_searches        — search history
///   findr_favorites       — favorited stores
///   findr_recommendations — AI-generated personalized recommendations
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSearches = 'findr_searches';
const _kFavorites = 'findr_favorites';
const _kRecommendations = 'findr_recommendations';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<List<Map<String, dynamic>>> _readList(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('LocalStorage: _readList($key) failed: $e');
    return [];
  }
}

Future<void> _writeList(String key, List<Map<String, dynamic>> list) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(list));
  } catch (e) {
    debugPrint('LocalStorage: _writeList($key) failed: $e');
  }
}

String _generateId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
}

// ---------------------------------------------------------------------------
// User profile (no-op for local storage)
// ---------------------------------------------------------------------------

Future<void> ensureUserDoc() async {}

// ---------------------------------------------------------------------------
// Search history
// ---------------------------------------------------------------------------

/// Save a search to history.
Future<void> saveSearch({
  required String item,
  required double lat,
  required double lng,
  required String locationLabel,
  int resultCount = 0,
}) async {
  try {
    final list = await _readList(_kSearches);
    list.insert(0, {
      'id': _generateId(),
      'item': item,
      'lat': lat,
      'lng': lng,
      'locationLabel': locationLabel,
      'resultCount': resultCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // Keep at most 100 entries.
    if (list.length > 100) list.removeRange(100, list.length);
    await _writeList(_kSearches, list);
    debugPrint('LocalStorage: saved search "$item"');
  } catch (e) {
    debugPrint('LocalStorage: saveSearch failed: $e');
  }
}

/// Get recent searches (newest first), limited to [limit].
Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 20}) async {
  final list = await _readList(_kSearches);
  return list.take(limit).toList();
}

/// Stream of recent searches (emits once — local storage has no live updates).
Stream<List<Map<String, dynamic>>> watchRecentSearches({int limit = 20}) async* {
  yield await getRecentSearches(limit: limit);
}

/// Delete a search from history.
Future<void> deleteSearch(String docId) async {
  try {
    final list = await _readList(_kSearches);
    list.removeWhere((e) => e['id'] == docId);
    await _writeList(_kSearches, list);
  } catch (e) {
    debugPrint('LocalStorage: deleteSearch failed: $e');
  }
}

/// Clear all search history.
Future<void> clearSearchHistory() async {
  try {
    await _writeList(_kSearches, []);
    debugPrint('LocalStorage: cleared search history');
  } catch (e) {
    debugPrint('LocalStorage: clearSearchHistory failed: $e');
  }
}

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

/// Save a store as a favorite.
Future<void> addFavorite({
  required String storeId,
  required String storeName,
  required String address,
  required double lat,
  required double lng,
  required String searchItem,
  String? phone,
  String? website,
  String? openingHours,
  String? brand,
  String? shopType,
  double? rating,
  int? reviewCount,
  String? priceLevel,
  String? thumbnail,
}) async {
  try {
    final list = await _readList(_kFavorites);
    final safeId = storeId.replaceAll('/', '_');
    // Remove existing entry to prevent duplicates.
    list.removeWhere((e) => (e['storeId'] as String?)?.replaceAll('/', '_') == safeId);
    list.insert(0, {
      'id': safeId,
      'storeId': storeId,
      'storeName': storeName,
      'address': address,
      'lat': lat,
      'lng': lng,
      'searchItem': searchItem,
      'phone': phone,
      'website': website,
      'openingHours': openingHours,
      'brand': brand,
      'shopType': shopType,
      'rating': rating,
      'reviewCount': reviewCount,
      'priceLevel': priceLevel,
      'thumbnail': thumbnail,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _writeList(_kFavorites, list);
    debugPrint('LocalStorage: added favorite "$storeName"');
  } catch (e) {
    debugPrint('LocalStorage: addFavorite failed: $e');
  }
}

/// Remove a store from favorites.
Future<void> removeFavorite(String storeId) async {
  try {
    final list = await _readList(_kFavorites);
    final safeId = storeId.replaceAll('/', '_');
    list.removeWhere((e) => (e['storeId'] as String?)?.replaceAll('/', '_') == safeId);
    await _writeList(_kFavorites, list);
    debugPrint('LocalStorage: removed favorite "$storeId"');
  } catch (e) {
    debugPrint('LocalStorage: removeFavorite failed: $e');
  }
}

/// Check if a store is favorited.
Future<bool> isFavorite(String storeId) async {
  try {
    final list = await _readList(_kFavorites);
    final safeId = storeId.replaceAll('/', '_');
    return list.any((e) => (e['storeId'] as String?)?.replaceAll('/', '_') == safeId);
  } catch (e) {
    debugPrint('LocalStorage: isFavorite failed: $e');
    return false;
  }
}

/// Get all favorites.
Future<List<Map<String, dynamic>>> getFavorites() async {
  return _readList(_kFavorites);
}

/// Stream of favorites (emits once — local storage has no live updates).
Stream<List<Map<String, dynamic>>> watchFavorites() async* {
  yield await getFavorites();
}

// ---------------------------------------------------------------------------
// AI Recommendations
// ---------------------------------------------------------------------------

/// Save an AI recommendation.
Future<void> saveRecommendation({
  required String title,
  required String content,
  required String basedOn,
}) async {
  try {
    final list = await _readList(_kRecommendations);
    list.insert(0, {
      'id': _generateId(),
      'title': title,
      'content': content,
      'basedOn': basedOn,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (list.length > 50) list.removeRange(50, list.length);
    await _writeList(_kRecommendations, list);
  } catch (e) {
    debugPrint('LocalStorage: saveRecommendation failed: $e');
  }
}

/// Get recent recommendations.
Future<List<Map<String, dynamic>>> getRecommendations({int limit = 10}) async {
  final list = await _readList(_kRecommendations);
  return list.take(limit).toList();
}
