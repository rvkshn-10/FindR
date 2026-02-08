import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/store.dart';
import '../services/search_service.dart';
import '../services/distance_util.dart';
import '../providers/settings_provider.dart';
import '../widgets/liquid_glass_background.dart';
import 'settings_screen.dart';

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
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final maxKm = milesToKmFn(widget.maxDistanceMiles);
      final result = await search(
        item: widget.item,
        lat: widget.lat,
        lng: widget.lng,
        maxDistanceKm: maxKm,
        filters: widget.filters,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _openDirections(Store store) {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${store.lat},${store.lng}',
    );
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _onSelectStore(Store store) {
    setState(() => _selectedStoreId = store.id);
    _mapController.move(LatLng(store.lat, store.lng), 16);
    _sheetController.animateTo(0.4,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
    if (_loading) {
      return Scaffold(
        backgroundColor: LiquidGlassColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: LiquidGlassColors.surfaceLight,
          title: Text('Results for "${widget.item}"'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        body: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Finding nearby stores…',
                    style: TextStyle(
                        fontSize: 14, color: LiquidGlassColors.label),
                  ),
                ],
              ),
            ),
          ),
        );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: LiquidGlassColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: LiquidGlassColors.surfaceLight,
          title: const Text('Results'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        body: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        if (widget.onNewSearch != null) {
                          widget.onNewSearch!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      );
    }
    final result = _result!;
    final stores = result.stores;
    final searchRadiusMeters = widget.maxDistanceMiles * 1609.34;

    return Scaffold(
      backgroundColor: LiquidGlassColors.surfaceLight,
      body: Stack(
          children: [
            // CustomScrollView with SliverAppBar (collapsible search bar / header)
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 140,
                  pinned: true,
                  stretch: true,
                  backgroundColor: LiquidGlassColors.surfaceLight,
                  flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 16),
                        title: Text(
                          'Results for "${widget.item}"',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: LiquidGlassColors.label,
                          ),
                        ),
                    background: Padding(
                          padding: EdgeInsets.only(
                              top: MediaQuery.paddingOf(context).top +
                                  kToolbarHeight +
                                  8,
                              left: 16,
                              right: 16,
                              bottom: 8),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              result.summary,
                              style: const TextStyle(
                                fontSize: 13,
                                color: LiquidGlassColors.labelSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (widget.onNewSearch != null) {
                          widget.onNewSearch!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('New search'),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context)
                                      .style
                                      .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                  children: [
                                    const TextSpan(text: 'Within '),
                                    TextSpan(
                                      text: formatMaxDistance(
                                          widget.maxDistanceMiles,
                                          useKm: settings.useKm),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text:
                                          ' · Tap a store for details or directions.',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 400,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Map card
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: stores.isEmpty
                                          ? const Center(
                                              child: Text(
                                                  'No nearby stores found.'))
                                          : FlutterMap(
                                              mapController: _mapController,
                                              options: MapOptions(
                                                initialCenter: LatLng(
                                                    widget.lat, widget.lng),
                                                initialZoom: 14,
                                              ),
                                              children: [
                                                TileLayer(
                                                  urlTemplate:
                                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                  userAgentPackageName:
                                                      'com.findr.findr_flutter',
                                                ),
                                                // Search radius circle (CustomPaint via CircleLayer)
                                                CircleLayer(
                                                  circles: [
                                                    CircleMarker(
                                                      point: LatLng(widget.lat,
                                                          widget.lng),
                                                      radius:
                                                          searchRadiusMeters,
                                                      useRadiusInMeter: true,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                              alpha: 0.12),
                                                      borderColor: Theme.of(
                                                              context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                              alpha: 0.35),
                                                      borderStrokeWidth: 1.5,
                                                    ),
                                                  ],
                                                ),
                                                MarkerLayer(
                                                  markers: [
                                                    Marker(
                                                      point: LatLng(
                                                          widget.lat,
                                                          widget.lng),
                                                      width: 24,
                                                      height: 24,
                                                      child: const Icon(
                                                        Icons
                                                            .person_pin_circle,
                                                        color: Colors.blue,
                                                        size: 24,
                                                      ),
                                                    ),
                                                    ...stores.map((s) {
                                                      final isBest =
                                                          s.id ==
                                                              result
                                                                  .bestOptionId;
                                                      final isSelected =
                                                          s.id ==
                                                              _selectedStoreId;
                                                      return Marker(
                                                        point: LatLng(
                                                            s.lat, s.lng),
                                                        width: 24,
                                                        height: 24,
                                                        child: Icon(
                                                          Icons.store,
                                                          color: isSelected
                                                              ? Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .primary
                                                              : (isBest
                                                                  ? Colors
                                                                      .green
                                                                  : Colors
                                                                      .orange),
                                                          size: isSelected
                                                              ? 28
                                                              : 24,
                                                        ),
                                                      );
                                                    }),
                                                  ],
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              // Store list
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Card(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Text(
                                            'Nearby stores',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600),
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        if (stores.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(24),
                                            child: Center(
                                                child: Text(
                                                    'No nearby stores found.')),
                                          )
                                        else
                                          Expanded(
                                            child: ListView.separated(
                                              itemCount: stores.length,
                                              padding: EdgeInsets.zero,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 1),
                                              itemBuilder: (context, i) {
                                                final s = stores[i];
                                                final isBest = s.id ==
                                                    result.bestOptionId;
                                                return _StoreListTile(
                                                  store: s,
                                                  isBest: isBest,
                                                  settings: settings,
                                                  onTap: () =>
                                                      _onSelectStore(s),
                                                  onDirections: () =>
                                                      _openDirections(s),
                                                );
                                              },
                                            ),
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
                    ),
                  ),
                ),
              ],
            ),
            // DraggableScrollableSheet for slide-up store details panel
            if (_selectedStoreId != null)
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.35,
                minChildSize: 0.2,
                maxChildSize: 0.7,
                snap: true,
                snapSizes: const [0.2, 0.4, 0.7],
                builder: (context, scrollController) {
                  final store = stores
                      .firstWhere((s) => s.id == _selectedStoreId!);
                  return _StoreDetailSheet(
                    store: store,
                    result: result,
                    settings: settings,
                    scrollController: scrollController,
                    onClose: () =>
                        setState(() => _selectedStoreId = null),
                    onDirections: () => _openDirections(store),
                  );
                },
              ),
          ],
        ),
    );
  }
}

