import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_models.dart';
import '../services/content_safety_service.dart';
import '../services/geocode_service.dart';
import '../services/firestore_service.dart' as db;
import '../services/store_filters.dart';
import '../widgets/design_system.dart';
import '../widgets/settings_panel.dart';
import '../version.dart';
import 'app_shell.dart';
import 'results_screen.dart';

// Shared font helper for Outfit
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

// Default suggestions when the user has no search history yet.
const _kDefaultSuggestions = <String>[
  'N95 Masks',
  'Baby Formula',
  'Water',
  'Batteries',
];

const _kRecentSearchesKey = 'recent_searches';
const _kRadiusKey = 'search_radius_miles';
const _kMaxRecent = 8;

class SearchScreen extends StatefulWidget {
  final void Function(SearchResultParams)? onSearchResult;
  final VoidCallback? onOpenProfile;

  const SearchScreen({
    super.key,
    this.onSearchResult,
    this.onOpenProfile,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

// Common items for autocomplete when no recent searches match.
const _kAutocompleteSuggestions = <String>[
  // Batteries & electronics
  'AA Batteries', 'AAA Batteries', 'C Batteries', 'D Batteries', '9V Battery',
  'Phone Charger', 'USB-C Cable', 'USB Cable', 'Lightning Cable',
  'Portable Charger', 'Power Bank', 'Extension Cord', 'Power Strip',
  'Headphones', 'Earbuds', 'Bluetooth Speaker', 'HDMI Cable',
  'Phone Case', 'Screen Protector', 'Memory Card', 'SD Card', 'Flash Drive',
  'Printer Ink', 'Printer Paper', 'Laptop Stand', 'Mouse', 'Keyboard',
  // Baby & kids
  'Baby Formula', 'Baby Wipes', 'Diapers', 'Baby Food', 'Pacifier',
  'Baby Bottles', 'Baby Shampoo', 'Diaper Cream', 'Sippy Cup',
  // Food & beverages
  'Bottled Water', 'Bread', 'Milk', 'Eggs', 'Butter', 'Cheese',
  'Rice', 'Pasta', 'Cereal', 'Coffee', 'Tea', 'Sugar', 'Flour',
  'Olive Oil', 'Cooking Oil', 'Salt', 'Pepper', 'Canned Soup',
  'Peanut Butter', 'Jelly', 'Honey', 'Oatmeal', 'Yogurt',
  'Chicken', 'Ground Beef', 'Fish', 'Frozen Pizza', 'Ice Cream',
  'Chips', 'Crackers', 'Popcorn', 'Granola Bars', 'Protein Bars',
  'Fruit', 'Bananas', 'Apples', 'Oranges', 'Strawberries', 'Avocado',
  'Vegetables', 'Lettuce', 'Tomatoes', 'Onions', 'Potatoes', 'Carrots',
  'Soda', 'Juice', 'Sports Drink', 'Energy Drink',
  // Health & medicine
  'Band-Aids', 'First Aid Kit', 'Thermometer', 'Cold Medicine',
  'Ibuprofen', 'Tylenol', 'Aspirin', 'Allergy Medicine', 'Antihistamine',
  'Cough Syrup', 'Throat Lozenges', 'Vitamin C', 'Vitamins',
  'Pain Reliever', 'Antacid', 'Pepto Bismol', 'Eye Drops',
  'Hydrogen Peroxide', 'Rubbing Alcohol', 'Neosporin', 'Gauze',
  'Ace Bandage', 'Ice Pack', 'Heating Pad', 'Blood Pressure Monitor',
  // Personal care
  'Toothpaste', 'Toothbrush', 'Mouthwash', 'Dental Floss',
  'Shampoo', 'Conditioner', 'Body Wash', 'Soap', 'Hand Soap',
  'Deodorant', 'Razors', 'Shaving Cream', 'Lotion', 'Lip Balm',
  'Sunscreen', 'Hair Gel', 'Hair Spray', 'Cotton Balls', 'Q-Tips',
  'Nail Clippers', 'Tweezers', 'Contact Solution', 'Tampons', 'Pads',
  // Cleaning & household
  'Cleaning Supplies', 'Laundry Detergent', 'Fabric Softener',
  'Dish Soap', 'Dishwasher Pods', 'Bleach', 'All-Purpose Cleaner',
  'Glass Cleaner', 'Windex', 'Lysol', 'Disinfectant Wipes', 'Clorox',
  'Paper Towels', 'Toilet Paper', 'Tissues', 'Trash Bags',
  'Sponges', 'Mop', 'Broom', 'Dustpan', 'Vacuum Bags',
  'Air Freshener', 'Candles', 'Light Bulbs', 'LED Bulbs',
  'Batteries', 'Duct Tape', 'Super Glue', 'WD-40',
  // Pet supplies
  'Dog Food', 'Cat Food', 'Cat Litter', 'Pet Treats', 'Dog Leash',
  'Dog Toys', 'Cat Toys', 'Pet Shampoo', 'Flea Treatment',
  // Outdoor & seasonal
  'Charcoal', 'Lighter Fluid', 'Matches', 'Lighter', 'Flashlight',
  'Lantern', 'Sunscreen', 'Bug Spray', 'Insect Repellent',
  'Ice', 'Ice Melt', 'Rock Salt', 'Snow Shovel',
  'Firewood', 'Propane', 'Garden Hose', 'Lawn Bags',
  'Seeds', 'Potting Soil', 'Fertilizer', 'Plant Pots',
  // Safety
  'N95 Masks', 'Masks', 'Hand Sanitizer', 'Gloves', 'Face Shield',
  'Smoke Detector', 'Carbon Monoxide Detector', 'Fire Extinguisher',
  // Automotive
  'Motor Oil', 'Windshield Fluid', 'Antifreeze', 'Jumper Cables',
  'Tire Gauge', 'Car Air Freshener', 'Gasoline', 'Gas Can',
  // Clothing & accessories
  'Socks', 'Underwear', 'T-Shirt', 'Rain Jacket', 'Umbrella',
  'Sunglasses', 'Winter Gloves', 'Beanie', 'Scarf',
  // Kitchen & home
  'Aluminum Foil', 'Plastic Wrap', 'Ziplock Bags', 'Tupperware',
  'Paper Plates', 'Plastic Cups', 'Napkins', 'Straws',
  'Can Opener', 'Bottle Opener', 'Measuring Cups', 'Cutting Board',
  // Office & school
  'Pens', 'Pencils', 'Markers', 'Highlighters', 'Notebooks',
  'Binder', 'Folders', 'Tape', 'Scissors', 'Stapler', 'Envelopes',
  'Stamps', 'Sticky Notes', 'Index Cards', 'Backpack',
  // Dining out
  'Pizza', 'Burgers', 'Tacos', 'Sushi', 'Chinese Food',
  'Thai Food', 'Indian Food', 'Mexican Food', 'Italian Food',
  'Breakfast', 'Brunch', 'Coffee Shop', 'Bakery', 'Deli',
  // Services
  'Pharmacy', 'Gas Station', 'ATM', 'Bank', 'Post Office',
  'Laundromat', 'Dry Cleaner', 'Hair Salon', 'Barber',
  'Dentist', 'Doctor', 'Urgent Care', 'Veterinarian',
  'Auto Repair', 'Car Wash', 'Tire Shop', 'Oil Change',
  // Stores
  'Grocery Store', 'Convenience Store', 'Hardware Store',
  'Dollar Store', 'Thrift Store', 'Liquor Store',
  'Electronics Store', 'Pet Store', 'Toy Store', 'Book Store',
];

class _SearchScreenState extends State<SearchScreen> {
  final _itemController = TextEditingController();
  final _locationController = TextEditingController();
  final LayerLink _searchBarLayerLink = LayerLink();
  OverlayEntry? _autocompleteOverlay;
  List<String> _autocompleteSuggestions = [];
  bool _useMyLocation = true;
  double _maxDistanceMiles = 5;
  bool _loading = false;
  bool _geocoding = false;
  bool _settingsOpen = false;
  bool _filtersExpanded = false;
  String? _qualityTier; // null = All
  bool _membershipsOnly = false;
  final Set<String> _selectedStores = {};
  List<String> _recentSearches = [];
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadRadius();
    _checkOnboarding();
    _itemController.addListener(_onSearchTextChanged);
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!seen && mounted) {
      setState(() => _showOnboarding = true);
    }
  }

  Future<void> _dismissOnboarding() async {
    setState(() => _showOnboarding = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
  }

  void _onSearchTextChanged() {
    final text = _itemController.text.trim().toLowerCase();
    if (text.isEmpty) {
      _hideAutocomplete();
      return;
    }
    final matches = <String>{};
    for (final r in _recentSearches) {
      if (r.toLowerCase().contains(text) &&
          r.toLowerCase() != text) {
        matches.add(r);
      }
    }
    for (final s in _kAutocompleteSuggestions) {
      if (s.toLowerCase().contains(text) &&
          s.toLowerCase() != text) {
        matches.add(s);
      }
    }
    final list = matches.take(5).toList();
    if (list.isEmpty) {
      _hideAutocomplete();
      return;
    }
    _autocompleteSuggestions = list;
    _showAutocomplete();
  }

  void _showAutocomplete() {
    _hideAutocomplete();
    _autocompleteOverlay = OverlayEntry(builder: (context) {
      final ac = AppColors.of(context);
      return Positioned(
        width: MediaQuery.of(context).size.width < 700
            ? MediaQuery.of(context).size.width - 48
            : 700,
        child: CompositedTransformFollower(
          link: _searchBarLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 64),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(kRadiusMd),
            color: ac.cardBg,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _autocompleteSuggestions.map((s) {
                  return InkWell(
                    onTap: () {
                      _hideAutocomplete();
                      _searchFor(s);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            _recentSearches.contains(s)
                                ? Icons.history
                                : Icons.search,
                            size: 16,
                            color: ac.textTertiary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s,
                              style: _outfit(
                                fontSize: 14,
                                color: ac.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_autocompleteOverlay!);
  }

  void _hideAutocomplete() {
    _autocompleteOverlay?.remove();
    _autocompleteOverlay = null;
  }

  Future<void> _loadRadius() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kRadiusKey);
    if (saved != null && mounted) {
      setState(() => _maxDistanceMiles = saved.clamp(5, 25));
    }
  }

  Future<void> _saveRadius(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRadiusKey, value);
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentSearchesKey);
    if (list != null && list.isNotEmpty && mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _saveRecentSearch(String term) async {
    _recentSearches.remove(term); // deduplicate
    _recentSearches.insert(0, term);
    if (_recentSearches.length > _kMaxRecent) {
      _recentSearches = _recentSearches.sublist(0, _kMaxRecent);
    }
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, _recentSearches);
  }

  Future<void> _removeRecentSearch(String term) async {
    _recentSearches.remove(term);
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, _recentSearches);
  }

  @override
  void dispose() {
    _hideAutocomplete();
    _itemController.removeListener(_onSearchTextChanged);
    _itemController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    print('[Wayvio] _submit called');
    setState(() => _loading = true);
    try {
      final item = _itemController.text.trim();
      if (item.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter what you need.')),
          );
        }
        return;
      }
      final safety = checkQuerySafety(item);
      if (safety.blocked) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(safety.reason ?? 'This search is not allowed.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      double lat;
      double lng;
      print('[Wayvio] _useMyLocation=$_useMyLocation');
      if (_useMyLocation) {
        final perm = await Geolocator.checkPermission();
        print('[Wayvio] location permission: $perm');
        if (perm == LocationPermission.denied) {
          final req = await Geolocator.requestPermission();
          if (req == LocationPermission.denied ||
              req == LocationPermission.deniedForever) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _useMyLocation = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_locationController.text.trim().isEmpty
                    ? 'Please enable location access or enter a city/address to search.'
                    : 'Location denied. Enter a city or address below.'),
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }
        }
        // Try high accuracy first, then medium, then give a helpful error.
        Position pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
        } catch (_) {
          print('[Wayvio] High accuracy failed, trying medium...');
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 15),
            );
          } catch (_) {
            print('[Wayvio] Medium accuracy also failed');
            if (mounted) {
              setState(() {
                _loading = false;
                _useMyLocation = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_locationController.text.trim().isEmpty
                      ? 'Please enable location access or enter a city/address to search.'
                      : 'Location timed out. Please type your city or address below.'),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }
        lat = pos.latitude;
        lng = pos.longitude;
        print('[Wayvio] Got location: $lat, $lng');
      } else {
        var loc = _locationController.text.trim();
        if (loc.length > 200) loc = loc.substring(0, 200);
        if (loc.isEmpty) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Enter a city or address, or use "Use my location".')),
            );
          }
          return;
        }
        print('[Wayvio] Geocoding address: "$loc"');
        setState(() => _geocoding = true);
        final result = await geocode(loc);
        if (mounted) setState(() => _geocoding = false);
        if (result == null) {
          print('[Wayvio] Geocode returned null for "$loc"');
          if (mounted) setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not find that location.')),
            );
          }
          return;
        }
        lat = result.lat;
        lng = result.lng;
        print('[Wayvio] Geocoded "$loc" -> $lat, $lng');
      }
      final filters = SearchFilters(
        qualityTier: _qualityTier,
        membershipsOnly: _membershipsOnly,
        storeNames: _selectedStores.toList(),
      );
      if (!mounted) return;
      _saveRecentSearch(item);

      // Save to Firestore (fire-and-forget, don't block navigation).
      final locationLabel = _useMyLocation
          ? 'Current location'
          : _locationController.text.trim();
      db.saveSearch(
        item: item,
        lat: lat,
        lng: lng,
        locationLabel: locationLabel,
      );

      print('[Wayvio] Navigating to results: item="$item", lat=$lat, lng=$lng, radius=$_maxDistanceMiles mi');
      final params = SearchResultParams(
        item: item,
        lat: lat,
        lng: lng,
        maxDistanceMiles: _maxDistanceMiles,
        filters: filters,
      );
      if (widget.onSearchResult != null) {
        widget.onSearchResult!(params);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              item: item,
              lat: lat,
              lng: lng,
              maxDistanceMiles: _maxDistanceMiles,
              filters: filters,
            ),
          ),
        );
      }
    } catch (e, st) {
      print('[Wayvio] _submit ERROR: $e');
      print('[Wayvio] _submit STACK: $st');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() { _loading = false; _geocoding = false; });
    }
  }

  void _searchFor(String term) {
    _hideAutocomplete();
    _itemController.text = term;
    _submit();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Version label – pinned bottom-right
            Positioned(
              bottom: 10,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ac.glass.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'v$appVersion',
                  style: _outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ac.textSecondary,
                  ),
                ),
              ),
            ),
            // Profile + Settings – pinned top-right
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ac.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: ac.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.person_outline,
                          color: ac.textSecondary, size: 20),
                      tooltip: 'Profile & History',
                      onPressed: widget.onOpenProfile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings gear
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ac.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: ac.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.settings,
                          color: ac.textSecondary, size: 20),
                      tooltip: 'Settings',
                      onPressed: () =>
                          setState(() => _settingsOpen = !_settingsOpen),
                    ),
                  ),
                ],
              ),
            ),
            // Centered content
            Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 48),

                // ── Hero title ──────────────────────────────────────
                Builder(builder: (context) {
                  final isNarrow = MediaQuery.of(context).size.width < 600;
                  return Text(
                    'Wayvio',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.quicksand(
                      fontSize: isNarrow ? 56 : 96,
                      fontWeight: FontWeight.w700,
                      letterSpacing: isNarrow ? -1 : -2,
                      height: 0.95,
                      color: ac.textPrimary,
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // ── Subtitle ────────────────────────────────────────
                Builder(builder: (context) {
                  final isNarrow = MediaQuery.of(context).size.width < 600;
                  return Text(
                    isNarrow
                        ? 'Locate essentials instantly.\nSmart store matching by product type.'
                        : 'Locate essentials instantly. Smart store matching\nby product type and convenience ranking.',
                    textAlign: TextAlign.center,
                    style: _outfit(
                      fontSize: isNarrow ? 15 : 18,
                      color: ac.textSecondary,
                      height: 1.5,
                    ),
                  );
                }),
                const SizedBox(height: 36),

                // ── Search bar (pill) ───────────────────────────────
                _buildSearchBar(),

                // ── Location toggle (below search bar) ──────────────
                const SizedBox(height: 12),
                _buildLocationToggle(),

                // ── Distance slider ──────────────────────────────
                const SizedBox(height: 12),
                _buildDistanceSlider(),

                // ── Filters toggle ───────────────────────────────
                const SizedBox(height: 12),
                _buildFiltersSection(),

                // ── Suggestion pills (recent searches or defaults) ──
                const SizedBox(height: 24),
                if (_recentSearches.isNotEmpty) ...[
                  Text(
                    'Recent searches',
                    style: _outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ac.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: (_recentSearches.isNotEmpty
                          ? _recentSearches
                          : _kDefaultSuggestions)
                      .map((term) {
                    final isRecent = _recentSearches.contains(term);
                    return _SuggestionPill(
                      label: term,
                      onTap: () => _searchFor(term),
                      onRemove: isRecent ? () => _removeRecentSearch(term) : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
            // ── Settings sidebar overlay ──────────────────────────
            // Dim background when open
            if (_settingsOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _settingsOpen = false),
                  child: Container(color: ac.dimOverlay),
                ),
              ),
            // Sliding panel from the right (responsive width)
            Builder(builder: (context) {
              final screenW = MediaQuery.of(context).size.width;
              final sidebarW = screenW < 400 ? screenW.toDouble() : 320.0;
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: _settingsOpen ? 0 : -sidebarW,
                width: sidebarW,
                child: SettingsPanel(
                  onClose: () => setState(() => _settingsOpen = false),
                ),
              );
            }),
            // ── Onboarding overlay ──
            if (_showOnboarding) _buildOnboarding(),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboarding() {
    final ac = AppColors.of(context);
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dismissOnboarding,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ac.cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 40,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: ac.accentGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.waving_hand_rounded,
                        size: 30, color: ac.accentGreen),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Wayvio!',
                    style: _outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ac.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Find nearby stores that sell what you need.\nHere\'s how it works:',
                    textAlign: TextAlign.center,
                    style: _outfit(
                      fontSize: 14,
                      color: ac.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _onboardingStep(ac, Icons.search, 'Search',
                      'Type what you\'re looking for'),
                  const SizedBox(height: 12),
                  _onboardingStep(ac, Icons.location_on, 'Locate',
                      'We find stores near you'),
                  const SizedBox(height: 12),
                  _onboardingStep(ac, Icons.map_outlined, 'Navigate',
                      'Get directions to the closest match'),
                  const SizedBox(height: 12),
                  _onboardingStep(ac, Icons.favorite_border, 'Save',
                      'Favorite stores for quick access'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _dismissOnboarding,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: ac.accentGreen,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Get Started',
                          style: _outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _onboardingStep(AppColors ac, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ac.accentGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: ac.accentGreen),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: _outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ac.textPrimary,
                  )),
              Text(subtitle,
                  style: _outfit(
                    fontSize: 12,
                    color: ac.textTertiary,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    final ac = AppColors.of(context);
    return CompositedTransformTarget(
      link: _searchBarLayerLink,
      child: Container(
      constraints: const BoxConstraints(maxWidth: 700),
      decoration: BoxDecoration(
        color: ac.inputBg,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: ac.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ac.isDark ? 0.3 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(Icons.search, color: ac.textTertiary, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: _itemController,
              style: _outfit(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: ac.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: "What are you looking for? e.g. 'AA Batteries'",
                hintStyle: _outfit(
                  fontSize: 17,
                  color: ac.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                filled: false,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _hideAutocomplete();
                _submit();
              },
              onChanged: (_) => GradientBackground.onKeystroke(context),
              enabled: !_loading,
            ),
          ),
          _SearchButton(
            onPressed: _loading
                ? null
                : () {
                    _hideAutocomplete();
                    _submit();
                  },
            loading: _loading,
          ),
        ],
      ),
    ),
    );
  }

  // ── Location toggle ─────────────────────────────────────────────────────
  Widget _buildLocationToggle() {
    final ac = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _useMyLocation,
                  onChanged:
                      _loading ? null : (v) => setState(() => _useMyLocation = v ?? true),
                  side: BorderSide(color: ac.borderStrong),
                  checkColor: Colors.white,
                  fillColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected)
                          ? ac.accentGreen
                          : Colors.transparent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Use my location',
                style: _outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: ac.textSecondary,
                ),
              ),
            ],
          ),
          if (!_useMyLocation) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: ac.inputBg,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: ac.borderSubtle),
              ),
              child: TextField(
                controller: _locationController,
                style: _outfit(
                    fontSize: 14, color: ac.textPrimary),
                decoration: InputDecoration(
                  hintText: 'City or address',
                  hintStyle: _outfit(
                      fontSize: 14, color: ac.textTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  prefixIcon: Icon(Icons.place_outlined,
                      color: ac.textTertiary, size: 18),
                  filled: false,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                enabled: !_loading,
              ),
            ),
            if (_geocoding)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: ac.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Locating…',
                      style: _outfit(
                        fontSize: 11,
                        color: ac.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
  // ── Distance slider ─────────────────────────────────────────────────────
  Widget _buildDistanceSlider() {
    final ac = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Row(
        children: [
          Icon(Icons.near_me, size: 14, color: ac.textTertiary),
          const SizedBox(width: 6),
          Text(
            'Radius: ${_maxDistanceMiles.round()} mi',
            style: _outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ac.textSecondary,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: ac.accentGreen,
                inactiveTrackColor: ac.borderSubtle,
                thumbColor: ac.accentGreen,
                overlayColor: ac.accentGreen.withValues(alpha: 0.12),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _maxDistanceMiles,
                min: 5,
                max: 25,
                divisions: 20,
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() => _maxDistanceMiles = v);
                        _saveRadius(v);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters section ─────────────────────────────────────────────────────
  Widget _buildFiltersSection() {
    final ac = AppColors.of(context);
    final hasActive = _qualityTier != null || _membershipsOnly || _selectedStores.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasActive ? Icons.filter_list : Icons.tune,
                  size: 16,
                  color: hasActive ? ac.accentGreen : ac.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  hasActive ? 'Filters (active)' : 'Filters',
                  style: _outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: hasActive ? ac.accentGreen : ac.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _filtersExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: ac.textTertiary,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Store type',
                      style: _outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ac.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [null, 'Premium', 'Standard', 'Budget']
                        .map((tier) => _FilterChip(
                              label: tier ?? 'All',
                              selected: _qualityTier == tier,
                              onTap: () =>
                                  setState(() => _qualityTier = tier),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => setState(
                        () => _membershipsOnly = !_membershipsOnly),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: _membershipsOnly,
                            onChanged: (v) => setState(
                                () => _membershipsOnly = v ?? false),
                            side: BorderSide(color: ac.borderStrong),
                            checkColor: Colors.white,
                            fillColor:
                                WidgetStateProperty.resolveWith((s) =>
                                    s.contains(WidgetState.selected)
                                        ? ac.accentGreen
                                        : Colors.transparent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Membership stores only',
                            style: _outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: ac.textSecondary,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Specific stores
                  Text('Specific stores',
                      style: _outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ac.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: commonStoresForFilter.map((name) {
                      final sel = _selectedStores.contains(name);
                      return _FilterChip(
                        label: name,
                        selected: sel,
                        onTap: () => setState(() {
                          if (sel) {
                            _selectedStores.remove(name);
                          } else {
                            _selectedStores.add(name);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            crossFadeState: _filtersExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ac.accentGreen : ac.glass,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(
            color: selected ? ac.accentGreen : ac.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: _outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : ac.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Circular search button ────────────────────────────────────────────────

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: loading ? ac.borderStrong : ac.accentGreen,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        hoverColor: ac.isDark ? const Color(0xFF3DA668) : const Color(0xFF2D7048),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Suggestion pill ───────────────────────────────────────────────────────

class _SuggestionPill extends StatefulWidget {
  const _SuggestionPill({
    required this.label,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  State<_SuggestionPill> createState() => _SuggestionPillState();
}

class _SuggestionPillState extends State<_SuggestionPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          padding: EdgeInsets.only(
            left: 20,
            right: widget.onRemove != null ? 8 : 20,
            top: 10,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: _hovered ? ac.borderSubtle : ac.glass,
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: ac.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: _outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ac.textPrimary,
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: ac.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

