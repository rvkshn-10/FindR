import 'dart:ui' as ui;
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

  @override
  void initState() {
    super.initState();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitMapToClosestStores(result.stores);
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
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
      ),
    );
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
    Store? selectedStore;
    if (_selectedStoreId != null) {
      for (final s in stores) {
        if (s.id == _selectedStoreId) {
          selectedStore = s;
          break;
        }
      }
    }

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
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 16),
                        title: Text(
                          'Results for "${widget.item}"',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: LiquidGlassColors.label,
                            decoration: TextDecoration.none,
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
                              DefaultTextStyle(
                                style: DefaultTextStyle.of(context).style.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                  decorationColor: Colors.transparent,
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.none,
                                      decorationColor: Colors.transparent,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Within '),
                                      TextSpan(
                                        text: formatMaxDistance(
                                            widget.maxDistanceMiles,
                                            useKm: settings.useKm),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.none,
                                            decorationColor: Colors.transparent),
                                      ),
                                      TextSpan(
                                        text:
                                            ' · Tap a store for details or directions.',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.normal,
                                          decoration: TextDecoration.none,
                                          decorationColor: Colors.transparent,
                                        ),
                                      ),
                                    ],
                                  ),
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
                                                    ...stores.asMap().entries.map((entry) {
                                                      final i = entry.key;
                                                      final s = entry.value;
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
                                                        width: 34,
                                                        height: 34,
                                                        child: _StoreMarkerBadge(
                                                          index: i + 1,
                                                          isBest: isBest,
                                                          isSelected: isSelected,
                                                          onTap: () => _onSelectStore(s),
                                                        ),
                                                      );
                                                    }),
                                                    if (selectedStore != null)
                                                      Marker(
                                                        point: LatLng(selectedStore.lat, selectedStore.lng),
                                                        width: 250,
                                                        height: 130,
                                                        child: Align(
                                                          alignment: Alignment.topCenter,
                                                          child: _SelectedStorePopup(
                                                            store: selectedStore,
                                                            settings: settings,
                                                            onClose: () => setState(() => _selectedStoreId = null),
                                                            onDirections: () => _openDirections(selectedStore!),
                                                          ),
                                                        ),
                                                      ),
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
                                                  isSelected: s.id == _selectedStoreId,
                                                  settings: settings,
                                                  onTap: () =>
                                                      _onSelectStore(s),
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
    required this.isSelected,
    required this.settings,
    required this.onTap,
  });

  final Store store;
  final bool isBest;
  final bool isSelected;
  final SettingsProvider settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showHighlight = isBest || isSelected;
    return Container(
      decoration: showHighlight
          ? BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                left: BorderSide(
                  color: LiquidGlassColors.primary,
                  width: isSelected ? 5 : 4,
                ),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Selected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
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
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, size: 16),
                      splashRadius: 16,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDistance(store.distanceKm, useKm: settings.useKm)} away'
                  '${store.durationMinutes != null ? ' · ~${store.durationMinutes} min' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions, size: 16),
                    label: const Text('Directions'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        CustomPaint(
          size: const Size(18, 8),
          painter: _PopupArrowPainter(color: theme.colorScheme.surface),
        ),
      ],
    );
  }
}

class _StoreMarkerBadge extends StatelessWidget {
  const _StoreMarkerBadge({
    required this.index,
    required this.isBest,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final bool isBest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = isSelected
        ? theme.colorScheme.primary
        : (isBest ? Colors.green : Colors.orange);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isSelected ? 13 : 12,
            ),
          ),
        ),
      ),
    );
  }
}

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
    final paint = Paint()..color = color;
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _PopupArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

