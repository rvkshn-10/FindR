/// Firestore service for persisting user data.
///
/// Collections:
///   users/{uid}/searches    — search history
///   users/{uid}/favorites   — favorited stores
///   users/{uid}/recommendations — AI-generated personalized recommendations
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart' as auth;

final _db = FirebaseFirestore.instance;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DocumentReference? _userDoc() {
  final uid = auth.currentUser?.uid;
  if (uid == null) return null;
  return _db.collection('users').doc(uid);
}

CollectionReference? _subcollection(String name) {
  return _userDoc()?.collection(name);
}

// ---------------------------------------------------------------------------
// User profile
// ---------------------------------------------------------------------------

/// Ensure user document exists and update last-seen timestamp.
Future<void> ensureUserDoc() async {
  final doc = _userDoc();
  if (doc == null) return;
  await doc.set({
    'displayName': auth.displayName,
    'email': auth.email,
    'photoUrl': auth.photoUrl,
    'lastSeen': FieldValue.serverTimestamp(),
    'isAnonymous': auth.isAnonymous,
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
  final col = _subcollection('searches');
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
  final col = _subcollection('searches');
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
Stream<List<Map<String, dynamic>>> watchRecentSearches({int limit = 20}) {
  final col = _subcollection('searches');
  if (col == null) return Stream.value([]);
  return col
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
  final col = _subcollection('searches');
  if (col == null) return;
  await col.doc(docId).delete();
}

/// Clear all search history.
Future<void> clearSearchHistory() async {
  final col = _subcollection('searches');
  if (col == null) return;
  final snap = await col.get();
  final batch = _db.batch();
  for (final doc in snap.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
  debugPrint('Firestore: cleared search history');
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
  final col = _subcollection('favorites');
  if (col == null) return;
  try {
    // Use storeId as doc ID to prevent duplicates.
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
  final col = _subcollection('favorites');
  if (col == null) return;
  await col.doc(storeId.replaceAll('/', '_')).delete();
  debugPrint('Firestore: removed favorite "$storeId"');
}

/// Check if a store is favorited.
Future<bool> isFavorite(String storeId) async {
  final col = _subcollection('favorites');
  if (col == null) return false;
  final doc = await col.doc(storeId.replaceAll('/', '_')).get();
  return doc.exists;
}

/// Get all favorites.
Future<List<Map<String, dynamic>>> getFavorites() async {
  final col = _subcollection('favorites');
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
Stream<List<Map<String, dynamic>>> watchFavorites() {
  final col = _subcollection('favorites');
  if (col == null) return Stream.value([]);
  return col
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
  final col = _subcollection('recommendations');
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
  final col = _subcollection('recommendations');
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
