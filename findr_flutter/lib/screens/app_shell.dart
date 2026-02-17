import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_models.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart' as auth;
import '../widgets/design_system.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
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

/// Shell: gradient background stays fixed, search/results/profile/auth animate.
class SupplyMapShell extends StatefulWidget {
  const SupplyMapShell({super.key});

  @override
  State<SupplyMapShell> createState() => _SupplyMapShellState();
}

enum _Page { search, results, profile, auth }

class _SupplyMapShellState extends State<SupplyMapShell> {
  _Page _currentPage = _Page.search;
  SearchResultParams? _resultParams;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSignedIn();
    });
  }

  void _ensureSignedIn() {
    if (!auth.isSignedIn) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      authProv.signInAnonymously();
    }
  }

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

  void _openAuth() {
    setState(() => _currentPage = _Page.auth);
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
            onOpenAuth: _openAuth,
          ),
        );
      case _Page.results:
        return KeyedSubtree(
          key: const ValueKey<String>('results'),
          child: ResultsScreen(
            item: _resultParams!.item,
            lat: _resultParams!.lat,
            lng: _resultParams!.lng,
            maxDistanceMiles: _resultParams!.maxDistanceMiles,
            filters: _resultParams!.filters,
            onNewSearch: _onNewSearch,
          ),
        );
      case _Page.profile:
        return KeyedSubtree(
          key: const ValueKey<String>('profile'),
          child: ProfileScreen(
            onBack: _onNewSearch,
            onSearchAgain: _searchAgain,
            onOpenAuth: _openAuth,
          ),
        );
      case _Page.auth:
        return KeyedSubtree(
          key: const ValueKey<String>('auth'),
          child: AuthScreen(
            onBack: _onNewSearch,
            onSuccess: _openProfile,
          ),
        );
    }
  }
}
