import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_models.dart';
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

class _SearchScreenState extends State<SearchScreen> {
  final _itemController = TextEditingController();
  final _locationController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadRadius();
  }

  Future<void> _loadRadius() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kRadiusKey);
    if (saved != null && mounted) {
      setState(() => _maxDistanceMiles = saved.clamp(1, 25));
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

  @override
  void dispose() {
    _itemController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      double lat;
      double lng;
      if (_useMyLocation) {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          final req = await Geolocator.requestPermission();
          if (req == LocationPermission.denied ||
              req == LocationPermission.deniedForever) {
            setState(() => _loading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Location denied. Enter a city or address below.')),
              );
            }
            return;
          }
        }
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        lat = pos.latitude;
        lng = pos.longitude;
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
        setState(() => _geocoding = true);
        final result = await geocode(loc);
        if (mounted) setState(() => _geocoding = false);
        if (result == null) {
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
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() { _loading = false; _geocoding = false; });
    }
  }

  void _searchFor(String term) {
    _itemController.text = term;
    _submit();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'v$appVersion',
                  style: _outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: SupplyMapColors.textSecondary,
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
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: SupplyMapColors.borderSubtle),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x081A1918),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.person_outline,
                          color: SupplyMapColors.textSecondary, size: 20),
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
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: SupplyMapColors.borderSubtle),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x081A1918),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings,
                          color: SupplyMapColors.textSecondary, size: 20),
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
                      color: SupplyMapColors.textBlack,
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
                      color: SupplyMapColors.textSecondary,
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
                      color: SupplyMapColors.textTertiary,
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
                    return _SuggestionPill(
                      label: term,
                      onTap: () => _searchFor(term),
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
                  child: Container(color: Colors.black.withValues(alpha: 0.15)),
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
          ],
        ),
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: SupplyMapColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121A1918),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(Icons.search, color: SupplyMapColors.textTertiary, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: _itemController,
              style: _outfit(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: SupplyMapColors.textBlack,
              ),
              decoration: InputDecoration(
                hintText: "What are you looking for? e.g. 'AA Batteries'",
                hintStyle: _outfit(
                  fontSize: 17,
                  color: SupplyMapColors.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                filled: false,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => GradientBackground.onKeystroke(context),
              enabled: !_loading,
            ),
          ),
          _SearchButton(
            onPressed: _loading ? null : _submit,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  // ── Location toggle ─────────────────────────────────────────────────────
  Widget _buildLocationToggle() {
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
                  side: const BorderSide(color: SupplyMapColors.borderStrong),
                  checkColor: Colors.white,
                  fillColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected)
                          ? SupplyMapColors.accentGreen
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
                  color: SupplyMapColors.textSecondary,
                ),
              ),
            ],
          ),
          if (!_useMyLocation) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: SupplyMapColors.borderSubtle),
              ),
              child: TextField(
                controller: _locationController,
                style: _outfit(
                    fontSize: 14, color: SupplyMapColors.textBlack),
                decoration: InputDecoration(
                  hintText: 'City or address',
                  hintStyle: _outfit(
                      fontSize: 14, color: SupplyMapColors.textTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(Icons.place_outlined,
                      color: SupplyMapColors.textTertiary, size: 18),
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
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: SupplyMapColors.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Locating…',
                      style: _outfit(
                        fontSize: 11,
                        color: SupplyMapColors.textTertiary,
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Row(
        children: [
          const Icon(Icons.near_me, size: 14, color: SupplyMapColors.textTertiary),
          const SizedBox(width: 6),
          Text(
            'Radius: ${_maxDistanceMiles.round()} mi',
            style: _outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: SupplyMapColors.textSecondary,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: SupplyMapColors.accentGreen,
                inactiveTrackColor: SupplyMapColors.borderSubtle,
                thumbColor: SupplyMapColors.accentGreen,
                overlayColor: SupplyMapColors.accentGreen.withValues(alpha: 0.12),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _maxDistanceMiles,
                min: 1,
                max: 25,
                divisions: 24,
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
                  color: hasActive
                      ? SupplyMapColors.accentGreen
                      : SupplyMapColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  hasActive ? 'Filters (active)' : 'Filters',
                  style: _outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: hasActive
                        ? SupplyMapColors.accentGreen
                        : SupplyMapColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _filtersExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: SupplyMapColors.textTertiary,
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
                  // Quality tier
                  Text('Store type',
                      style: _outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SupplyMapColors.textSecondary)),
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
                  // Membership only
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
                            side: const BorderSide(
                                color: SupplyMapColors.borderStrong),
                            checkColor: Colors.white,
                            fillColor:
                                WidgetStateProperty.resolveWith((s) =>
                                    s.contains(WidgetState.selected)
                                        ? SupplyMapColors.accentGreen
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
                              color: SupplyMapColors.textSecondary,
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
                          color: SupplyMapColors.textSecondary)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? SupplyMapColors.accentGreen : SupplyMapColors.glass,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(
            color: selected
                ? SupplyMapColors.accentGreen
                : SupplyMapColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: _outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : SupplyMapColors.textBlack,
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
    return Material(
      color: loading
          ? SupplyMapColors.borderStrong
          : SupplyMapColors.accentGreen,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        hoverColor: const Color(0xFF2D7048),
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
  const _SuggestionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SuggestionPill> createState() => _SuggestionPillState();
}

class _SuggestionPillState extends State<_SuggestionPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? SupplyMapColors.borderSubtle
                : SupplyMapColors.glass,
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: SupplyMapColors.borderSubtle),
          ),
          child: Text(
            widget.label,
            style: _outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SupplyMapColors.textBlack,
            ),
          ),
        ),
      ),
    );
  }
}

