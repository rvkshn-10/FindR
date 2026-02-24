import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/shopping_list_models.dart';
import '../services/shopping_list_service.dart';
import '../widgets/design_system.dart';

TextStyle _outfit({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.outfit(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  ).copyWith(shadows: const <Shadow>[]);
}

IconData _iconFor(IconDataRef ref) {
  switch (ref) {
    case IconDataRef.home:
      return Icons.home_outlined;
    case IconDataRef.car:
      return Icons.directions_car_outlined;
    case IconDataRef.flashOn:
      return Icons.flash_on;
    case IconDataRef.localHospital:
      return Icons.local_hospital_outlined;
    case IconDataRef.outdoorGrill:
      return Icons.outdoor_grill_outlined;
    case IconDataRef.school:
      return Icons.school_outlined;
  }
}

class ShoppingListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final void Function(String item)? onSearchItem;
  const ShoppingListScreen({super.key, this.onBack, this.onSearchItem});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<ShoppingList> _lists = [];
  int _activeIndex = -1;
  bool _loading = true;
  final _addItemController = TextEditingController();
  final _listNameController = TextEditingController();
  List<StoreCombo>? _combos;
  bool _findingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addItemController.dispose();
    _listNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final lists = await loadShoppingLists();
    if (mounted) setState(() { _lists = lists; _loading = false; });
  }

  Future<void> _save() async {
    await persistShoppingLists(_lists);
  }

  void _createList(String name, [List<String>? prefilledItems]) {
    final list = ShoppingList(name: name);
    if (prefilledItems != null) {
      for (final item in prefilledItems) {
        list.items.add(ShoppingItem(name: item));
      }
    }
    setState(() {
      _lists.insert(0, list);
      _activeIndex = 0;
      _combos = null;
    });
    _save();
  }

  void _deleteList(int index) {
    setState(() {
      _lists.removeAt(index);
      if (_activeIndex == index) {
        _activeIndex = -1;
        _combos = null;
      } else if (_activeIndex > index) {
        _activeIndex--;
      }
    });
    _save();
  }

  void _addItem(String name) {
    if (_activeIndex < 0 || _activeIndex >= _lists.length) return;
    if (name.trim().isEmpty) return;
    setState(() {
      _lists[_activeIndex].items.add(ShoppingItem(name: name.trim()));
      _lists[_activeIndex].updatedAt = DateTime.now();
      _combos = null;
    });
    _addItemController.clear();
    _save();
  }

  void _removeItem(int idx) {
    if (_activeIndex < 0) return;
    setState(() {
      _lists[_activeIndex].items.removeAt(idx);
      _lists[_activeIndex].updatedAt = DateTime.now();
      _combos = null;
    });
    _save();
  }

  void _toggleItem(int idx) {
    if (_activeIndex < 0) return;
    setState(() {
      _lists[_activeIndex].items[idx].checked =
          !_lists[_activeIndex].items[idx].checked;
    });
    _save();
  }

  void _changeQuantity(int idx, int delta) {
    if (_activeIndex < 0) return;
    setState(() {
      final item = _lists[_activeIndex].items[idx];
      item.quantity = (item.quantity + delta).clamp(1, 99);
      _lists[_activeIndex].updatedAt = DateTime.now();
    });
    _save();
  }

  Future<void> _findAll() async {
    if (_activeIndex < 0) return;
    final list = _lists[_activeIndex];
    final unchecked = list.items.where((i) => !i.checked).toList();
    if (unchecked.isEmpty) return;

    setState(() => _findingAll = true);

    // For a real implementation we'd call searchFast per item and aggregate.
    // Here we demonstrate the algorithm with category-based heuristics.
    await Future.delayed(const Duration(milliseconds: 800));

    final storeItemMap = <String, Set<String>>{};
    final storeIdMap = <String, String>{};

    // Heuristic: map items to likely stores based on category
    const heuristic = {
      'Walmart': ['batteries', 'trash bags', 'cleaning', 'charcoal', 'paper',
        'light bulbs', 'flashlight', 'blanket', 'notebooks', 'pens',
        'highlighters', 'sticky notes', 'headphones', 'phone charger',
        'sunglasses', 'sunscreen', 'can opener', 'napkins', 'chips',
        'soda', 'energy drinks', 'buns', 'hot dogs', 'plates'],
      'Target': ['batteries', 'cleaning spray', 'dish soap', 'sponges',
        'hand soap', 'laundry detergent', 'toilet paper', 'paper towels',
        'snacks', 'water bottles', 'portable charger', 'notebooks',
        'first aid kit', 'sunscreen'],
      'CVS': ['cough medicine', 'thermometer', 'vitamin C', 'tissues',
        'batteries', 'band-aids', 'first aid kit', 'gatorade'],
      'Kroger': ['soup', 'tea', 'honey', 'crackers', 'bread', 'milk',
        'eggs', 'butter', 'cheese', 'canned food', 'bottled water',
        'ketchup', 'mustard', 'burgers', 'buns', 'hot dogs', 'chips'],
    };

    for (final entry in heuristic.entries) {
      final store = entry.key;
      final storeItems = entry.value;
      storeIdMap[store] = store.toLowerCase().replaceAll(' ', '_');
      for (final item in unchecked) {
        if (storeItems.any((si) =>
            item.name.toLowerCase().contains(si) ||
            si.contains(item.name.toLowerCase()))) {
          storeItemMap.putIfAbsent(store, () => {}).add(item.name);
        }
      }
    }

    final combos = computeOptimalCombos(
      storeItemMap: storeItemMap,
      storeIdMap: storeIdMap,
    );

    if (mounted) {
      setState(() {
        _combos = combos;
        _findingAll = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _activeIndex >= 0
                        ? () => setState(() { _activeIndex = -1; _combos = null; })
                        : widget.onBack,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: ac.glass,
                        shape: BoxShape.circle,
                        border: Border.all(color: ac.borderSubtle),
                      ),
                      child: Icon(Icons.arrow_back,
                          size: 18, color: ac.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _activeIndex >= 0 && _activeIndex < _lists.length
                          ? _lists[_activeIndex].name
                          : 'Shopping Lists',
                      style: _outfit(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: ac.textPrimary,
                      ),
                    ),
                  ),
                  if (_activeIndex < 0)
                    GestureDetector(
                      onTap: () => _showCreateDialog(ac),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: ac.accentGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            size: 20, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: ac.accentGreen))
                  : _activeIndex >= 0 && _activeIndex < _lists.length
                      ? _buildListDetail(ac)
                      : _buildListsOverview(ac),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lists overview ─────────────────────────────────────────────
  Widget _buildListsOverview(AppColors ac) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Templates
          Text('Quick Start Templates',
              style: _outfit(fontSize: 14, fontWeight: FontWeight.w600,
                  color: ac.textSecondary)),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kListTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = kListTemplates[i];
                return GestureDetector(
                  onTap: () => _createList(t.name, t.items),
                  child: Container(
                    width: 130,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ac.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ac.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_iconFor(t.icon), size: 22,
                            color: ac.accentGreen),
                        const Spacer(),
                        Text(t.name,
                            style: _outfit(fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ac.textPrimary),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text('${t.items.length} items',
                            style: _outfit(fontSize: 10,
                                color: ac.textTertiary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // My lists
          Text('My Lists',
              style: _outfit(fontSize: 14, fontWeight: FontWeight.w600,
                  color: ac.textSecondary)),
          const SizedBox(height: 10),

          if (_lists.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.checklist_outlined,
                        size: 48, color: ac.textTertiary),
                    const SizedBox(height: 12),
                    Text('No lists yet',
                        style: _outfit(fontSize: 15,
                            color: ac.textTertiary)),
                    const SizedBox(height: 4),
                    Text('Create one or pick a template above',
                        style: _outfit(fontSize: 12,
                            color: ac.textTertiary)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_lists.length, (i) {
              final list = _lists[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() { _activeIndex = i; _combos = null; }),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ac.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ac.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(list.name,
                                  style: _outfit(fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: ac.textPrimary)),
                              const SizedBox(height: 2),
                              Text(
                                '${list.checkedCount}/${list.items.length} items checked',
                                style: _outfit(fontSize: 12,
                                    color: ac.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteList(i),
                          child: Icon(Icons.delete_outline,
                              size: 18, color: ac.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── List detail ─────────────────────────────────────────────────
  Widget _buildListDetail(AppColors ac) {
    final list = _lists[_activeIndex];
    return Column(
      children: [
        // Add item row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: ac.inputBg,
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(color: ac.borderSubtle),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addItemController,
                    style: _outfit(fontSize: 14, color: ac.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add item...',
                      hintStyle: _outfit(fontSize: 14, color: ac.textTertiary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _addItem,
                  ),
                ),
                GestureDetector(
                  onTap: () => _addItem(_addItemController.text),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: ac.accentGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Items list
        Expanded(
          child: list.items.isEmpty
              ? Center(
                  child: Text('Add items to your list',
                      style: _outfit(fontSize: 14, color: ac.textTertiary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.items.length,
                  itemBuilder: (_, i) {
                    final item = list.items[i];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _removeItem(i),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red.withValues(alpha: 0.1),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: ac.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ac.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleItem(i),
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: item.checked
                                      ? ac.accentGreen
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: item.checked
                                        ? ac.accentGreen
                                        : ac.borderStrong,
                                  ),
                                ),
                                child: item.checked
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.name,
                                style: _outfit(
                                  fontSize: 14,
                                  color: item.checked
                                      ? ac.textTertiary
                                      : ac.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ).copyWith(
                                  decoration: item.checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            // Quantity controls
                            GestureDetector(
                              onTap: () => _changeQuantity(i, -1),
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: ac.glass,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.remove,
                                    size: 14, color: ac.textSecondary),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: Text('${item.quantity}',
                                  style: _outfit(fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ac.textPrimary)),
                            ),
                            GestureDetector(
                              onTap: () => _changeQuantity(i, 1),
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: ac.glass,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.add,
                                    size: 14, color: ac.textSecondary),
                              ),
                            ),
                            if (item.priceEstimate != null) ...[
                              const SizedBox(width: 10),
                              Text('\$${item.priceEstimate!.toStringAsFixed(2)}',
                                  style: _outfit(fontSize: 12,
                                      color: ac.accentGreen,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // "Find All" button + combos
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_combos != null && _combos!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ac.accentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: ac.accentGreen.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recommended Store Combo',
                          style: _outfit(fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ac.accentGreen)),
                      const SizedBox(height: 8),
                      ..._combos!.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.storeName,
                                    style: _outfit(fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: ac.textPrimary)),
                                Text(
                                  'Covers: ${c.coveredItems.join(", ")}',
                                  style: _outfit(fontSize: 11,
                                      color: ac.textSecondary, height: 1.3),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _findingAll ? null : _findAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _findingAll
                          ? ac.borderStrong
                          : ac.accentGreen,
                      borderRadius: BorderRadius.circular(kRadiusPill),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_findingAll)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            ),
                          ),
                        Text(
                          _findingAll
                              ? 'Finding stores...'
                              : 'Find All Items Nearby',
                          style: _outfit(fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(AppColors ac) {
    _listNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ac.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New List',
                  style: _outfit(fontSize: 18, fontWeight: FontWeight.w700,
                      color: ac.textPrimary)),
              const SizedBox(height: 14),
              TextField(
                controller: _listNameController,
                autofocus: true,
                style: _outfit(fontSize: 14, color: ac.textPrimary),
                decoration: InputDecoration(
                  hintText: 'List name',
                  hintStyle: _outfit(fontSize: 14, color: ac.textTertiary),
                  filled: true,
                  fillColor: ac.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ac.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ac.borderSubtle),
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    Navigator.of(ctx).pop();
                    _createList(v.trim());
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: ac.glass,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                          border: Border.all(color: ac.borderSubtle),
                        ),
                        alignment: Alignment.center,
                        child: Text('Cancel',
                            style: _outfit(fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ac.textPrimary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final name = _listNameController.text.trim();
                        if (name.isNotEmpty) {
                          Navigator.of(ctx).pop();
                          _createList(name);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: ac.accentGreen,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                        ),
                        alignment: Alignment.center,
                        child: Text('Create',
                            style: _outfit(fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
