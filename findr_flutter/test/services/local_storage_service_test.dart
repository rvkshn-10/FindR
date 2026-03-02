import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:findr_flutter/services/local_storage_service.dart';

void main() {
  group('LocalStorageService Tests', () {
    setUp(() async {
      // Clear all SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      clearPrefsCache();
    });

    group('Search History', () {
      test('should save and retrieve search history', () async {
        const item = 'milk';
        const lat = 37.7749;
        const lng = -122.4194;
        const locationLabel = 'San Francisco, CA';
        
        await saveSearch(
          item: item,
          lat: lat,
          lng: lng,
          locationLabel: locationLabel,
          resultCount: 5,
        );

        final searches = await getRecentSearches();
        expect(searches.length, 1);
        expect(searches.first['item'], item);
        expect(searches.first['lat'], lat);
        expect(searches.first['lng'], lng);
        expect(searches.first['locationLabel'], locationLabel);
        expect(searches.first['resultCount'], 5);
      });

      test('should limit search history to 100 entries', () async {
        // Add 105 searches
        for (int i = 0; i < 105; i++) {
          await saveSearch(
            item: 'item_$i',
            lat: 37.0 + i * 0.01,
            lng: -122.0 + i * 0.01,
            locationLabel: 'Location $i',
          );
        }

        final searches = await getRecentSearches(limit: 200); // Get all searches
        expect(searches.length, 100); // Should be limited to 100 by saveSearch
      });

      test('should delete specific search', () async {
        await saveSearch(
          item: 'test',
          lat: 37.0,
          lng: -122.0,
          locationLabel: 'Test',
        );

        final searches = await getRecentSearches();
        final docId = searches.first['id'] as String;

        await deleteSearch(docId);

        final updatedSearches = await getRecentSearches();
        expect(updatedSearches.isEmpty, true);
      });

      test('should clear all search history', () async {
        await saveSearch(
          item: 'test1',
          lat: 37.0,
          lng: -122.0,
          locationLabel: 'Test1',
        );
        await saveSearch(
          item: 'test2',
          lat: 38.0,
          lng: -123.0,
          locationLabel: 'Test2',
        );

        await clearSearchHistory();

        final searches = await getRecentSearches();
        expect(searches.isEmpty, true);
      });
    });

    group('Favorites', () {
      test('should add and retrieve favorites', () async {
        await addFavorite(
          storeId: 'store_123',
          storeName: 'Test Store',
          address: '123 Test St',
          lat: 37.0,
          lng: -122.0,
          searchItem: 'milk',
        );

        final favorites = await getFavorites();
        expect(favorites.length, 1);
        expect(favorites.first['storeName'], 'Test Store');
        expect(favorites.first['address'], '123 Test St');
      });

      test('should check if store is favorited', () async {
        const storeId = 'store_123';
        
        expect(await isFavorite(storeId), false);

        await addFavorite(
          storeId: storeId,
          storeName: 'Test Store',
          address: '123 Test St',
          lat: 37.0,
          lng: -122.0,
          searchItem: 'milk',
        );

        expect(await isFavorite(storeId), true);
      });

      test('should remove favorite', () async {
        const storeId = 'store_123';
        
        await addFavorite(
          storeId: storeId,
          storeName: 'Test Store',
          address: '123 Test St',
          lat: 37.0,
          lng: -122.0,
          searchItem: 'milk',
        );

        expect(await isFavorite(storeId), true);

        await removeFavorite(storeId);

        expect(await isFavorite(storeId), false);
      });
    });

    group('Store Notes', () {
      test('should save and retrieve store notes', () async {
        const storeId = 'store_123';
        const note = 'Great store!';

        await saveStoreNote(storeId, note);

        final retrieved = await getStoreNote(storeId);
        expect(retrieved, note);
      });

      test('should handle empty notes', () async {
        const storeId = 'store_123';
        const note = 'Great store!';

        await saveStoreNote(storeId, note);
        expect(await getStoreNote(storeId), note);

        await saveStoreNote(storeId, '');
        expect(await getStoreNote(storeId), null);
      });
    });

    group('Store Reviews', () {
      test('should save and retrieve store reviews', () async {
        const storeId = 'store_123';
        const availability = 5;
        const speed = 4;
        const parking = 3;

        await saveStoreReview(storeId, availability, speed, parking);

        final review = await getStoreReview(storeId);
        expect(review, isNotNull);
        expect(review!['availability'], availability);
        expect(review['speed'], speed);
        expect(review['parking'], parking);
      });

      test('should get all store reviews', () async {
        await saveStoreReview('store_1', 5, 4, 3);
        await saveStoreReview('store_2', 4, 5, 4);

        final allReviews = await getAllStoreReviews();
        expect(allReviews.length, 2);
        expect(allReviews.containsKey('store_1'), true);
        expect(allReviews.containsKey('store_2'), true);
      });
    });

    group('Visit Tracking', () {
      test('should track store visits', () async {
        const storeId = 'store_123';

        await markVisited(storeId);

        final count = await getVisitCount(storeId);
        expect(count, 1);

        final history = await getVisitHistory(storeId);
        expect(history.length, 1);
        expect(history.first.containsKey('timestamp'), true);
      });

      test('should count multiple visits', () async {
        const storeId = 'store_123';

        await markVisited(storeId);
        await markVisited(storeId);
        await markVisited(storeId);

        final count = await getVisitCount(storeId);
        expect(count, 3);
      });
    });

    group('Price History', () {
      test('should save and retrieve price snapshots', () async {
        const storeId = 'store_123';
        const item = 'milk';
        const price = 3.99;

        await savePriceSnapshot(storeId, item, price);

        // No previous price should return null
        expect(await getPreviousPrice(storeId, item), null);

        // Save another price
        await savePriceSnapshot(storeId, item, 4.29);

        // Now we should have a previous price
        final previousPrice = await getPreviousPrice(storeId, item);
        expect(previousPrice, price);
      });
    });

    group('Error Handling', () {
      test('should handle corrupted data gracefully', () async {
        // Simulate corrupted data by directly setting invalid JSON
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('findr_searches', 'invalid json');

        final searches = await getRecentSearches();
        expect(searches.isEmpty, true);
      });
    });
  });
}
