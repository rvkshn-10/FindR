import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/store.dart';
import '../services/search_service.dart';
import '../services/distance_util.dart';
import '../providers/settings_provider.dart';

class ResultsScreen extends StatefulWidget {
  final String item;
  final double lat;
  final double lng;
  final double maxDistanceMiles;

  const ResultsScreen({
    super.key,
    required this.item,
    required this.lat,
    required this.lng,
    required this.maxDistanceMiles,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  SearchResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Results for "${widget.item}"')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Finding nearby stores…', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final result = _result!;
    final stores = result.stores;
    return Scaffold(
      appBar: AppBar(
        title: Text('Results for "${widget.item}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('New search'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.clamp(0.0, 1152.0);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
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
          ),
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
                  child: Card(
                    margin: const EdgeInsets.only(right: 8),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: stores.isEmpty
                        ? const Center(child: Text('No nearby stores found.'))
                        : FlutterMap(
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
                                    return Marker(
                                      point: LatLng(s.lat, s.lng),
                                      width: 24,
                                      height: 24,
                                      child: Icon(
                                        Icons.store,
                                        color: isBest ? Colors.green : Colors.orange,
                                        size: 24,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Card(
                    margin: const EdgeInsets.only(left: 8),
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
    );
  }
}
