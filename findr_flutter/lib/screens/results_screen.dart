import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/search_models.dart';
import '../services/search_service.dart';
import '../services/distance_util.dart';
import '../services/ai_service.dart';
import '../services/price_service.dart';
import '../services/kroger_service.dart';
import '../services/firestore_service.dart' as db;
import '../providers/settings_provider.dart';
import '../widgets/design_system.dart';
import '../widgets/settings_panel.dart';
import '../config.dart';
import '../version.dart';

// ---------------------------------------------------------------------------
// Card style enum – matches the HTML design card variants
// ---------------------------------------------------------------------------

enum _CardStyle { closest, fastest, nearby, standard }

/// Assign a data-driven style based on actual store attributes.
_CardStyle _styleForStore(int index, Store store, List<Store> allStores) {
  if (index == 0) return _CardStyle.closest;
  // "Fastest" = shortest drive time among stores with duration data
  if (store.durationMinutes != null) {
    final withDuration = allStores.where((s) => s.durationMinutes != null);
    if (withDuration.isEmpty) return _CardStyle.standard;
    final fastestDur = withDuration
        .fold<int>(2147483647, (min, s) => s.durationMinutes! < min ? s.durationMinutes! : min);
    if (store.durationMinutes == fastestDur && index != 0) {
      return _CardStyle.fastest;
    }
  }
  if (store.distanceKm <= 1.6) return _CardStyle.nearby; // ~1 mile
  return _CardStyle.standard;
}

Color _cardBg(_CardStyle s) {
  switch (s) {
    case _CardStyle.closest:
      return SupplyMapColors.red;
    case _CardStyle.fastest:
      return SupplyMapColors.purple;
    case _CardStyle.nearby:
      return SupplyMapColors.accentLightGreen;
    case _CardStyle.standard:
      return SupplyMapColors.glass;
  }
}

bool _cardDarkText(_CardStyle s) {
  return s == _CardStyle.nearby || s == _CardStyle.standard;
}

