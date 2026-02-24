import '../models/shopping_list_models.dart';
import '../services/firestore_service.dart' as db;

/// Load all shopping lists from local storage.
Future<List<ShoppingList>> loadShoppingLists() async {
  final raw = await db.getShoppingLists();
  return raw.map((m) => ShoppingList.fromJson(m)).toList();
}

/// Persist all shopping lists.
Future<void> persistShoppingLists(List<ShoppingList> lists) async {
  await db.saveShoppingLists(
      lists.take(10).map((l) => l.toJson()).toList());
}

/// Greedy set-cover algorithm to find 1-2 stores covering the most items.
///
/// [storeItemMap] maps storeName -> set of item names this store carries.
/// [storeDistances] maps storeName -> distance in km (optional).
/// Returns a sorted list of StoreCombo (best coverage first).
List<StoreCombo> computeOptimalCombos({
  required Map<String, Set<String>> storeItemMap,
  required Map<String, String> storeIdMap,
  Map<String, double>? storeDistances,
  Map<String, Map<String, double>>? storePrices,
}) {
  if (storeItemMap.isEmpty) return [];

  final combos = <StoreCombo>[];
  final remainingItems = <String>{};
  for (final items in storeItemMap.values) {
    remainingItems.addAll(items);
  }

  // Greedy: pick store covering the most uncovered items
  final usedStores = <String>{};

  for (var round = 0; round < 2 && remainingItems.isNotEmpty; round++) {
    String? bestStore;
    Set<String> bestCovered = {};

    for (final entry in storeItemMap.entries) {
      if (usedStores.contains(entry.key)) continue;
      final covered = entry.value.intersection(remainingItems);
      if (covered.length > bestCovered.length) {
        bestStore = entry.key;
        bestCovered = covered;
      }
    }

    if (bestStore == null || bestCovered.isEmpty) break;

    usedStores.add(bestStore);
    remainingItems.removeAll(bestCovered);

    double total = 0;
    if (storePrices != null && storePrices.containsKey(bestStore)) {
      for (final item in bestCovered) {
        total += storePrices[bestStore]?[item] ?? 0;
      }
    }

    combos.add(StoreCombo(
      storeName: bestStore,
      storeId: storeIdMap[bestStore] ?? '',
      coveredItems: bestCovered.toList()..sort(),
      totalPrice: total,
      distanceKm: storeDistances?[bestStore],
    ));
  }

  return combos;
}
