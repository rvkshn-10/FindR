import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/store.dart';
import '../services/geocode_service.dart';
import '../widgets/liquid_glass_background.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'supply_map_shell.dart';

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

// Suggestion pills shown below the search bar (label → search term).
const _kSuggestions = <String, String>{
  'Medical Supplies': 'N95 Masks',
  'Baby Care': 'Baby Formula',
  'Emergency': 'Water',
  'Hardware': 'Batteries',
};

class SearchScreen extends StatefulWidget {
  final bool embedInBackground;
  final void Function(SearchResultParams)? onSearchResult;

  const SearchScreen({
    super.key,
    this.embedInBackground = true,
    this.onSearchResult,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _itemController = TextEditingController();
  final _locationController = TextEditingController();
  bool _useMyLocation = true;
  final double _maxDistanceMiles = 5;
  bool _loading = false;
  final String _qualityTier = 'All';
  final bool _membershipsOnly = false;
  final Set<String> _selectedStoreNames = {};

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
        final loc = _locationController.text.trim();
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
        final result = await geocode(loc);
        if (result == null) {
          setState(() => _loading = false);
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
        qualityTier: _qualityTier == 'All' ? null : _qualityTier,
        membershipsOnly: _membershipsOnly,
        storeNames: _selectedStoreNames.toList(),
      );
      if (!mounted) return;
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
      if (mounted) setState(() => _loading = false);
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
            // Settings gear – pinned top-right
            Positioned(
              top: 16,
              right: 16,
              child: Container(
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
                  icon: Icon(Icons.settings,
                      color: SupplyMapColors.textSecondary, size: 20),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                ),
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
                    'FindR',
                    textAlign: TextAlign.center,
                    style: _outfit(
                      fontSize: isNarrow ? 56 : 96,
                      fontWeight: FontWeight.w800,
                      letterSpacing: isNarrow ? -2 : -4,
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
                        ? 'Locate essentials instantly.\nAI-powered inventory tracking.'
                        : 'Locate essentials instantly. AI-powered inventory\ntracking and convenience ranking.',
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

                // ── Suggestion pills ────────────────────────────────
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: _kSuggestions.entries.map((e) {
                    return _SuggestionPill(
                      label: e.key,
                      onTap: () => _searchFor(e.value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
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
          Padding(
            padding: const EdgeInsets.only(left: 12),
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
              onChanged: (_) {
                GradientBackground.maybeOf(context)?.keystroke();
              },
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
                  side: BorderSide(color: SupplyMapColors.borderStrong),
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
                  prefixIcon: Icon(Icons.place_outlined,
                      color: SupplyMapColors.textTertiary, size: 18),
                  filled: false,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                enabled: !_loading,
              ),
            ),
          ],
        ],
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
