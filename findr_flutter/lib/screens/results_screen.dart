import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/search_models.dart';
import '../services/search_service.dart';
import '../services/distance_util.dart';
import '../providers/settings_provider.dart';
import '../widgets/design_system.dart';

// ---------------------------------------------------------------------------
// Card style enum – matches the HTML design card variants
// ---------------------------------------------------------------------------

enum _CardStyle { bestMatch, goodMatch, convenient, available, substitute }

_CardStyle _styleForIndex(int i, bool isBest) {
  if (isBest) return _CardStyle.bestMatch;
  switch (i) {
    case 0:
      return _CardStyle.bestMatch;
    case 1:
      return _CardStyle.goodMatch;
    case 2:
      return _CardStyle.convenient;
    case 3:
      return _CardStyle.substitute;
    default:
      return i % 2 == 0 ? _CardStyle.available : _CardStyle.substitute;
  }
}

Color _cardBg(_CardStyle s) {
  switch (s) {
    case _CardStyle.bestMatch:
      return SupplyMapColors.red;
    case _CardStyle.goodMatch:
      return SupplyMapColors.purple;
    case _CardStyle.convenient:
      return SupplyMapColors.yellow;
    case _CardStyle.available:
      return SupplyMapColors.accentLightGreen;
    case _CardStyle.substitute:
      return SupplyMapColors.glass;
  }
}

bool _cardDarkText(_CardStyle s) {
  return s == _CardStyle.convenient || s == _CardStyle.available || s == _CardStyle.substitute;
}

String _badgeLabel(_CardStyle s) {
  switch (s) {
    case _CardStyle.bestMatch:
      return 'Best Match';
    case _CardStyle.goodMatch:
      return 'Convenient';
    case _CardStyle.convenient:
      return 'Cheapest';
    case _CardStyle.available:
      return 'Open Now';
    case _CardStyle.substitute:
      return 'Suggestion';
  }
}

// Pin color on map
Color _pinColor(_CardStyle s) {
  switch (s) {
    case _CardStyle.bestMatch:
      return SupplyMapColors.red;
    case _CardStyle.goodMatch:
      return SupplyMapColors.purple;
    case _CardStyle.convenient:
      return SupplyMapColors.yellow;
    case _CardStyle.available:
      return SupplyMapColors.accentGreen;
    case _CardStyle.substitute:
      return SupplyMapColors.borderStrong;
  }
}

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

// ---------------------------------------------------------------------------
// Results screen
// ---------------------------------------------------------------------------

class ResultsScreen extends StatefulWidget {
  final String item;
  final double lat;
  final double lng;
  final double maxDistanceMiles;
  final SearchFilters? filters;
  final bool embedInBackground;
  final VoidCallback? onNewSearch;

