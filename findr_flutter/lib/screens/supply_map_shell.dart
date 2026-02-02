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

/// Shell that keeps the background fixed and only animates the content
/// when switching between search and results.
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
    return LiquidGlassBackground(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isSearch = child.key == const ValueKey<String>('search');
          final offsetAnim = Tween<Offset>(
            begin: isSearch ? const Offset(-1, 0) : const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(
            position: offsetAnim,
            child: child,
          );
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
