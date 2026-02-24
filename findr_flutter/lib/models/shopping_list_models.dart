import 'dart:math';

class ShoppingItem {
  final String id;
  final String name;
  int quantity;
  final String? category;
  double? priceEstimate;
  List<String> foundAtStores;
  bool checked;

  ShoppingItem({
    String? id,
    required this.name,
    this.quantity = 1,
    this.category,
    this.priceEstimate,
    this.foundAtStores = const [],
    this.checked = false,
  }) : id = id ?? _randomId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'category': category,
        'priceEstimate': priceEstimate,
        'foundAtStores': foundAtStores,
        'checked': checked,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> m) => ShoppingItem(
        id: m['id'] as String? ?? _randomId(),
        name: m['name'] as String? ?? '',
        quantity: m['quantity'] as int? ?? 1,
        category: m['category'] as String?,
        priceEstimate: (m['priceEstimate'] as num?)?.toDouble(),
        foundAtStores:
            (m['foundAtStores'] as List<dynamic>?)?.cast<String>() ?? [],
        checked: m['checked'] as bool? ?? false,
      );
}

class ShoppingList {
  final String id;
  String name;
  List<ShoppingItem> items;
  final DateTime createdAt;
  DateTime updatedAt;

  ShoppingList({
    String? id,
    required this.name,
    List<ShoppingItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _randomId(),
        items = items ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory ShoppingList.fromJson(Map<String, dynamic> m) => ShoppingList(
        id: m['id'] as String? ?? _randomId(),
        name: m['name'] as String? ?? 'Untitled',
        items: (m['items'] as List<dynamic>?)
                ?.map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            m['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            m['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      );

  double get totalEstimate => items.fold<double>(
      0, (sum, i) => sum + (i.priceEstimate ?? 0) * i.quantity);

  int get checkedCount => items.where((i) => i.checked).length;
}

/// Store combo result after running "Find All".
class StoreCombo {
  final String storeName;
  final String storeId;
  final List<String> coveredItems;
  final double totalPrice;
  final double? distanceKm;

  const StoreCombo({
    required this.storeName,
    required this.storeId,
    required this.coveredItems,
    required this.totalPrice,
    this.distanceKm,
  });
}

String _randomId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
}

// Pre-built emergency kit templates.
class ListTemplate {
  final String name;
  final IconDataRef icon;
  final List<String> items;
  const ListTemplate(
      {required this.name, required this.icon, required this.items});
}

enum IconDataRef {
  home,
  car,
  flashOn,
  localHospital,
  outdoorGrill,
  school,
}

const kListTemplates = <ListTemplate>[
  ListTemplate(
    name: 'Apartment move-in',
    icon: IconDataRef.home,
    items: [
      'Paper towels', 'Trash bags', 'Cleaning spray', 'Dish soap',
      'Sponges', 'Light bulbs', 'Batteries', 'Toilet paper',
      'Hand soap', 'Laundry detergent',
    ],
  ),
  ListTemplate(
    name: 'Road trip kit',
    icon: IconDataRef.car,
    items: [
      'Snacks', 'Water bottles', 'Phone charger', 'Sunglasses',
      'First aid kit', 'Napkins', 'Trash bags', 'Sunscreen',
    ],
  ),
  ListTemplate(
    name: 'Power outage kit',
    icon: IconDataRef.flashOn,
    items: [
      'Flashlight', 'Batteries', 'Candles', 'Matches',
      'Bottled water', 'Canned food', 'Can opener', 'Blanket',
      'Portable charger',
    ],
  ),
  ListTemplate(
    name: 'Sick day kit',
    icon: IconDataRef.localHospital,
    items: [
      'Tissues', 'Cough medicine', 'Soup', 'Tea', 'Honey',
      'Thermometer', 'Vitamin C', 'Crackers', 'Gatorade',
    ],
  ),
  ListTemplate(
    name: 'BBQ / cookout',
    icon: IconDataRef.outdoorGrill,
    items: [
      'Charcoal', 'Lighter fluid', 'Paper plates', 'Napkins',
      'Ketchup', 'Mustard', 'Buns', 'Burgers', 'Hot dogs', 'Chips',
    ],
  ),
  ListTemplate(
    name: 'Study session',
    icon: IconDataRef.school,
    items: [
      'Notebooks', 'Pens', 'Highlighters', 'Sticky notes',
      'Snacks', 'Energy drinks', 'Headphones',
    ],
  ),
];
