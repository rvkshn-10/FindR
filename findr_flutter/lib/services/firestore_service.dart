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
    debugPrint('[Wayvio] LocalStorage: _readList($key) failed: $e');
    return [];
  }
}

Future<void> _writeList(String key, List<Map<String, dynamic>> list) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(list));
  } catch (e) {
    debugPrint('[Wayvio] LocalStorage: _writeList($key) failed: $e');
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
    debugPrint('[Wayvio] LocalStorage: saveSearch failed: $e');
  }
}

/// Get recent searches (newest first), limited to [limit].
Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 20}) async {
  final list = await _readList(_kSearches);
  return list.take(limit.clamp(0, list.length)).toList();
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
    debugPrint('[Wayvio] LocalStorage: deleteSearch failed: $e');
  }
}

/// Update the result count for the most recent search matching [item].
Future<void> updateSearchResultCount(String item, int count) async {
  try {
    final list = await _readList(_kSearches);
    final idx = list.indexWhere((e) => e['item'] == item);
    if (idx == -1) return;
    list[idx]['resultCount'] = count;
    await _writeList(_kSearches, list);
    debugPrint('LocalStorage: updated resultCount for "$item" to $count');
  } catch (e) {
    debugPrint('[Wayvio] LocalStorage: updateSearchResultCount failed: $e');
  }
}

/// Clear all search history.
Future<void> clearSearchHistory() async {
  try {
    await _writeList(_kSearches, []);
    debugPrint('LocalStorage: cleared search history');
  } catch (e) {
    debugPrint('[Wayvio] LocalStorage: clearSearchHistory failed: $e');
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
    debugPrint('[Wayvio] LocalStorage: addFavorite failed: $e');
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
    debugPrint('[Wayvio] LocalStorage: removeFavorite failed: $e');
  }
}

/// Check if a store is favorited.
Future<bool> isFavorite(String storeId) async {
  try {
    final list = await _readList(_kFavorites);
    final safeId = storeId.replaceAll('/', '_');
    return list.any((e) => (e['storeId'] as String?)?.replaceAll('/', '_') == safeId);
  } catch (e) {
    debugPrint('[Wayvio] LocalStorage: isFavorite failed: $e');
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
    debugPrint('[Wayvio] LocalStorage: saveRecommendation failed: $e');
  }
}

/// Get recent recommendations.
Future<List<Map<String, dynamic>>> getRecommendations({int limit = 10}) async {
  final list = await _readList(_kRecommendations);
  return list.take(limit.clamp(0, list.length)).toList();
}

// ---------------------------------------------------------------------------
// Cached search results (offline fallback)
// ---------------------------------------------------------------------------

const _kCachedResults = 'findr_cached_results';

/// Cache the last successful search results for offline fallback.
Future<void> cacheSearchResults({
  required String query,
  required List<Map<String, dynamic>> stores,
  required double lat,
  required double lng,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedResults, jsonEncode({
      'query': query,
      'stores': stores,
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));
  } catch (e) {
    debugPrint('[Wayvio] cacheSearchResults failed: $e');
  }
}

/// Get cached search results, if any.
Future<Map<String, dynamic>?> getCachedResults() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCachedResults);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('[Wayvio] getCachedResults failed: $e');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Store notes
// ---------------------------------------------------------------------------

const _kNotes = 'findr_store_notes';

/// Get the user's note for a store.
Future<String?> getStoreNote(String storeId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotes);
    if (raw == null) return null;
    final notes = jsonDecode(raw) as Map<String, dynamic>;
    return notes[storeId] as String?;
  } catch (e) {
    debugPrint('[Wayvio] LocalStorage: getStoreNote failed: $e');
    return null;
  }
}

/// Save a note for a store.
Future<void> saveStoreNote(String storeId, String note) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotes);
    final notes = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{};
    if (note.trim().isEmpty) {
      notes.remove(storeId);
    } else {
      notes[storeId] = note.trim();
    }
    await prefs.setString(_kNotes, jsonEncode(notes));
  } catch (e) {
    debugPrint('[Wayvio] LocalStorage: saveStoreNote failed: $e');
  }
}

// ---------------------------------------------------------------------------
// Store items tracking (common items people search at each store)
// ---------------------------------------------------------------------------

const _kStoreItems = 'findr_store_items';

Future<List<String>> getStoreItems(String storeId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStoreItems);
    if (raw == null) return [];
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map[storeId] as List<dynamic>?)?.cast<String>() ?? [];
  } catch (e) {
    debugPrint('[Wayvio] getStoreItems failed: $e');
    return [];
  }
}

Future<void> trackStoreItem(String storeId, String item) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStoreItems);
    final map = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{};
    final items = (map[storeId] as List<dynamic>?)?.cast<String>() ?? [];
    final lower = item.toLowerCase();
    if (!items.any((i) => i.toLowerCase() == lower)) {
      items.insert(0, item);
      if (items.length > 20) items.removeRange(20, items.length);
    }
    map[storeId] = items;
    await prefs.setString(_kStoreItems, jsonEncode(map));
  } catch (e) {
    debugPrint('[Wayvio] trackStoreItem failed: $e');
  }
}

// ---------------------------------------------------------------------------
// Micro-reviews (local user ratings per store)
// ---------------------------------------------------------------------------

const _kReviews = 'findr_store_reviews';

Future<Map<String, dynamic>?> getStoreReview(String storeId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kReviews);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map[storeId] as Map<String, dynamic>?;
  } catch (e) {
    debugPrint('[Wayvio] getStoreReview failed: $e');
    return null;
  }
}

Future<void> saveStoreReview(
    String storeId, int availability, int speed, int parking) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kReviews);
    final map = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{};
    map[storeId] = {
      'availability': availability,
      'speed': speed,
      'parking': parking,
      'userId': 'local',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_kReviews, jsonEncode(map));
  } catch (e) {
    debugPrint('[Wayvio] saveStoreReview failed: $e');
  }
}

Future<Map<String, Map<String, dynamic>>> getAllStoreReviews() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kReviews);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
  } catch (e) {
    debugPrint('[Wayvio] getAllStoreReviews failed: $e');
    return {};
  }
}

// ---------------------------------------------------------------------------
// Shopping lists
// ---------------------------------------------------------------------------

const _kShoppingLists = 'findr_shopping_lists';

Future<List<Map<String, dynamic>>> getShoppingLists() async {
  return _readList(_kShoppingLists);
}

Future<void> saveShoppingLists(List<Map<String, dynamic>> lists) async {
  await _writeList(_kShoppingLists, lists);
}

// ---------------------------------------------------------------------------
// Saved locations (home / work for "On the way" routing)
// ---------------------------------------------------------------------------

const _kSavedLocations = 'findr_saved_locations';

Future<Map<String, dynamic>> getSavedLocations() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedLocations);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('[Wayvio] getSavedLocations failed: $e');
    return {};
  }
}

Future<void> saveSavedLocation(
    String key, double lat, double lng, String label) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedLocations);
    final map = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{};
    map[key] = {'lat': lat, 'lng': lng, 'label': label};
    await prefs.setString(_kSavedLocations, jsonEncode(map));
  } catch (e) {
    debugPrint('[Wayvio] saveSavedLocation failed: $e');
  }
}