  const ResultsScreen({
    super.key,
    required this.item,
    required this.lat,
    required this.lng,
    required this.maxDistanceMiles,
    this.filters,
    this.embedInBackground = true,
    this.onNewSearch,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  SearchResult? _result;
  bool _loading = true;
  String? _error;
  final MapController _mapController = MapController();
  String? _selectedStoreId;
  late String _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final maxKm = milesToKmFn(widget.maxDistanceMiles);

      // Phase 1: Show haversine results immediately (fast).
      final fastResult = await searchFast(
        item: _currentItem,
        lat: widget.lat,
        lng: widget.lng,
        maxDistanceKm: maxKm,
        filters: widget.filters,
      );
      if (!mounted) return;
      setState(() {
        _result = fastResult;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitMapToClosestStores(fastResult.stores);
      });

      // Phase 2: Enrich with road distances in background.
      if (fastResult.stores.isNotEmpty) {
        final enriched = await enrichWithRoadDistances(
          fastResult: fastResult,
          lat: widget.lat,
          lng: widget.lng,
          maxDistanceKm: maxKm,
        );
        if (!mounted) return;
        setState(() {
          _result = enriched;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _reSearch(String newItem) {
    if (newItem.trim().isEmpty) return;
    setState(() {
      _currentItem = newItem.trim();
      _selectedStoreId = null;
    });
    _load();
  }

  void _openDirections(Store store) {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${store.lat},${store.lng}',
    );
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _onSelectStore(Store store) {
    setState(() => _selectedStoreId = store.id);
    const targetZoom = 17.5;
    final currentZoom = _mapController.camera.zoom;
    final nextZoom = currentZoom < targetZoom ? targetZoom : currentZoom;
    _mapController.move(LatLng(store.lat, store.lng), nextZoom);
  }

  void _fitMapToClosestStores(List<Store> stores) {
    if (stores.isEmpty) return;
    final points = <LatLng>[
      LatLng(widget.lat, widget.lng),
      ...stores.take(5).map((s) => LatLng(s.lat, s.lng)),
    ];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Loading
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: SupplyMapColors.accentGreen),
              const SizedBox(height: 16),
              Text(
                'Finding nearby stores…',
                style: _outfit(
                    fontSize: 14, color: SupplyMapColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Error
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: _outfit(
                      color: SupplyMapColors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _pillButton('Back', onTap: () {
                  if (widget.onNewSearch != null) {
                    widget.onNewSearch!();
                  } else {
                    Navigator.of(context).pop();
                  }
                }),
              ],
            ),
          ),
        ),
      );
    }

    final result = _result!;
    final stores = result.stores;
    final searchRadiusMeters = widget.maxDistanceMiles * 1609.34;

    Store? selectedStore;
    if (_selectedStoreId != null) {
      for (final s in stores) {
        if (s.id == _selectedStoreId) {
          selectedStore = s;
          break;
        }
      }
    }

    final isWide = MediaQuery.of(context).size.width >= 500;

    final mapWidget = _buildMapArea(stores, result, searchRadiusMeters, selectedStore, settings);

    // Wide (web / tablet): map left + store list (sidebar) right
    if (isWide) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            Expanded(child: mapWidget),
            _Sidebar(
              query: _currentItem,
              stores: stores,
              result: result,
              settings: settings,
              selectedStoreId: _selectedStoreId,
              onSelectStore: _onSelectStore,
              onDirections: _openDirections,
              onReSearch: _reSearch,
              onNewSearch: () {
                if (widget.onNewSearch != null) {
                  widget.onNewSearch!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );
    }

    // Narrow (phone): map full-screen + draggable bottom sheet
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          mapWidget,
          // Back / new-search button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _MapControlBtn(
              icon: Icons.arrow_back,
              onTap: () {
                if (widget.onNewSearch != null) {
                  widget.onNewSearch!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          // Draggable results sheet
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.10,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: SupplyMapColors.sidebarBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    top: BorderSide(color: SupplyMapColors.borderSubtle),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x121A1918),
                      blurRadius: 24,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SupplyMapColors.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'Results for ',
                                style: _outfit(
                                  fontSize: 16,
                                  color: SupplyMapColors.textSecondary,
                                ),
                                children: [
                                  TextSpan(
                                    text: _currentItem,
                                    style: _outfit(
                                        fontWeight: FontWeight.w700,
                                        color: SupplyMapColors.textBlack),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '${stores.length} found',
                            style: _outfit(
                                fontSize: 13, color: SupplyMapColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // List
                    Expanded(
                      child: stores.isEmpty
                          ? Center(
                              child: Text(
                                'No nearby stores found.',
                                style: _outfit(
                                    color: SupplyMapColors.textTertiary, fontSize: 14),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: stores.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final s = stores[i];
                                final isBest = s.id == result.bestOptionId;
                                final style = _styleForIndex(i, isBest);
                                return _SafeResultCard(
                                  store: s,
                                  style: style,
                                  settings: settings,
                                  isSelected: s.id == _selectedStoreId,
                                  onTap: () => _onSelectStore(s),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Shared map area widget
  // -----------------------------------------------------------------------
  Widget _buildMapArea(
    List<Store> stores,
    SearchResult result,
    double searchRadiusMeters,
    Store? selectedStore,
    SettingsProvider settings,
  ) {
    return Container(
      color: SupplyMapColors.mapBg,
      child: stores.isEmpty
          ? Center(
              child: Text(
                'No nearby stores found.',
                style: _outfit(color: SupplyMapColors.textTertiary, fontSize: 14),
              ),
            )
          : Stack(
              children: [
                CustomPaint(
                  painter: _GridPainter(),
                  size: Size.infinite,
                ),
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(widget.lat, widget.lng),
                    initialZoom: 14,
                    backgroundColor: Colors.transparent,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.findr.findr_flutter',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(widget.lat, widget.lng),
                          radius: searchRadiusMeters,
                          useRadiusInMeter: true,
                          color:
                              SupplyMapColors.blue.withValues(alpha: 0.08),
                          borderColor:
                              SupplyMapColors.blue.withValues(alpha: 0.20),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(widget.lat, widget.lng),
                          width: 24,
                          height: 24,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: SupplyMapColors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                        ...stores.asMap().entries.map((entry) {
                          final i = entry.key;
                          final s = entry.value;
                          final isBest = s.id == result.bestOptionId;
                          final style = _styleForIndex(i, isBest);
                          final isSelected = s.id == _selectedStoreId;
                          return Marker(
                            point: LatLng(s.lat, s.lng),
                            width: isSelected ? 50 : 40,
                            height: isSelected ? 50 : 40,
                            child: _MapPin(
                              index: i + 1,
                              color: _pinColor(style),
                              isBest: isBest,
                              isSelected: isSelected,
                              darkText: _cardDarkText(style),
                              onTap: () => _onSelectStore(s),
                            ),
                          );
                        }),
                        if (selectedStore != null)
                          Marker(
                            point: LatLng(
                                selectedStore.lat, selectedStore.lng),
                            width: 250,
                            height: 130,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _SelectedStorePopup(
                                store: selectedStore,
                                settings: settings,
                                onClose: () => setState(
                                    () => _selectedStoreId = null),
                                onDirections: () =>
                                    _openDirections(selectedStore),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Map controls
                Positioned(
                  bottom: 32,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapControlBtn(
                          icon: Icons.add,
                          onTap: () {
                            final cam = _mapController.camera;
                            _mapController.move(
                                cam.center, cam.zoom + 1);
                          }),
                      const SizedBox(height: 8),
                      _MapControlBtn(
                          icon: Icons.remove,
                          onTap: () {
                            final cam = _mapController.camera;
                            _mapController.move(
                                cam.center, cam.zoom - 1);
                          }),
                      const SizedBox(height: 8),
                      _MapControlBtn(
                          icon: Icons.navigation,
                          onTap: () {
                            _fitMapToClosestStores(stores);
                          }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.query,
    required this.stores,
    required this.result,
    required this.settings,
    required this.selectedStoreId,
    required this.onSelectStore,
    required this.onDirections,
    required this.onReSearch,
    required this.onNewSearch,
  });

  final String query;
  final List<Store> stores;
  final SearchResult result;
  final SettingsProvider settings;
  final String? selectedStoreId;
  final void Function(Store) onSelectStore;
  final void Function(Store) onDirections;
  final void Function(String) onReSearch;
  final VoidCallback onNewSearch;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _searchController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final text = _searchController.text.trim();
    if (text.isNotEmpty) {
      widget.onReSearch(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 440,
          decoration: const BoxDecoration(
            color: SupplyMapColors.sidebarBg,
            border: Border(
              left: BorderSide(
                  color: SupplyMapColors.borderSubtle, width: 1),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Results',
                          style: _outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: SupplyMapColors.textBlack,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            text: 'Searching for ',
                            style: _outfit(
                              fontSize: 14,
                              color: SupplyMapColors.textSecondary,
                            ),
                            children: [
                              TextSpan(
                                text: widget.query,
                                style: _outfit(
                                  fontWeight: FontWeight.w700,
                                  color: SupplyMapColors.textBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: SupplyMapColors.glass,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: SupplyMapColors.textSecondary, size: 16),
                      onPressed: widget.onNewSearch,
                      tooltip: '',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Search bar
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: SupplyMapColors.bodyBg,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(color: SupplyMapColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.search,
                          size: 16, color: SupplyMapColors.textTertiary),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: _outfit(
                            fontSize: 14, color: SupplyMapColors.textBlack),
                        decoration: InputDecoration(
                          hintText: 'Search for something else…',
                          hintStyle: _outfit(
                              fontSize: 14, color: SupplyMapColors.textTertiary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          filled: false,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submitSearch(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _submitSearch,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: SupplyMapColors.accentGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_forward,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Results list
              Expanded(
                child: widget.stores.isEmpty
                    ? Center(
                        child: Text(
                          'No nearby stores found.',
                          style: _outfit(
                              color: SupplyMapColors.textTertiary, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.stores.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        padding: const EdgeInsets.only(right: 8),
                        itemBuilder: (context, i) {
                          final s = widget.stores[i];
                          final isBest =
                              s.id == widget.result.bestOptionId;
                          final style =
                              _styleForIndex(i, isBest);
                          return _SafeResultCard(
                            store: s,
                            style: style,
                            settings: widget.settings,
                            isSelected:
                                s.id == widget.selectedStoreId,
                            onTap: () => widget.onSelectStore(s),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Wrapper that forces no text shadow for result cards (avoids blurRadius assertion).
// ---------------------------------------------------------------------------

class _SafeResultCard extends StatelessWidget {
  const _SafeResultCard({
    required this.store,
    required this.style,
    required this.settings,
    required this.isSelected,
    required this.onTap,
  });

  final Store store;
  final _CardStyle style;
  final SettingsProvider settings;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final noShadow = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(shadows: const <Shadow>[]);
    return DefaultTextStyle(
      style: noShadow,
      child: _ResultCard(
        store: store,
        style: style,
        settings: settings,
        isSelected: isSelected,
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result card (colored)
// ---------------------------------------------------------------------------

class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.store,
    required this.style,
    required this.settings,
    required this.isSelected,
    required this.onTap,
  });

  final Store store;
  final _CardStyle style;
  final SettingsProvider settings;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _cardBg(widget.style);
    final dark = _cardDarkText(widget.style);
    final fg = dark ? SupplyMapColors.textBlack : Colors.white;
    final isGlass = widget.style == _CardStyle.substitute;

    final noShadowStyle = Theme.of(context)
        .textTheme
        .bodyLarge!
        .copyWith(shadows: const <Shadow>[]);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: DefaultTextStyle(
          style: noShadowStyle,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(
              _hovered ? 1.02 : 1.0, _hovered ? 1.02 : 1.0, 1.0),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: isGlass
                ? Border.all(color: SupplyMapColors.glassBorder)
                : (widget.isSelected
                    ? Border.all(color: Colors.white, width: 2)
                    : null),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(minHeight: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _badgeLabel(widget.style),
                      style: _outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: dark ? SupplyMapColors.textBlack : Colors.white,
                      ),
                    ),
                  ),
                  if (widget.style == _CardStyle.bestMatch)
                    Text(
                      '98%',
                      style: _outfit(
                          fontSize: 16, fontWeight: FontWeight.w600, color: fg),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                widget.store.name,
                style: _outfit(
                  fontSize: isGlass ? 16 : 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: -0.5,
                  color: fg.withValues(alpha: isGlass ? 0.9 : 1.0),
                ),
              ),
              const SizedBox(height: 12),
              // Meta
              Row(
                children: [
                  Text(
                    formatDistance(widget.store.distanceKm,
                        useKm: widget.settings.useKm),
                    style: _outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: fg.withValues(alpha: 0.85),
                    ),
                  ),
                  _dot(fg),
                  if (widget.store.durationMinutes != null) ...[
                    Text(
                      '~${widget.store.durationMinutes} min',
                      style: _outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                    _dot(fg),
                  ],
                  Text(
                    widget.store.address.isEmpty
                        ? 'In Stock'
                        : widget.store.address
                            .split(',')
                            .first
                            .trim(),
                    style: _outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: fg.withValues(alpha: 0.85),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _dot(Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map pin
// ---------------------------------------------------------------------------

class _MapPin extends StatefulWidget {
  const _MapPin({
    required this.index,
    required this.color,
    required this.isBest,
    required this.isSelected,
    required this.darkText,
    required this.onTap,
  });

  final int index;
  final Color color;
  final bool isBest;
  final bool isSelected;
  final bool darkText;
  final VoidCallback onTap;

  @override
  State<_MapPin> createState() => _MapPinState();
}

class _MapPinState extends State<_MapPin> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.isBest ? 50.0 : 40.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          transform: Matrix4.diagonal3Values(
              _hovered ? 1.1 : 1.0, _hovered ? 1.1 : 1.0, 1.0),
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${widget.index}',
            style: _outfit(
              fontWeight: FontWeight.w800,
              fontSize: widget.isBest ? 16 : 13,
              color: widget.darkText
                  ? SupplyMapColors.textBlack
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map control button
// ---------------------------------------------------------------------------

class _MapControlBtn extends StatefulWidget {
  const _MapControlBtn({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_MapControlBtn> createState() => _MapControlBtnState();
}

class _MapControlBtnState extends State<_MapControlBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _hovered
                ? SupplyMapColors.borderSubtle
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: SupplyMapColors.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x081A1918),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon,
              color: SupplyMapColors.textBlack, size: 18),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected store popup
// ---------------------------------------------------------------------------

class _SelectedStorePopup extends StatelessWidget {
  const _SelectedStorePopup({
    required this.store,
    required this.settings,
    required this.onClose,
    required this.onDirections,
  });

  final Store store;
  final SettingsProvider settings;
  final VoidCallback onClose;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
              decoration: BoxDecoration(
                color: SupplyMapColors.sidebarBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SupplyMapColors.borderSubtle),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x151A1918),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store,
                          size: 16, color: SupplyMapColors.accentGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: SupplyMapColors.textBlack,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: const Icon(Icons.close,
                            size: 14, color: SupplyMapColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDistance(store.distanceKm, useKm: settings.useKm)} away'
                    '${store.durationMinutes != null ? ' · ~${store.durationMinutes} min' : ''}',
                    style: _outfit(
                        fontSize: 12, color: SupplyMapColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onDirections,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: SupplyMapColors.accentGreen,
                        borderRadius:
                            BorderRadius.circular(kRadiusPill),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Directions',
                            style: _outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        ),
        CustomPaint(
          size: const Size(18, 8),
          painter: _PopupArrowPainter(color: SupplyMapColors.sidebarBg),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grid painter for map background
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SupplyMapColors.borderSubtle.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Popup arrow painter
// ---------------------------------------------------------------------------

class _PopupArrowPainter extends CustomPainter {
  _PopupArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PopupArrowPainter old) =>
      old.color != color;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _pillButton(String label, {required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: SupplyMapColors.glass,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: SupplyMapColors.borderSubtle),
      ),
      child: Text(
        label,
        style: _outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: SupplyMapColors.textBlack,
        ),
      ),
    ),
  );
}
