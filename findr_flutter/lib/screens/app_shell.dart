import 'package:flutter/material.dart';
import '../models/search_models.dart';
import '../widgets/design_system.dart';
import 'profile_screen.dart';
import 'results_screen.dart';
import 'search_screen.dart';
import 'shopping_list_screen.dart';

/// Params for showing the results view (from search submit).
class SearchResultParams {
  final String item;
  final double lat;
  final double lng;
  final double maxDistanceMiles;
  final SearchFilters? filters;
  final double? destLat;
  final double? destLng;

  const SearchResultParams({
    required this.item,
    required this.lat,
    required this.lng,
    required this.maxDistanceMiles,
    this.filters,
    this.destLat,
    this.destLng,
  });

  bool get hasDestination => destLat != null && destLng != null;
}

/// Shell: gradient background stays fixed, search/results/profile animate.
class SupplyMapShell extends StatefulWidget {
  const SupplyMapShell({super.key});

  @override
  State<SupplyMapShell> createState() => _SupplyMapShellState();
}

enum _Page { search, results, profile, lists }

class _SupplyMapShellState extends State<SupplyMapShell> {
  _Page _currentPage = _Page.search;
  SearchResultParams? _resultParams;

  void _onSearchResult(SearchResultParams params) {
    setState(() {
      _resultParams = params;
      _currentPage = _Page.results;
    });
  }

  void _onNewSearch() {
    setState(() {
      _resultParams = null;
      _currentPage = _Page.search;
    });
  }

  void _openProfile() {
    setState(() => _currentPage = _Page.profile);
  }

  void _openLists() {
    setState(() => _currentPage = _Page.lists);
  }

  void _searchAgain(String item) {
    setState(() {
      _resultParams = null;
      _currentPage = _Page.search;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          if (child.key == const ValueKey<String>('search')) {
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0)
                    .animate(curved),
                child: child,
              ),
            );
          }
          if (child.key == const ValueKey<String>('results')) {
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          }
          return FadeTransition(opacity: curved, child: child);
        },
        child: _buildCurrentPage(),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case _Page.search:
        return KeyedSubtree(
          key: const ValueKey<String>('search'),
          child: SearchScreen(
            onSearchResult: _onSearchResult,
            onOpenProfile: _openProfile,
            onOpenLists: _openLists,
          ),
        );
      case _Page.results:
        final params = _resultParams;
        if (params == null) {
          return KeyedSubtree(
            key: const ValueKey<String>('search'),
            child: SearchScreen(
              onSearchResult: _onSearchResult,
              onOpenProfile: _openProfile,
            ),
          );
        }
        return KeyedSubtree(
          key: const ValueKey<String>('results'),
          child: ResultsScreen(
            item: params.item,
            lat: params.lat,
            lng: params.lng,
            maxDistanceMiles: params.maxDistanceMiles,
            filters: params.filters,
            onNewSearch: _onNewSearch,
            destLat: params.destLat,
            destLng: params.destLng,
          ),
        );
      case _Page.profile:
        return KeyedSubtree(
          key: const ValueKey<String>('profile'),
          child: ProfileScreen(
            onBack: _onNewSearch,
            onSearchAgain: _searchAgain,
          ),
        );
      case _Page.lists:
        return KeyedSubtree(
          key: const ValueKey<String>('lists'),
          child: ShoppingListScreen(
            onBack: _onNewSearch,
            onSearchItem: (item) {
              _onSearchResult(SearchResultParams(
                item: item, lat: 0, lng: 0, maxDistanceMiles: 10,
              ));
            },
          ),
        );
    }
  }
}
