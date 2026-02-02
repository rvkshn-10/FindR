import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/store.dart';
import '../providers/settings_provider.dart';
import '../services/filter_constants.dart';
import '../services/geocode_service.dart';
import '../services/distance_util.dart';
import '../widgets/liquid_glass_background.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'supply_map_shell.dart';

const _kMaxDistanceMiles = [5.0, 10.0, 15.0];
const _kQualityTiers = ['All', 'Premium', 'Standard', 'Budget'];

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
  double _maxDistanceMiles = 5;
  bool _loading = false;
  String _qualityTier = 'All';
  bool _membershipsOnly = false;
  final Set<String> _selectedStoreNames = {};
  bool _filtersExpanded = false;

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
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 16;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: const LiquidGlassAppBarBar(),
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
      body: _buildBody(context, settings, topPadding),
    );
  }

  Widget _buildBody(BuildContext context, SettingsProvider settings, double topPadding) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.clamp(0.0, 672.0);
        return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, 40),
              child: Center(
                child: SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LiquidGlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'What do you need?',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: LiquidGlassColors.onDarkLabel,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      LiquidGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _itemController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. AA batteries, milk, bandages',
                                prefixIcon: Icon(Icons.search),
                              ),
                              textInputAction: _useMyLocation ? TextInputAction.search : TextInputAction.next,
                              onSubmitted: (_) {
                                if (_useMyLocation) {
                                  _submit();
                                }
                              },
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
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _submit(),
                                enabled: !_loading,
                              ),
                              const SizedBox(height: 16),
                            ],
                            const Divider(height: 24),
                            InkWell(
                              onTap: _loading ? null : () => setState(() => _filtersExpanded = !_filtersExpanded),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Filters',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (_maxDistanceMiles != _kMaxDistanceMiles.first ||
                                        _qualityTier != 'All' ||
                                        _membershipsOnly ||
                                        _selectedStoreNames.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Chip(
                                          label: Text(
                                            '${(_maxDistanceMiles != _kMaxDistanceMiles.first ? 1 : 0) + (_qualityTier != 'All' ? 1 : 0) + (_membershipsOnly ? 1 : 0) + _selectedStoreNames.length} active',
                                            style: GoogleFonts.outfit(fontSize: 11),
                                          ),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (_filtersExpanded) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Max distance',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<double>(
                                value: _maxDistanceMiles,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                isExpanded: true,
                                items: _kMaxDistanceMiles.map((m) {
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text('Within ${formatMaxDistance(m, useKm: settings.useKm)}'),
                                  );
                                }).toList(),
                                onChanged: _loading ? null : (v) => setState(() => _maxDistanceMiles = v ?? 5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Quality',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _qualityTier,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                isExpanded: true,
                                items: _kQualityTiers.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                onChanged: _loading ? null : (v) => setState(() => _qualityTier = v ?? 'All'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _membershipsOnly,
                                    onChanged: _loading ? null : (v) => setState(() => _membershipsOnly = v ?? false),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Only membership warehouses (e.g. Costco, Sam\'s Club)',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Specific stores',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: commonStoresForFilter.map((name) {
                                  final selected = _selectedStoreNames.contains(name);
                                  return FilterChip(
                                    label: Text(name, style: GoogleFonts.outfit(fontSize: 12)),
                                    selected: selected,
                                    onSelected: _loading ? null : (v) {
                                      setState(() {
                                        if (v) _selectedStoreNames.add(name);
                                        else _selectedStoreNames.remove(name);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
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
                    const SizedBox(height: 16),
                    Text(
                      'We show stores that typically carry this kind of item. Availability is estimated.',
                      style: GoogleFonts.outfit(
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
    );
    if (widget.embedInBackground) {
      return LiquidGlassBackground(child: content);
    }
    return content;
  }
}
