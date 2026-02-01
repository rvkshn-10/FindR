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
              SizedBox(height: 16),
              Text('Finding nearby stores…'),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to search'),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You searched: "${widget.item}" · Within ${formatMaxDistance(widget.maxDistanceMiles, useKm: settings.useKm)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(result.summary, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: Card(
                    margin: const EdgeInsets.only(left: 16, right: 8, bottom: 16),
                    clipBehavior: Clip.antiAlias,
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
                    margin: const EdgeInsets.only(left: 8, right: 16, bottom: 16),
                    child: stores.isEmpty
                        ? const Center(child: Text('No nearby stores found.'))
                        : ListView.builder(
                            itemCount: stores.length,
                            itemBuilder: (context, i) {
                              final s = stores[i];
                              final isBest = s.id == result.bestOptionId;
                              return ListTile(
                                title: Row(
                                  children: [
                                    Expanded(child: Text(s.name)),
                                    if (isBest)
                                      const Chip(
                                        label: Text('Best', style: TextStyle(fontSize: 10)),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${formatDistance(s.distanceKm, useKm: settings.useKm)} away'
                                  '${s.durationMinutes != null ? ' · ~${s.durationMinutes} min drive' : ''}',
                                ),
                                trailing: TextButton(
                                  onPressed: () => _openDirections(s),
                                  child: const Text('Directions'),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