String _badgeLabel(_CardStyle s) {
  switch (s) {
    case _CardStyle.closest:
      return 'Closest';
    case _CardStyle.fastest:
      return 'Fastest';
    case _CardStyle.nearby:
      return 'Nearby';
    case _CardStyle.standard:
      return 'Store';
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
// Safe URL launcher
// ---------------------------------------------------------------------------

Future<void> _safeLaunch(String url) async {
  try {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Silently ignore unsupported schemes or parse errors.
  }
}

/// Format review count with K suffix for large numbers.
String _formatReviewCount(int count) {
  if (count >= 1000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K reviews';
  }
  return '$count reviews';
}

/// Sort mode for search results.
enum SortMode { distance, priceLow, rating }

/// Returns a human-friendly label for the store's OSM type, or null if unknown.
String? _storeTypeLabel(Store store) {
  final raw = store.shopType ?? store.amenityType;
  if (raw == null || raw.isEmpty) return null;
  // Capitalise and replace underscores with spaces.
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
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
  final VoidCallback? onNewSearch;

  const ResultsScreen({
    super.key,
    required this.item,
    required this.lat,
    required this.lng,
    required this.maxDistanceMiles,
    this.filters,
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
  bool _settingsOpen = false;
  bool _enriching = false;
  bool _aiLoading = false;
  AiResultSummary? _aiSummary;
  PriceData? _priceData;
  bool _pricesLoading = false;
  SortMode _sortMode = SortMode.distance;
  int _loadGeneration = 0;

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
    final gen = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final maxKm = milesToKmFn(widget.maxDistanceMiles);
      print('[Wayvio] _load: item="$_currentItem", lat=${widget.lat}, lng=${widget.lng}, maxKm=$maxKm');

      // Phase 1: Show haversine results immediately (fast).
      final fastResult = await searchFast(
        item: _currentItem,
        lat: widget.lat,
        lng: widget.lng,
        maxDistanceKm: maxKm,
        filters: widget.filters,
      );
      print('[Wayvio] searchFast returned ${fastResult.stores.length} stores');
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _result = fastResult;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitMapToClosestStores(fastResult.stores);
      });

      // Phase 2 + 3 + 4 run in parallel: road distances, AI summary, prices.
      if (fastResult.stores.isNotEmpty) {
        if (mounted) {
          setState(() {
            _enriching = true;
            _aiLoading = true;
            _aiSummary = null;
            _pricesLoading = true;
            _priceData = null;
          });
        }

        // Fire all three in parallel.
        final enrichFuture = enrichWithRoadDistances(
          fastResult: fastResult,
          lat: widget.lat,
          lng: widget.lng,
          maxDistanceKm: maxKm,
        );

        final aiFuture = generateResultSummary(
          query: _currentItem,
          storeData: fastResult.stores.take(6).map((s) => {
            'name': s.name,
            'distanceKm': s.distanceKm,
            'durationMinutes': s.durationMinutes,
            'address': s.address,
            'openingHours': s.openingHours,
            'brand': s.brand,
            'rating': s.rating,
            'reviewCount': s.reviewCount,
            'priceLevel': s.priceLevel,
            'shopType': s.shopType,
            'serviceOptions': s.serviceOptions,
          }).toList(),
        );

        final priceFuture = fetchProductPrices(
          _currentItem,
          lat: widget.lat,
          lng: widget.lng,
        );

        // Also fetch Kroger in-store prices for any Kroger stores.
        final krogerStores = fastResult.stores
            .where((s) => s.id.startsWith('kroger/'))
            .toList();
        final krogerPriceFutures = krogerStores.map((s) {
          final locId = s.id.replaceFirst('kroger/', '');
          return fetchKrogerProducts(query: _currentItem, locationId: locId)
              .catchError((_) => null);
        }).toList();

        // Wait for all.
        final results = await Future.wait([
          enrichFuture,
          aiFuture,
          priceFuture,
          Future.wait(krogerPriceFutures),
        ]);

        if (!mounted || gen != _loadGeneration) return;

        final enriched = results[0] as SearchResult;
        final aiSummary = results[1] as AiResultSummary?;
        final prices = results[2] as PriceData?;
        final krogerPrices = results[3] as List<KrogerPriceData?>;

        // Build a map of Kroger locationId → price data.
        final krogerPriceMap = <String, KrogerPriceData>{};
        for (final kp in krogerPrices) {
          if (kp != null) krogerPriceMap[kp.locationId] = kp;
        }

        // Merge price data into store results (Google Shopping + Kroger).
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final storesWithPrices = _applyPrices(enriched.stores, prices, krogerPriceMap, settings);

        setState(() {
          _result = enriched.copyWith(stores: storesWithPrices);
          _enriching = false;
          _aiSummary = aiSummary;
          _aiLoading = false;
          _priceData = prices;
          _pricesLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _enriching = false;
      });
    }
  }

  void _reSearch(String newItem) {
    if (newItem.trim().isEmpty) return;
    setState(() {
      _currentItem = newItem.trim();
      _selectedStoreId = null;
      _aiSummary = null;
      _aiLoading = false;
      _priceData = null;
      _pricesLoading = false;
    });
    _load();
  }

  /// Merge Google Shopping prices into the store list.
  List<Store> _applyPrices(
    List<Store> stores,
    PriceData? prices,
    Map<String, KrogerPriceData>? krogerPrices,
    SettingsProvider settings,
  ) {
    final currency = settings.currency;

    return stores.map((store) {
      // --- Kroger in-store price (most accurate) ---
      if (store.id.startsWith('kroger/') && krogerPrices != null) {
        final locId = store.id.replaceFirst('kroger/', '');
        final kp = krogerPrices[locId];
        if (kp != null && kp.lowPrice != null) {
          return store.copyWith(
            price: kp.lowPrice,
            priceLabel: formatPrice(kp.lowPrice!, currency),
            priceIsAvg: false,
          );
        }
      }

      // --- Google Shopping price match ---
      if (prices != null && prices.prices.isNotEmpty) {
        final matched = matchPriceToStore(store, prices);
        if (matched != null) {
          return store.copyWith(
            price: matched.price,
            priceLabel: formatPrice(matched.price, currency),
            priceIsAvg: false,
          );
        }
        // No direct match — show the average price across all results.
        if (prices.avgPrice > 0) {
          return store.copyWith(
            price: prices.avgPrice,
            priceLabel: 'avg ~${formatPrice(prices.avgPrice, currency)}',
            priceIsAvg: true,
          );
        }
      }

      return store;
    }).toList();
  }

  void _openDirections(Store store) {
    _safeLaunch(
      'https://www.google.com/maps/dir/?api=1&destination=${store.lat},${store.lng}',
    );
  }

  void _onSelectStore(Store store) {
    setState(() => _selectedStoreId = store.id);
    _mapController.move(LatLng(store.lat, store.lng), kMapSelectZoom);
  }

  void _fitMapToClosestStores(List<Store> stores) {
    if (stores.isEmpty) return;
    final points = <LatLng>[
      LatLng(widget.lat, widget.lng),
      ...stores.take(5).map((s) => LatLng(s.lat, s.lng)),
    ];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  // -----------------------------------------------------------------------
  // Sorting
  // -----------------------------------------------------------------------

  List<Store> _sortedStores(List<Store> stores) {
    final sorted = List<Store>.from(stores);
    switch (_sortMode) {
      case SortMode.distance:
        sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case SortMode.priceLow:
        sorted.sort((a, b) {
          if (a.price == null && b.price == null) return 0;
          if (a.price == null) return 1;
          if (b.price == null) return -1;
          return a.price!.compareTo(b.price!);
        });
        break;
      case SortMode.rating:
        sorted.sort((a, b) {
          if (a.rating == null && b.rating == null) return 0;
          if (a.rating == null) return 1;
          if (b.rating == null) return -1;
          return b.rating!.compareTo(a.rating!); // higher first
        });
        break;
    }
    return sorted;
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Loading — shimmer skeleton cards
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                    color: SupplyMapColors.accentGreen),
                const SizedBox(height: 20),
                Text(
                  'Finding nearby stores…',
                  style: _outfit(
                      fontSize: 14, color: SupplyMapColors.textSecondary),
                ),
                const SizedBox(height: 28),
                ...List.generate(
                    3,
                    (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ShimmerCard(delay: i * 200),
                        )),
              ],
            ),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pillButton('Back', onTap: () {
                      if (widget.onNewSearch != null) {
                        widget.onNewSearch!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    }),
                    const SizedBox(width: 12),
                    _pillButton('Try again', onTap: _load),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text('Loading…', style: _outfit(color: SupplyMapColors.textSecondary)),
        ),
      );
    }
    final stores = _sortedStores(result.stores);
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
        body: _wrapWithSettings(
          context: context,
          child: Row(
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
                enriching: _enriching,
                aiSummary: _aiSummary,
                aiLoading: _aiLoading,
                priceData: _priceData,
                pricesLoading: _pricesLoading,
                sortMode: _sortMode,
                onSortChanged: (mode) => setState(() => _sortMode = mode),
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
        ),
      );
    }

    // Narrow (phone): map full-screen + draggable bottom sheet
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _wrapWithSettings(
        context: context,
        child: Stack(
          children: [
            mapWidget,
            // Back / new-search button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: _MapControlBtn(
                icon: Icons.arrow_back,
                tooltip: 'Back',
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
            snap: true,
            snapSizes: const [0.10, 0.35, 0.85],
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
                clipBehavior: Clip.antiAlias,
                child: stores.isEmpty
                    ? CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildSheetHeader(stores),
                          ),
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(),
                          ),
                        ],
                      )
                    : CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildSheetHeader(stores),
                          ),
                          // AI Insight in the bottom sheet
                          if (_aiLoading || _aiSummary != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: (_aiLoading || _aiSummary == null)
                                    ? const _AiInsightCard.loading()
                                    : _AiInsightCard(summary: _aiSummary!),
                              ),
                            ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                24 + MediaQuery.of(context).padding.bottom),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final s = stores[i];
                                  final style = _styleForStore(i, s, stores);
                                  return Padding(
                                    padding: EdgeInsets.only(
                                        bottom: i < stores.length - 1 ? 12 : 0),
                                    child: _StaggeredFadeIn(
                                      index: i,
                                      child: _SafeResultCard(
                                        key: ValueKey(s.id),
                                        store: s,
                                        style: style,
                                        settings: settings,
                                        isSelected: s.id == _selectedStoreId,
                                        onTap: () => _onSelectStore(s),
                                        searchItem: _currentItem,
                                      ),
                                    ),
                                  );
                                },
                                childCount: stores.length,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Settings overlay wrapper
  // -----------------------------------------------------------------------
  Widget _buildSheetHeader(List<Store> stores) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        // Header row
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
        if (_enriching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: SupplyMapColors.accentGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Refining distances…',
                  style: _outfit(
                      fontSize: 11, color: SupplyMapColors.textTertiary),
                ),
              ],
            ),
          ),
        // Price range banner (mobile)
        if (_pricesLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: SupplyMapColors.accentGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Fetching prices…',
                    style: _outfit(
                        fontSize: 11, color: SupplyMapColors.textTertiary)),
              ],
            ),
          )
        else if (_priceData != null && _priceData!.prices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SupplyMapColors.accentGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SupplyMapColors.accentGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sell_outlined,
                      size: 14, color: SupplyMapColors.accentGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Builder(builder: (ctx) {
                      final currency = Provider.of<SettingsProvider>(ctx, listen: false).currency;
                      return Text(
                        '${formatPrice(_priceData!.lowPrice, currency)}'
                        ' – ${formatPrice(_priceData!.highPrice, currency)}'
                        '  avg ${formatPrice(_priceData!.avgPrice, currency)}',
                        style: _outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SupplyMapColors.textBlack,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        // Sort chips (mobile)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                'Sort',
                style: _outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: SupplyMapColors.textTertiary,
                ),
              ),
              const SizedBox(width: 6),
              _SortChip(
                label: 'Distance',
                icon: Icons.near_me_outlined,
                selected: _sortMode == SortMode.distance,
                onTap: () => setState(() => _sortMode = SortMode.distance),
              ),
              const SizedBox(width: 4),
              _SortChip(
                label: 'Price',
                icon: Icons.attach_money,
                selected: _sortMode == SortMode.priceLow,
                onTap: () => setState(() => _sortMode = SortMode.priceLow),
              ),
              const SizedBox(width: 4),
              _SortChip(
                label: 'Rating',
                icon: Icons.star_outline_rounded,
                selected: _sortMode == SortMode.rating,
                onTap: () => setState(() => _sortMode = SortMode.rating),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _wrapWithSettings({
    required BuildContext context,
    required Widget child,
  }) {
    final screenW = MediaQuery.of(context).size.width;
    final sidebarW = screenW < 400 ? screenW.toDouble() : 320.0;
    return Stack(
      children: [
        child,
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
        // Settings gear – pinned top-left (next to back button on narrow)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 68,
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
              icon: const Icon(Icons.settings,
                  color: SupplyMapColors.textSecondary, size: 20),
              tooltip: 'Settings',
              onPressed: () =>
                  setState(() => _settingsOpen = !_settingsOpen),
            ),
          ),
        ),
        // Dim background when open
        if (_settingsOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _settingsOpen = false),
              child: Container(
                  color: Colors.black.withValues(alpha: 0.15)),
            ),
          ),
        // Sliding settings panel from the right
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _settingsOpen ? 0 : -sidebarW,
          width: sidebarW,
          child: SettingsPanel(
            onClose: () => setState(() => _settingsOpen = false),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Build flutter_map markers
  // -----------------------------------------------------------------------
  List<Marker> _buildMarkers(List<Store> stores) {
    final markers = <Marker>[];

    // User location marker
    markers.add(
      Marker(
        point: LatLng(widget.lat, widget.lng),
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: SupplyMapColors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: SupplyMapColors.blue.withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );

    // Store markers
    for (final entry in stores.asMap().entries) {
      final i = entry.key;
      final s = entry.value;
      final style = _styleForStore(i, s, stores);
      final isSelected = s.id == _selectedStoreId;

      Color pinColor;
      switch (style) {
        case _CardStyle.closest:
          pinColor = SupplyMapColors.red;
        case _CardStyle.fastest:
          pinColor = SupplyMapColors.purple;
        case _CardStyle.nearby:
          pinColor = SupplyMapColors.accentGreen;
        case _CardStyle.standard:
          pinColor = SupplyMapColors.accentWarm;
      }

      markers.add(
        Marker(
          point: LatLng(s.lat, s.lng),
          width: isSelected ? 40 : 32,
          height: isSelected ? 40 : 32,
          child: GestureDetector(
            onTap: () => _onSelectStore(s),
            child: Container(
              decoration: BoxDecoration(
                color: pinColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white70,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: pinColor.withValues(alpha: 0.5),
                    blurRadius: isSelected ? 12 : 6,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
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
          ? const Center(child: _EmptyState())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(widget.lat, widget.lng),
                    initialZoom: kMapInitialZoom,
                    onTap: (_, __) => setState(() => _selectedStoreId = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: kTileUrl,
                      userAgentPackageName: kTileUserAgent,
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(widget.lat, widget.lng),
                          radius: searchRadiusMeters,
                          useRadiusInMeter: true,
                          color: SupplyMapColors.blue.withValues(alpha: 0.08),
                          borderColor: SupplyMapColors.blue.withValues(alpha: 0.25),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(markers: _buildMarkers(stores)),
                  ],
                ),
                // Selected store popup overlay
                if (selectedStore != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 80,
                    child: _SelectedStorePopup(
                      store: selectedStore,
                      settings: settings,
                      onClose: () => setState(() => _selectedStoreId = null),
                      onDirections: () => _openDirections(selectedStore),
                    ),
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
                          tooltip: 'Zoom in',
                          onTap: () {
                            final cam = _mapController.camera;
                            _mapController.move(cam.center, cam.zoom + 1);
                          }),
                      const SizedBox(height: 8),
                      _MapControlBtn(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          onTap: () {
                            final cam = _mapController.camera;
                            _mapController.move(cam.center, cam.zoom - 1);
                          }),
                      const SizedBox(height: 8),
                      _MapControlBtn(
                          icon: Icons.my_location,
                          tooltip: 'Fit to results',
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
    this.enriching = false,
    this.aiSummary,
    this.aiLoading = false,
    this.priceData,
    this.pricesLoading = false,
    required this.sortMode,
    required this.onSortChanged,
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
  final bool enriching;
  final AiResultSummary? aiSummary;
  final bool aiLoading;
  final PriceData? priceData;
  final bool pricesLoading;
  final SortMode sortMode;
  final ValueChanged<SortMode> onSortChanged;

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
                      tooltip: 'New search',
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
              if (widget.enriching)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: SupplyMapColors.accentGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Refining distances…',
                        style: _outfit(
                            fontSize: 11,
                            color: SupplyMapColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // AI Insight card
              if (widget.aiLoading)
                const _AiInsightCard.loading()
              else if (widget.aiSummary != null)
                _AiInsightCard(summary: widget.aiSummary!),
              // Price range banner (from Google Shopping)
              if (widget.pricesLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: SupplyMapColors.accentGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fetching prices…',
                        style: _outfit(
                            fontSize: 11,
                            color: SupplyMapColors.textTertiary),
                      ),
                    ],
                  ),
                )
              else if (widget.priceData != null &&
                  widget.priceData!.prices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: SupplyMapColors.accentGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            SupplyMapColors.accentGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sell_outlined,
                            size: 16, color: SupplyMapColors.accentGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Price range: ${formatPrice(widget.priceData!.lowPrice, widget.settings.currency)}'
                            ' – ${formatPrice(widget.priceData!.highPrice, widget.settings.currency)}'
                            '  (avg ${formatPrice(widget.priceData!.avgPrice, widget.settings.currency)})',
                            style: _outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SupplyMapColors.textBlack,
                            ),
                          ),
                        ),
                        const Tooltip(
                          message: 'Prices from Google Shopping (online)',
                          child: Icon(Icons.info_outline,
                              size: 14,
                              color: SupplyMapColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              // Sort chips
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      'Sort by',
                      style: _outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: SupplyMapColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Distance',
                      icon: Icons.near_me_outlined,
                      selected: widget.sortMode == SortMode.distance,
                      onTap: () => widget.onSortChanged(SortMode.distance),
                    ),
                    const SizedBox(width: 6),
                    _SortChip(
                      label: 'Price',
                      icon: Icons.attach_money,
                      selected: widget.sortMode == SortMode.priceLow,
                      onTap: () => widget.onSortChanged(SortMode.priceLow),
                    ),
                    const SizedBox(width: 6),
                    _SortChip(
                      label: 'Rating',
                      icon: Icons.star_outline_rounded,
                      selected: widget.sortMode == SortMode.rating,
                      onTap: () => widget.onSortChanged(SortMode.rating),
                    ),
                  ],
                ),
              ),
              // Results list
              Expanded(
                child: widget.stores.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        itemCount: widget.stores.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        padding: const EdgeInsets.only(right: 8),
                        itemBuilder: (context, i) {
                          final s = widget.stores[i];
                          final style =
                              _styleForStore(i, s, widget.stores);
                          return _StaggeredFadeIn(
                            index: i,
                            child: _SafeResultCard(
                              key: ValueKey(s.id),
                              store: s,
                              style: style,
                              settings: widget.settings,
                              isSelected:
                                  s.id == widget.selectedStoreId,
                              onTap: () => widget.onSelectStore(s),
                              searchItem: widget.query,
                            ),
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
    super.key,
    required this.store,
    required this.style,
    required this.settings,
    required this.isSelected,
    required this.onTap,
    this.searchItem = '',
  });

  final Store store;
  final _CardStyle style;
  final SettingsProvider settings;
  final bool isSelected;
  final VoidCallback onTap;
  final String searchItem;

  @override
  Widget build(BuildContext context) {
    final noShadow = (Theme.of(context).textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(shadows: const <Shadow>[]);
    return DefaultTextStyle(
      style: noShadow,
      child: _ResultCard(
        store: store,
        style: style,
        settings: settings,
        isSelected: isSelected,
        onTap: onTap,
        searchItem: searchItem,
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
    this.searchItem = '',
  });

  final Store store;
  final _CardStyle style;
  final SettingsProvider settings;
  final bool isSelected;
  final VoidCallback onTap;
  final String searchItem;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _hovered = false;
  bool _isFavorite = false;
  bool _favLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  @override
  void didUpdateWidget(covariant _ResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.id != widget.store.id) _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final fav = await db.isFavorite(widget.store.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    if (_favLoading) return;
    setState(() => _favLoading = true);

    if (_isFavorite) {
      await db.removeFavorite(widget.store.id);
    } else {
      await db.addFavorite(
        storeId: widget.store.id,
        storeName: widget.store.name,
        address: widget.store.address,
        lat: widget.store.lat,
        lng: widget.store.lng,
        searchItem: widget.searchItem,
        phone: widget.store.phone,
        website: widget.store.website,
        openingHours: widget.store.openingHours,
        brand: widget.store.brand,
        shopType: widget.store.shopType,
        rating: widget.store.rating,
        reviewCount: widget.store.reviewCount,
        priceLevel: widget.store.priceLevel,
        thumbnail: widget.store.thumbnail,
      );
    }

    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
        _favLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _cardBg(widget.style);
    final dark = _cardDarkText(widget.style);
    final fg = dark ? SupplyMapColors.textBlack : Colors.white;
    final isGlass = widget.style == _CardStyle.standard;

    final noShadowStyle = (Theme.of(context).textTheme.bodyLarge ??
            const TextStyle())
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
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Thumbnail image (if available)
              if (widget.store.thumbnail != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(kRadiusLg),
                  ),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Image.network(
                      widget.store.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.store.durationMinutes != null)
                        Text(
                          '~${widget.store.durationMinutes} min',
                          style: _outfit(
                              fontSize: 13, fontWeight: FontWeight.w600, color: fg),
                        ),
                      const SizedBox(width: 8),
                      // Favorite button
                      GestureDetector(
                        onTap: _toggleFavorite,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _favLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: fg.withValues(alpha: 0.5),
                                  ),
                                )
                              : Icon(
                                  _isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  key: ValueKey(_isFavorite),
                                  size: 20,
                                  color: _isFavorite
                                      ? SupplyMapColors.red
                                      : fg.withValues(alpha: 0.6),
                                ),
                        ),
                      ),
                    ],
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
              // Rating row
              if (widget.store.rating != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      final starVal = widget.store.rating!;
                      IconData icon;
                      if (i < starVal.floor()) {
                        icon = Icons.star_rounded;
                      } else if (i < starVal.ceil() && starVal % 1 >= 0.3) {
                        icon = Icons.star_half_rounded;
                      } else {
                        icon = Icons.star_outline_rounded;
                      }
                      return Icon(icon,
                          size: 16,
                          color: dark
                              ? const Color(0xFFFFD54F)
                              : Colors.white.withValues(alpha: 0.9));
                    }),
                    const SizedBox(width: 4),
                    Text(
                      widget.store.rating!.toStringAsFixed(1),
                      style: _outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                    if (widget.store.reviewCount != null) ...[
                      Text(
                        ' (${_formatReviewCount(widget.store.reviewCount!)})',
                        style: _outfit(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    if (widget.store.priceLevel != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        widget.store.priceLevel!,
                        style: _outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              // Price + store type badges
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Price badge (from Google Shopping)
                  if (widget.store.priceLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dark
                            ? SupplyMapColors.accentGreen.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.store.priceLabel!,
                        style: _outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? SupplyMapColors.accentGreen
                              : Colors.white,
                        ),
                      ),
                    ),
                  // Store type badge
                  if (_storeTypeLabel(widget.store) != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _storeTypeLabel(widget.store)!,
                        style: _outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Meta row
              Wrap(
                spacing: 0,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  if (widget.store.durationMinutes != null) ...[
                    _dot(fg),
                    Text(
                      '~${widget.store.durationMinutes} min',
                      style: _outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  if (widget.store.address.isNotEmpty) ...[
                    _dot(fg),
                    Text(
                      widget.store.address.split(',').first.trim(),
                      style: _outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fg.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              // Extra info row (phone, website, hours)
              if (widget.store.phone != null ||
                  widget.store.website != null ||
                  widget.store.openingHours != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (widget.store.openingHours != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule,
                              size: 12,
                              color: fg.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.store.openingHours!,
                              style: _outfit(
                                fontSize: 11,
                                color: fg.withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (widget.store.phone != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _safeLaunch('tel:${widget.store.phone}'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone,
                                size: 12,
                                color: fg.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              widget.store.phone!,
                              style: _outfit(
                                fontSize: 11,
                                color: fg.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.store.website != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _safeLaunch(widget.store.website!),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language,
                                size: 12,
                                color: fg.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Website',
                              style: _outfit(
                                fontSize: 11,
                                color: fg.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              // Service options (e.g. "In-store shopping", "Delivery")
              if (widget.store.serviceOptions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.store.serviceOptions.map((opt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        opt,
                        style: _outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: fg.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
                  ], // inner Column children
                ), // inner Column
              ), // Padding
            ], // outer Column children
          ), // outer Column
        ), // AnimatedContainer
        ), // DefaultTextStyle
      ), // GestureDetector
    ); // MouseRegion
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
// Map control button
// ---------------------------------------------------------------------------

class _MapControlBtn extends StatefulWidget {
  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

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
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _hovered
                  ? SupplyMapColors.borderSubtle
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
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
                color: SupplyMapColors.textBlack, size: 20),
          ),
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
    return Container(
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
        mainAxisSize: MainAxisSize.min,
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
            '${store.priceLabel != null ? '${store.priceLabel} · ' : ''}'
            '${formatDistance(store.distanceKm, useKm: settings.useKm)} away'
            '${store.durationMinutes != null ? ' · ~${store.durationMinutes} min' : ''}'
            '${_storeTypeLabel(store) != null ? ' · ${_storeTypeLabel(store)}' : ''}',
            style: _outfit(
                fontSize: 12, color: SupplyMapColors.textSecondary),
          ),
          if (store.rating != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    size: 13, color: Color(0xFFFFD54F)),
                const SizedBox(width: 2),
                Text(
                  '${store.rating!.toStringAsFixed(1)}'
                  '${store.reviewCount != null ? ' (${_formatReviewCount(store.reviewCount!)})' : ''}',
                  style: _outfit(
                      fontSize: 11, color: SupplyMapColors.textTertiary),
                ),
              ],
            ),
          ],
          if (store.openingHours != null) ...[
            const SizedBox(height: 2),
            Text(
              store.openingHours!,
              style: _outfit(
                  fontSize: 11, color: SupplyMapColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
    );
  }
}

// ---------------------------------------------------------------------------
// AI Insight card
// ---------------------------------------------------------------------------

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.summary}) : _loading = false;
  const _AiInsightCard.loading()
      : summary = null,
        _loading = true;

  final AiResultSummary? summary;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F7F3), Color(0xFFEDF5F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: SupplyMapColors.accentGreen.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: _loading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: SupplyMapColors.accentGreen,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'AI is analyzing your results…',
          style: _outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SupplyMapColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final s = summary!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: SupplyMapColors.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 14, color: SupplyMapColors.accentGreen),
            ),
            const SizedBox(width: 8),
            Text(
              'AI Recommendation',
              style: _outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: SupplyMapColors.accentGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Recommendation
        Text(
          s.recommendation,
          style: _outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SupplyMapColors.textBlack,
            height: 1.4,
          ),
        ),
        if (s.reasoning.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            s.reasoning,
            style: _outfit(
              fontSize: 12,
              color: SupplyMapColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        if (s.tips.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...s.tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.lightbulb_outline,
                          size: 13, color: SupplyMapColors.accentGreen),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tip,
                        style: _outfit(
                          fontSize: 12,
                          color: SupplyMapColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer skeleton card (loading placeholder)
// ---------------------------------------------------------------------------

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({this.delay = 0});
  final int delay;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _ctrl.repeat();
      });
    } else {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shimmer = _ctrl.value;
        return Container(
          constraints: const BoxConstraints(maxWidth: 500),
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusLg),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * shimmer, 0),
              end: Alignment(-0.5 + 2.0 * shimmer, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  width: 70,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(4),
                  )),
              Container(
                  width: 160,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(4),
                  )),
              Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(4),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Staggered fade-in wrapper for cards
// ---------------------------------------------------------------------------

class _StaggeredFadeIn extends StatelessWidget {
  const _StaggeredFadeIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + index * 80),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state widget
// ---------------------------------------------------------------------------

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? SupplyMapColors.accentGreen.withValues(alpha: 0.15)
              : SupplyMapColors.glass,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? SupplyMapColors.accentGreen.withValues(alpha: 0.5)
                : SupplyMapColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? SupplyMapColors.accentGreen
                    : SupplyMapColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: _outfit(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? SupplyMapColors.accentGreen
                    : SupplyMapColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined,
              size: 48, color: SupplyMapColors.borderStrong.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No stores found nearby',
            style: _outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SupplyMapColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try increasing the search radius or\nsearching for a different item.',
            textAlign: TextAlign.center,
            style: _outfit(
              fontSize: 13,
              color: SupplyMapColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
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
