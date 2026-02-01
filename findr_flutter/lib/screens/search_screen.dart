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
  String? _error;

  @override
  void dispose() {
    _itemController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final item = _itemController.text.trim();
      if (item.isEmpty) {
        setState(() {
          _error = 'Enter what you need.';
          _loading = false;
        });
        return;
      }
      double lat;
      double lng;
      if (_useMyLocation) {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          final req = await Geolocator.requestPermission();
          if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
            setState(() {
              _error = 'Location denied. Enter a city or address below.';
              _loading = false;
            });
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
          setState(() {
            _error = 'Enter a city or address, or use "Use my location".';
            _loading = false;
          });
          return;
        }
        final result = await geocode(loc);
        if (result == null) {
          setState(() {
            _error = 'Could not find that location.';
            _loading = false;
          });
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
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What do you need?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Find stores nearby.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _itemController,
              decoration: const InputDecoration(
                hintText: 'e.g. batteries, milk',
                border: OutlineInputBorder(),
                filled: true,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              textInputAction: TextInputAction.next,
              enabled: !_loading,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _useMyLocation,
                  onChanged: (v) => setState(() {
                    _useMyLocation = v ?? true;
                    _error = null;
                  }),
                ),
                const Text('Use my location', style: TextStyle(fontSize: 14)),
              ],
            ),
            if (!_useMyLocation) ...[
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: 'City or address',
                  border: OutlineInputBorder(),
                  filled: true,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                enabled: !_loading,
              ),
              const SizedBox(height: 8),
            ],
            DropdownButton<double>(
              value: _maxDistanceMiles,
              isExpanded: true,
              isDense: true,
              items: _kMaxDistanceMiles.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text('Within ${formatMaxDistance(m, useKm: settings.useKm)}', style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: _loading ? null : (v) => setState(() => _maxDistanceMiles = v ?? 5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Finding…' : 'Find nearby'),
            ),
          ],
        ),
      ),
    );
  }
}
