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

  Widget _wrapBody(Widget child) {
    if (widget.embedInBackground) {
      return LiquidGlassBackground(child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          flexibleSpace: const LiquidGlassAppBarBar(),
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
        body: _wrapBody(
          Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Finding nearby stores…', style: TextStyle(fontSize: 14, color: LiquidGlassColors.onDarkLabel)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          flexibleSpace: const LiquidGlassAppBarBar(),
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
        body: _wrapBody(
          Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
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
        ),
      );
    }
    final result = _result!;
    final stores = result.stores;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: const LiquidGlassAppBarBar(),
        title: Text('Results for "${widget.item}"'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
      body: _wrapBody(
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth.clamp(0.0, 1152.0);
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 24),
                child: Center(
                  child: SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LiquidGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          const TextSpan(text: 'You searched for: '),
                          TextSpan(
                            text: '"${widget.item}"',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ' · Within ${formatMaxDistance(widget.maxDistanceMiles, useKm: settings.useKm)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stores that typically carry this kind of item. Availability is estimated.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              result.summary,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 400,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LiquidGlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: 20,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: stores.isEmpty
                        ? const Center(child: Text('No nearby stores found.'))
                        : Stack(
                            clipBehavior: Clip.none,
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: LatLng(widget.lat, widget.lng),
                                  initialZoom: 14,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.findr.findr_flutter',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(widget.lat, widget.lng),
                                        width: 24,
                                        height: 24,
                                        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 24),
                                      ),
                                      ...stores.map((s) {
                                        final isBest = s.id == result.bestOptionId;
                                        final isSelected = s.id == _selectedStoreId;
                                        return Marker(
                                          point: LatLng(s.lat, s.lng),
                                          width: 24,
                                          height: 24,
                                          child: Icon(
                                            Icons.store,
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.primary
                                                : (isBest ? Colors.green : Colors.orange),
                                            size: isSelected ? 28 : 24,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                              if (_selectedStoreId != null) ...[
                                Builder(
                                  builder: (context) {
                                    final store = stores.firstWhere(
                                      (s) => s.id == _selectedStoreId!,
                                    );
                                    return Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 12,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: LiquidGlassColors.glassFill,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: LiquidGlassColors.glassBorder,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      store.name,
                                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () => setState(() => _selectedStoreId = null),
                                                    icon: const Icon(Icons.close),
                                                    style: IconButton.styleFrom(
                                                      padding: const EdgeInsets.all(4),
                                                      minimumSize: const Size(32, 32),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (store.address.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  store.address,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Text(
                                                '${formatDistance(store.distanceKm, useKm: settings.useKm)} away'
                                                '${store.durationMinutes != null ? ' · ~${store.durationMinutes} min' : ''}',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                              const SizedBox(height: 12),
                                              FilledButton.icon(
                                                onPressed: () => _openDirections(store),
                                                icon: const Icon(Icons.directions, size: 20),
                                                label: const Text('Directions'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: LiquidGlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: 20,
                      child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            'Nearby stores',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        if (stores.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No nearby stores found.')),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                            itemCount: stores.length,
                            padding: EdgeInsets.zero,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final s = stores[i];
                              final isBest = s.id == result.bestOptionId;
                              return Container(
                                decoration: isBest
                                    ? BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        border: Border(
                                          left: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 4,
                                          ),
                                        ),
                                      )
                                    : null,
                                child: ListTile(
                                  dense: true,
                                  onTap: () {
                                    setState(() => _selectedStoreId = s.id);
                                    _mapController.move(LatLng(s.lat, s.lng), 16);
                                  },
                                  leading: Icon(
                                    isBest ? Icons.star : Icons.store_outlined,
                                    color: isBest ? Theme.of(context).colorScheme.primary : null,
                                    size: 22,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(s.name, style: const TextStyle(fontSize: 14))),
                                      if (isBest)
                                        Chip(
                                          label: const Text('Best', style: TextStyle(fontSize: 11)),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${formatDistance(s.distanceKm, useKm: settings.useKm)} away'
                                    '${s.durationMinutes != null ? ' · ~${s.durationMinutes} min' : ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _openDirections(s),
                                    icon: const Icon(Icons.directions, size: 20),
                                    style: IconButton.styleFrom(
                                      padding: const EdgeInsets.all(8),
                                      minimumSize: const Size(36, 36),
                                    ),
                                  ),
                                ),
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
            ),
          );
        },
      ),
      ),
    );
  }
}
