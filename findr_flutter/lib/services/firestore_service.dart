/// Firestore service for persisting user data.
///
/// Collections:
///   users/{deviceId}/searches    — search history
///   users/{deviceId}/favorites   — favorited stores
///   users/{deviceId}/recommendations — AI-generated personalized recommendations
library;

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _db = FirebaseFirestore.instance;

const _kDeviceIdKey = 'findr_device_id';
String? _cachedDeviceId;

/// Returns a stable device identifier, creating one on first launch.
Future<String> _getDeviceId() async {
  if (_cachedDeviceId != null) return _cachedDeviceId!;
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kDeviceIdKey);
  if (id == null) {
    id = _generateUuid();
    await prefs.setString(_kDeviceIdKey, id);
  }
  _cachedDeviceId = id;
  return id;
}

String _generateUuid() {
  final r = Random.secure();
  return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<DocumentReference?> _userDoc() async {
  try {
    final uid = await _getDeviceId();
    return _db.collection('users').doc(uid);
  } catch (e) {
    debugPrint('Firestore: _userDoc failed: $e');
    return null;
  }
}

Future<CollectionReference?> _subcollection(String name) async {
  final doc = await _userDoc();
  return doc?.collection(name);
}

// ---------------------------------------------------------------------------
// User profile
// ---------------------------------------------------------------------------

/// Ensure user document exists and update last-seen timestamp.
Future<void> ensureUserDoc() async {
  final doc = await _userDoc();
  if (doc == null) return;
  await doc.set({
    'lastSeen': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

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
  final col = await _subcollection('searches');
  if (col == null) return;
  try {
    await col.add({
      'item': item,
      'lat': lat,
      'lng': lng,
      'locationLabel': locationLabel,
      'resultCount': resultCount,
      'timestamp': FieldValue.serverTimestamp(),
    });
    debugPrint('Firestore: saved search "$item"');
  } catch (e) {
    debugPrint('Firestore: saveSearch failed: $e');
  }
}

/// Get recent searches (newest first), limited to [limit].
Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 20}) async {
  final col = await _subcollection('searches');
  if (col == null) return [];
  try {
    final snap = await col
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();
  } catch (e) {
    debugPrint('Firestore: getRecentSearches failed: $e');
    return [];
  }
}

/// Stream of recent searches (real-time updates).
Stream<List<Map<String, dynamic>>> watchRecentSearches({int limit = 20}) async* {
  final col = await _subcollection('searches');
  if (col == null) {
    yield [];
    return;
  }
  yield* col
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            data['id'] = d.id;
            return data;
          }).toList());
}

/// Delete a search from history.
Future<void> deleteSearch(String docId) async {
  final col = await _subcollection('searches');
  if (col == null) return;
  try {
    await col.doc(docId).delete();
  } catch (e) {
    debugPrint('Firestore: deleteSearch failed: $e');
  }
}

/// Clear all search history (batched in groups of 500).
Future<void> clearSearchHistory() async {
  final col = await _subcollection('searches');
  if (col == null) return;
  try {
    final snap = await col.get();
    for (var i = 0; i < snap.docs.length; i += 500) {
      final batch = _db.batch();
      final end = (i + 500 > snap.docs.length) ? snap.docs.length : i + 500;
      for (final doc in snap.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    debugPrint('Firestore: cleared search history');
  } catch (e) {
    debugPrint('Firestore: clearSearchHistory failed: $e');
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
  final col = await _subcollection('favorites');
  if (col == null) return;
  try {
    await col.doc(storeId.replaceAll('/', '_')).set({
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
      'timestamp': FieldValue.serverTimestamp(),
    });
    debugPrint('Firestore: added favorite "$storeName"');
  } catch (e) {
    debugPrint('Firestore: addFavorite failed: $e');
  }
}

/// Remove a store from favorites.
Future<void> removeFavorite(String storeId) async {
  final col = await _subcollection('favorites');
  if (col == null) return;
  try {
    await col.doc(storeId.replaceAll('/', '_')).delete();
    debugPrint('Firestore: removed favorite "$storeId"');
  } catch (e) {
    debugPrint('Firestore: removeFavorite failed: $e');
  }
}

/// Check if a store is favorited.
Future<bool> isFavorite(String storeId) async {
  final col = await _subcollection('favorites');
  if (col == null) return false;
  try {
    final doc = await col.doc(storeId.replaceAll('/', '_')).get();
    return doc.exists;
  } catch (e) {
    debugPrint('Firestore: isFavorite failed: $e');
    return false;
  }
}

/// Get all favorites.
Future<List<Map<String, dynamic>>> getFavorites() async {
  final col = await _subcollection('favorites');
  if (col == null) return [];
  try {
    final snap = await col
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();
  } catch (e) {
    debugPrint('Firestore: getFavorites failed: $e');
    return [];
  }
}

/// Stream of favorites (real-time updates).
Stream<List<Map<String, dynamic>>> watchFavorites() async* {
  final col = await _subcollection('favorites');
  if (col == null) {
    yield [];
    return;
  }
  yield* col
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            data['id'] = d.id;
            return data;
          }).toList());
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
  final col = await _subcollection('recommendations');
  if (col == null) return;
  try {
    await col.add({
      'title': title,
      'content': content,
      'basedOn': basedOn,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint('Firestore: saveRecommendation failed: $e');
  }
}

/// Get recent recommendations.
Future<List<Map<String, dynamic>>> getRecommendations({int limit = 10}) async {
  final col = await _subcollection('recommendations');
  if (col == null) return [];
  try {
    final snap = await col
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();
  } catch (e) {
    debugPrint('Firestore: getRecommendations failed: $e');
    return [];
  }
}
