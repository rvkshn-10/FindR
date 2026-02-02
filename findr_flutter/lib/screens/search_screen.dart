import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/geocode_service.dart';
import '../services/distance_util.dart';
import 'results_screen.dart';
import 'settings_screen.dart';

const _kMaxDistanceMiles = [5.0, 10.0, 15.0];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _itemController = TextEditingController();
  final _locationController = TextEditingController();
  bool _useMyLocation = true;
  double _maxDistanceMiles = 5;
  bool _loading = false;

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
          if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
            setState(() => _loading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location denied. Enter a city or address below.')),
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
              const SnackBar(content: Text('Enter a city or address, or use "Use my location".')),
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
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            item: item,
            lat: lat,
            lng: lng,
            maxDistanceMiles: _maxDistanceMiles,
          ),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supply Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.clamp(0.0, 672.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Center(
              child: SizedBox(
                width: w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'What do you need?',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                        color: Color(0xFF463f37),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Find items nearby – we'll show you stores and the best option.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _itemController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. AA batteries, milk, bandages',
                                prefixIcon: Icon(Icons.search),
                              ),
                              textInputAction: TextInputAction.next,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: _useMyLocation,
                                  onChanged: _loading ? null : (v) => setState(() => _useMyLocation = v ?? true),
                                ),
                                const Text('Use my location'),
                              ],
                            ),
                            if (!_useMyLocation) ...[
                              TextField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                  hintText: 'City or address',
                                  prefixIcon: Icon(Icons.place_outlined),
                                ),
                                enabled: !_loading,
                              ),
                              const SizedBox(height: 16),
                            ],
                            const Divider(height: 24),
                            Row(
                              children: [
                                Text(
                                  'Max distance',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<double>(
                                      value: _maxDistanceMiles,
                                      isExpanded: true,
                                      items: _kMaxDistanceMiles.map((m) {
                                        return DropdownMenuItem(
                                          value: m,
                                          child: Text('Within ${formatMaxDistance(m, useKm: settings.useKm)}'),
                                        );
                                      }).toList(),
                                      onChanged: _loading ? null : (v) => setState(() => _maxDistanceMiles = v ?? 5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _loading ? null : _submit,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.search, size: 20),
                              label: Text(_loading ? 'Finding…' : 'Find nearby'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We show stores that typically carry this kind of item. Availability is estimated.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
