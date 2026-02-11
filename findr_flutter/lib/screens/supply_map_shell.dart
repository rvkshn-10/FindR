import 'package:flutter/material.dart';
import '../models/store.dart';
import '../widgets/liquid_glass_background.dart';
import 'results_screen.dart';
import 'search_screen.dart';

/// Params for showing the results view (from search submit).
class SearchResultParams {
  final String item;
  final double lat;
  final double lng;
  final double maxDistanceMiles;
  final SearchFilters? filters;

  const SearchResultParams({
    required this.item,
    required this.lat,
    required this.lng,
    required this.maxDistanceMiles,
    this.filters,
  });
}

/// Shell: gradient background stays fixed, search ↔ results animate inside.
class SupplyMapShell extends StatefulWidget {
  const SupplyMapShell({super.key});

  @override
  State<SupplyMapShell> createState() => _SupplyMapShellState();
}

class _SupplyMapShellState extends State<SupplyMapShell> {
  SearchResultParams? _resultParams;

  void _onSearchResult(SearchResultParams params) {
    setState(() => _resultParams = params);
  }

  void _onNewSearch() {
    setState(() => _resultParams = null);
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Home fades + scales; Results fades in
          if (child.key == const ValueKey<String>('search')) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0)
                    .animate(animation),
                child: child,
              ),
            );
          }
          return FadeTransition(opacity: animation, child: child);
        },
        child: _resultParams == null
            ? KeyedSubtree(
                key: const ValueKey<String>('search'),
                child: SearchScreen(
                  embedInBackground: false,
                  onSearchResult: _onSearchResult,
                ),
              )
            : KeyedSubtree(
                key: const ValueKey<String>('results'),
                child: ResultsScreen(
                  item: _resultParams!.item,
                  lat: _resultParams!.lat,
                  lng: _resultParams!.lng,
                  maxDistanceMiles: _resultParams!.maxDistanceMiles,
                  filters: _resultParams!.filters,
                  embedInBackground: false,
                  onNewSearch: _onNewSearch,
                ),
              ),
      ),
    );
  }
}