/// List tile with Hero for smooth transition to detail sheet.
class _StoreListTile extends StatelessWidget {
  const _StoreListTile({
    required this.store,
    required this.isBest,
    required this.settings,
    required this.onTap,
    required this.onDirections,
  });

  final Store store;
  final bool isBest;
  final SettingsProvider settings;
  final VoidCallback onTap;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isBest
          ? BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              border: const Border(
                left: BorderSide(
                    color: LiquidGlassColors.primary, width: 4),
              ),
            )
          : null,
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Hero(
          tag: 'store_icon_${store.id}',
          child: Icon(
            isBest ? Icons.star : Icons.store_outlined,
            color: isBest
                ? Theme.of(context).colorScheme.primary
                : null,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Hero(
                tag: 'store_name_${store.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    store.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            if (isBest)
              Chip(
                label: const Text('Best', style: TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
              ),
          ],
        ),
        subtitle: Text(
          '${formatDistance(store.distanceKm, useKm: settings.useKm)} away'
          '${store.durationMinutes != null ? ' · ~${store.durationMinutes} min' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: onDirections,
          icon: const Icon(Icons.directions, size: 20),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(36, 36),
          ),
        ),
      ),
    );
  }
}

/// Slide-up panel content with Hero targets and scrollable details.
class _StoreDetailSheet extends StatelessWidget {
  const _StoreDetailSheet({
    required this.store,
    required this.result,
    required this.settings,
    required this.scrollController,
    required this.onClose,
    required this.onDirections,
  });

  final Store store;
  final SearchResult result;
  final SettingsProvider settings;
  final ScrollController scrollController;
  final VoidCallback onClose;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final isBest = store.id == result.bestOptionId;
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: LiquidGlassColors.glassFillLight,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: LiquidGlassColors.glassBorderLight),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Hero(
                                  tag: 'store_icon_${store.id}',
                                  child: Icon(
                                    isBest ? Icons.star : Icons.store,
                                    color: isBest
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : null,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Hero(
                                    tag: 'store_name_${store.id}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Text(
                                        store.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: onClose,
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(32, 32),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${formatDistance(store.distanceKm, useKm: settings.useKm)} away'
                              '${store.durationMinutes != null ? ' · ~${store.durationMinutes} min' : ''}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                            ),
                            if (store.address.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                store.address,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: onDirections,
                              icon: const Icon(Icons.directions, size: 20),
                              label: const Text('Directions'),
                            ),
                          ],
        ),
      ),
    );
  }
}
