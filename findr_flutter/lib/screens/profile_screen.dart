import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart' as db;
import '../widgets/design_system.dart';

TextStyle _outfit({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.outfit(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  ).copyWith(shadows: const <Shadow>[]);
}

GenerativeModel _getSummaryModelForRecs() => GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: kGeminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 500,
      ),
    );

/// Profile screen – shows user info, search history, favorites, AI recs.
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final void Function(String item)? onSearchAgain;
  final VoidCallback? onOpenAuth;

  const ProfileScreen({
    super.key,
    this.onBack,
    this.onSearchAgain,
    this.onOpenAuth,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _searches = [];
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _recommendations = [];
  bool _loadingSearches = true;
  bool _loadingFavorites = true;
  bool _loadingRecs = true;
  bool _generatingRecs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      db.getRecentSearches(limit: 30),
      db.getFavorites(),
      db.getRecommendations(limit: 10),
    ]);

    if (!mounted) return;
    setState(() {
      _searches = results[0];
      _favorites = results[1];
      _recommendations = results[2];
      _loadingSearches = false;
      _loadingFavorites = false;
      _loadingRecs = false;
    });
  }

  Future<void> _generateAiRecommendations() async {
    if (_searches.isEmpty) return;
    setState(() => _generatingRecs = true);

    final searchItems =
        _searches.take(10).map((s) => s['item'] as String? ?? '').toList();
    final favStores =
        _favorites.take(5).map((f) => f['storeName'] as String? ?? '').toList();

    final prompt =
        'Based on this user\'s search history and favorite stores, '
        'generate 3 personalized shopping recommendations.\n\n'
        'Recent searches: ${searchItems.join(', ')}\n'
        'Favorite stores: ${favStores.join(', ')}\n\n'
        'For each recommendation, suggest a product/category they might search '
        'for next, why it\'s relevant, and a deal tip.\n\n'
        'Return ONLY valid JSON array:\n'
        '[{"title":"Search suggestion","content":"Why and what to look for",'
        '"basedOn":"Based on your searches for X"}]';

    try {
      final response = await _getSummaryModelForRecs()
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 12));

      final text = response.text?.trim();
      if (text != null && text.isNotEmpty) {
        final cleaned = text
            .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
            .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
            .trim();

        final decoded = jsonDecode(cleaned);
        if (decoded is List) {
          for (final rec in decoded) {
            if (rec is Map<String, dynamic>) {
              await db.saveRecommendation(
                title: rec['title']?.toString() ?? 'Recommendation',
                content: rec['content']?.toString() ?? '',
                basedOn: rec['basedOn']?.toString() ?? '',
              );
            }
          }
          final recs = await db.getRecommendations(limit: 10);
          if (mounted) {
            setState(() {
              _recommendations = recs;
              _generatingRecs = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('AI recommendation generation failed: $e');
    }

    if (mounted) setState(() => _generatingRecs = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: SupplyMapColors.borderSubtle),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 18),
                        onPressed: widget.onBack,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  if (widget.onBack != null) const SizedBox(width: 12),
                  Expanded(child: _buildProfileHeader(auth)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: SupplyMapColors.glass,
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: SupplyMapColors.accentGreen,
                unselectedLabelColor: SupplyMapColors.textTertiary,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                dividerHeight: 0,
                labelStyle: _outfit(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    _outfit(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 16),
                        const SizedBox(width: 6),
                        const Text('History'),
                        if (_searches.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _CountBadge(count: _searches.length),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_border, size: 16),
                        const SizedBox(width: 6),
                        const Text('Favorites'),
                        if (_favorites.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _CountBadge(count: _favorites.length),
                        ],
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 16),
                        SizedBox(width: 6),
                        Text('For You'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Security'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSearchHistory(),
                  _buildFavorites(),
                  _buildRecommendations(),
                  const _SecurityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AuthProvider auth) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SupplyMapColors.accentGreen.withValues(alpha: 0.15),
            border: Border.all(
              color: SupplyMapColors.accentGreen.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: auth.photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    auth.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(auth),
                  ),
                )
              : _defaultAvatar(auth),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.displayName,
                style: _outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: SupplyMapColors.textBlack,
                ),
              ),
              Text(
                auth.email ?? (auth.isAnonymous ? 'Guest account' : ''),
                style: _outfit(
                    fontSize: 12, color: SupplyMapColors.textTertiary),
              ),
            ],
          ),
        ),
        if (auth.isAnonymous)
          _ActionButton(
            label: 'Sign In',
            icon: Icons.login,
            onTap: () {
              if (widget.onOpenAuth != null) {
                widget.onOpenAuth!();
              } else {
                auth.signInWithGoogle();
              }
            },
          )
        else
          _ActionButton(
            label: 'Sign Out',
            icon: Icons.logout,
            onTap: () => auth.signOut(),
            color: SupplyMapColors.red,
          ),
      ],
    );
  }

  Widget _defaultAvatar(AuthProvider auth) {
    return Center(
      child: Text(
        auth.displayName.isNotEmpty
            ? auth.displayName[0].toUpperCase()
            : 'G',
        style: _outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: SupplyMapColors.accentGreen,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search History Tab
  // ---------------------------------------------------------------------------

  Widget _buildSearchHistory() {
    if (_loadingSearches) {
      return const Center(
        child: CircularProgressIndicator(color: SupplyMapColors.accentGreen),
      );
    }
    if (_searches.isEmpty) {
      return const _EmptyTab(
        icon: Icons.search_off,
        title: 'No searches yet',
        subtitle: 'Your search history will appear here.\nGo find something!',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () async {
                  await db.clearSearchHistory();
                  if (mounted) setState(() => _searches = []);
                },
                child: Text(
                  'Clear all',
                  style: _outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: SupplyMapColors.red),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final search = _searches[i];
              final item = search['item'] as String? ?? '';
              final location =
                  search['locationLabel'] as String? ?? 'Near you';
              final count = search['resultCount'] as int? ?? 0;
              String timeLabel = '';
              final ts = search['timestamp'];
              if (ts != null) {
                try {
                  final date = (ts as dynamic).toDate() as DateTime;
                  final diff = DateTime.now().difference(date);
                  if (diff.inMinutes < 1) {
                    timeLabel = 'Just now';
                  } else if (diff.inHours < 1) {
                    timeLabel = '${diff.inMinutes}m ago';
                  } else if (diff.inDays < 1) {
                    timeLabel = '${diff.inHours}h ago';
                  } else {
                    timeLabel = '${diff.inDays}d ago';
                  }
                } catch (_) {}
              }

              return _HistoryCard(
                item: item,
                location: location,
                resultCount: count,
                timeLabel: timeLabel,
                onTap: () => widget.onSearchAgain?.call(item),
                onDelete: () async {
                  final id = search['id'] as String?;
                  if (id != null) {
                    await db.deleteSearch(id);
                    if (mounted) {
                      setState(() => _searches.removeWhere(
                          (s) => s['id'] == id));
                    }
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Favorites Tab
  // ---------------------------------------------------------------------------

  Widget _buildFavorites() {
    if (_loadingFavorites) {
      return const Center(
        child: CircularProgressIndicator(color: SupplyMapColors.accentGreen),
      );
    }
    if (_favorites.isEmpty) {
      return const _EmptyTab(
        icon: Icons.favorite_border,
        title: 'No favorites yet',
        subtitle:
            'Tap the heart on any store card\nto save it here for quick access.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final fav = _favorites[i];
        return _FavoriteCard(
          storeName: fav['storeName'] as String? ?? '',
          address: fav['address'] as String? ?? '',
          searchItem: fav['searchItem'] as String? ?? '',
          rating: (fav['rating'] as num?)?.toDouble(),
          shopType: fav['shopType'] as String?,
          thumbnail: fav['thumbnail'] as String?,
          onTap: () =>
              widget.onSearchAgain?.call(fav['searchItem'] as String? ?? ''),
          onRemove: () async {
            final storeId = fav['storeId'] as String? ?? '';
            await db.removeFavorite(storeId);
            if (mounted) {
              setState(() => _favorites.removeWhere(
                  (f) => f['storeId'] == storeId));
            }
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Recommendations Tab
  // ---------------------------------------------------------------------------

  Widget _buildRecommendations() {
    if (_loadingRecs) {
      return const Center(
        child: CircularProgressIndicator(color: SupplyMapColors.accentGreen),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: GestureDetector(
            onTap: _generatingRecs || _searches.isEmpty
                ? null
                : _generateAiRecommendations,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SupplyMapColors.accentGreen,
                    SupplyMapColors.accentGreen.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_generatingRecs)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.auto_awesome,
                        size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _generatingRecs
                        ? 'Generating recommendations...'
                        : 'Generate AI Recommendations',
                    style: _outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_searches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Search for some items first so the AI can learn your preferences!',
              textAlign: TextAlign.center,
              style: _outfit(fontSize: 13, color: SupplyMapColors.textTertiary),
            ),
          ),
        Expanded(
          child: _recommendations.isEmpty
              ? const _EmptyTab(
                  icon: Icons.auto_awesome,
                  title: 'No recommendations yet',
                  subtitle:
                      'Tap the button above to generate\npersonalized suggestions from AI.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recommendations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final rec = _recommendations[i];
                    return _RecommendationCard(
                      title: rec['title'] as String? ?? '',
                      content: rec['content'] as String? ?? '',
                      basedOn: rec['basedOn'] as String? ?? '',
                      onTap: () {
                        final title = rec['title'] as String? ?? '';
                        if (title.isNotEmpty) {
                          widget.onSearchAgain?.call(title);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: SupplyMapColors.accentGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: _outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: SupplyMapColors.accentGreen),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SupplyMapColors.accentGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 6),
            Text(label,
                style: _outfit(fontSize: 13, fontWeight: FontWeight.w600, color: c)),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.location,
    required this.resultCount,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  final String item, location, timeLabel;
  final int resultCount;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: SupplyMapColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SupplyMapColors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search,
                  size: 20, color: SupplyMapColors.accentGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item,
                      style: _outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SupplyMapColors.textBlack)),
                  const SizedBox(height: 2),
                  Text(
                    '$resultCount results  ·  $location',
                    style: _outfit(
                        fontSize: 11, color: SupplyMapColors.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (timeLabel.isNotEmpty)
              Text(timeLabel,
                  style: _outfit(
                      fontSize: 10, color: SupplyMapColors.textTertiary)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close,
                  size: 16, color: SupplyMapColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.storeName,
    required this.address,
    required this.searchItem,
    this.rating,
    this.shopType,
    this.thumbnail,
    required this.onTap,
    required this.onRemove,
  });

  final String storeName, address, searchItem;
  final double? rating;
  final String? shopType, thumbnail;
  final VoidCallback onTap, onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: SupplyMapColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail != null)
              SizedBox(
                height: 80,
                width: double.infinity,
                child: Image.network(thumbnail!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: SupplyMapColors.glass,
                          child: const Center(
                            child: Icon(Icons.store,
                                size: 32,
                                color: SupplyMapColors.borderStrong),
                          ),
                        )),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName,
                            style: _outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: SupplyMapColors.textBlack)),
                        const SizedBox(height: 2),
                        Text(address,
                            style: _outfit(
                                fontSize: 12,
                                color: SupplyMapColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (rating != null) ...[
                              const Icon(Icons.star_rounded,
                                  size: 14, color: Color(0xFFFFD54F)),
                              const SizedBox(width: 2),
                              Text(rating!.toStringAsFixed(1),
                                  style: _outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: SupplyMapColors.textSecondary)),
                              const SizedBox(width: 8),
                            ],
                            if (shopType != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: SupplyMapColors.glass,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(shopType!.replaceAll('_', ' '),
                                    style: _outfit(
                                        fontSize: 10,
                                        color: SupplyMapColors.textTertiary)),
                              ),
                            const SizedBox(width: 8),
                            const Icon(Icons.search,
                                size: 12,
                                color: SupplyMapColors.textTertiary),
                            const SizedBox(width: 2),
                            Text(searchItem,
                                style: _outfit(
                                    fontSize: 10,
                                    color: SupplyMapColors.textTertiary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SupplyMapColors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite,
                          size: 18, color: SupplyMapColors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.title,
    required this.content,
    required this.basedOn,
    required this.onTap,
  });

  final String title, content, basedOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0F7F3), Color(0xFFEDF5F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(
              color: SupplyMapColors.accentGreen.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color:
                        SupplyMapColors.accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 14, color: SupplyMapColors.accentGreen),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: _outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SupplyMapColors.textBlack)),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: SupplyMapColors.textTertiary),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(content,
                  style: _outfit(
                      fontSize: 12,
                      color: SupplyMapColors.textSecondary,
                      height: 1.4)),
            ],
            if (basedOn.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(basedOn,
                  style: _outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: SupplyMapColors.accentGreen)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 48,
              color: SupplyMapColors.borderStrong.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title,
              style: _outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SupplyMapColors.textSecondary)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  _outfit(fontSize: 13, color: SupplyMapColors.textTertiary)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Security Tab
// ---------------------------------------------------------------------------

class _SecurityTab extends StatefulWidget {
  const _SecurityTab();

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  // Controllers for various actions
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();

  String? _verificationId; // for SMS
  String? _message;
  bool _messageIsError = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCodeCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _message = msg;
        _messageIsError = isError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isAnonymous) {
      return const _EmptyTab(
        icon: Icons.shield_outlined,
        title: 'Sign in to manage security',
        subtitle:
            'Create an account or sign in\nto access security settings.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status message
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _messageIsError
                    ? SupplyMapColors.red.withValues(alpha: 0.08)
                    : SupplyMapColors.accentGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(kRadiusSm),
                border: Border.all(
                  color: _messageIsError
                      ? SupplyMapColors.red.withValues(alpha: 0.3)
                      : SupplyMapColors.accentGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _messageIsError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: _messageIsError
                        ? SupplyMapColors.red
                        : SupplyMapColors.accentGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _message!,
                      style: _outfit(
                        fontSize: 12,
                        color: _messageIsError
                            ? SupplyMapColors.red
                            : SupplyMapColors.accentGreen,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _message = null),
                    child: const Icon(Icons.close,
                        size: 14, color: SupplyMapColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),

        // ── Email Verification ───────────────────────────────────────
        const _SectionHeader(title: 'Email Verification'),
        _SecurityCard(
          icon: auth.isEmailVerified
              ? Icons.verified
              : Icons.mark_email_unread_outlined,
          iconColor: auth.isEmailVerified
              ? SupplyMapColors.accentGreen
              : SupplyMapColors.accentWarm,
          title: auth.email ?? 'No email',
          subtitle: auth.isEmailVerified
              ? 'Email verified'
              : 'Email not verified',
          trailing: auth.isEmailVerified
              ? const Icon(Icons.check_circle,
                  size: 20, color: SupplyMapColors.accentGreen)
              : _SmallButton(
                  label: 'Verify',
                  onTap: () async {
                    setState(() => _loading = true);
                    final err = await auth.sendEmailVerification();
                    if (!mounted) return;
                    setState(() => _loading = false);
                    if (err != null) {
                      _showMessage(err, isError: true);
                    } else {
                      _showMessage('Verification email sent! Check your inbox.');
                    }
                  },
                  loading: _loading,
                ),
        ),
        if (!auth.isEmailVerified)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
            child: GestureDetector(
              onTap: () async {
                final verified = await auth.reloadAndCheckVerified();
                if (verified) {
                  _showMessage('Email verified!');
                } else {
                  _showMessage('Not verified yet. Check your email.',
                      isError: true);
                }
              },
              child: Text(
                'I already verified — check again',
                style: _outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: SupplyMapColors.accentGreen,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // ── Change Email ─────────────────────────────────────────────
        const _SectionHeader(title: 'Change Email'),
        _SecurityInputRow(
          controller: _emailCtrl,
          hint: 'New email address',
          icon: Icons.email_outlined,
          buttonLabel: 'Update',
          onTap: () async {
            final newEmail = _emailCtrl.text.trim();
            if (newEmail.isEmpty || !newEmail.contains('@')) {
              _showMessage('Enter a valid email', isError: true);
              return;
            }
            setState(() => _loading = true);
            final err = await auth.updateEmail(newEmail);
            if (!mounted) return;
            setState(() => _loading = false);
            if (err != null) {
              _showMessage(err, isError: true);
            } else {
              _emailCtrl.clear();
              _showMessage(
                  'Verification sent to $newEmail. Confirm to update.');
            }
          },
          loading: _loading,
        ),
        const SizedBox(height: 16),

        // ── Change Password ──────────────────────────────────────────
        if (auth.hasPasswordProvider) ...[
          const _SectionHeader(title: 'Change Password'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SecurityInputField(
              controller: _currentPasswordCtrl,
              hint: 'Current password',
              icon: Icons.lock_outline,
              obscure: true,
            ),
          ),
          _SecurityInputRow(
            controller: _newPasswordCtrl,
            hint: 'New password (min 6 chars)',
            icon: Icons.lock_reset,
            obscure: true,
            buttonLabel: 'Change',
            onTap: () async {
              if (_currentPasswordCtrl.text.isEmpty) {
                _showMessage('Enter your current password first',
                    isError: true);
                return;
              }
              if (_newPasswordCtrl.text.length < 6) {
                _showMessage('New password must be at least 6 characters',
                    isError: true);
                return;
              }
              setState(() => _loading = true);
              var err = await auth
                  .reauthenticateWithPassword(_currentPasswordCtrl.text);
              if (!mounted) return;
              if (err != null) {
                setState(() => _loading = false);
                _showMessage(err, isError: true);
                return;
              }
              err = await auth.updatePassword(_newPasswordCtrl.text);
              if (!mounted) return;
              setState(() => _loading = false);
              if (err != null) {
                _showMessage(err, isError: true);
              } else {
                _currentPasswordCtrl.clear();
                _newPasswordCtrl.clear();
                _showMessage('Password updated!');
              }
            },
            loading: _loading,
          ),
          const SizedBox(height: 16),
        ],

        // ── Password Reset ───────────────────────────────────────────
        const _SectionHeader(title: 'Password Reset'),
        _SecurityCard(
          icon: Icons.lock_reset,
          title: 'Forgot your password?',
          subtitle: 'We\'ll send a reset link to ${auth.email ?? "your email"}',
          trailing: _SmallButton(
            label: 'Send Reset',
            onTap: () async {
              if (auth.email == null) {
                _showMessage('No email on this account', isError: true);
                return;
              }
              setState(() => _loading = true);
              final err = await auth.sendPasswordReset(auth.email!);
              if (!mounted) return;
              setState(() => _loading = false);
              if (err != null) {
                _showMessage(err, isError: true);
              } else {
                _showMessage('Password reset email sent!');
              }
            },
            loading: _loading,
          ),
        ),
        const SizedBox(height: 16),

        // ── Phone / SMS Verification ─────────────────────────────────
        const _SectionHeader(title: 'Phone / SMS Verification'),
        if (auth.hasPhoneProvider)
          _SecurityCard(
            icon: Icons.phone_android,
            iconColor: SupplyMapColors.accentGreen,
            title: auth.phoneNumber ?? 'Phone linked',
            subtitle: 'Phone number verified',
            trailing: _SmallButton(
              label: 'Remove',
              color: SupplyMapColors.red,
              onTap: () async {
                setState(() => _loading = true);
                final err = await auth.unlinkPhone();
                if (!mounted) return;
                setState(() => _loading = false);
                if (err != null) {
                  _showMessage(err, isError: true);
                } else {
                  _showMessage('Phone number removed.');
                }
              },
              loading: _loading,
            ),
          )
        else ...[
          if (_verificationId == null)
            _SecurityInputRow(
              controller: _phoneCtrl,
              hint: '+1 234 567 8900',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              buttonLabel: 'Send Code',
              onTap: () async {
                final phone = _phoneCtrl.text.trim();
                if (phone.isEmpty) {
                  _showMessage('Enter a phone number', isError: true);
                  return;
                }
                setState(() => _loading = true);
                await auth.verifyPhoneNumber(
                  phoneNumber: phone,
                  onCodeSent: (vId) {
                    if (!mounted) return;
                    setState(() {
                      _verificationId = vId;
                      _loading = false;
                    });
                    _showMessage('SMS code sent to $phone');
                  },
                  onAutoVerified: (_) {
                    if (!mounted) return;
                    setState(() {
                      _verificationId = null;
                      _loading = false;
                    });
                    _showMessage('Phone verified automatically!');
                  },
                  onError: (err) {
                    if (!mounted) return;
                    setState(() => _loading = false);
                    _showMessage(err, isError: true);
                  },
                );
              },
              loading: _loading,
            )
          else
            _SecurityInputRow(
              controller: _smsCodeCtrl,
              hint: '6-digit code',
              icon: Icons.sms_outlined,
              keyboardType: TextInputType.number,
              buttonLabel: 'Verify',
              onTap: () async {
                if (_smsCodeCtrl.text.trim().isEmpty) {
                  _showMessage('Enter the SMS code', isError: true);
                  return;
                }
                setState(() => _loading = true);
                final err = await auth.confirmSmsCode(
                  verificationId: _verificationId!,
                  smsCode: _smsCodeCtrl.text.trim(),
                );
                if (!mounted) return;
                setState(() => _loading = false);
                if (err != null) {
                  _showMessage(err, isError: true);
                } else {
                  _smsCodeCtrl.clear();
                  _phoneCtrl.clear();
                  setState(() => _verificationId = null);
                  _showMessage('Phone number verified!');
                }
              },
              loading: _loading,
            ),
        ],
        const SizedBox(height: 16),

        // ── Linked Providers ─────────────────────────────────────────
        const _SectionHeader(title: 'Linked Sign-In Methods'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (auth.hasPasswordProvider)
              const _ProviderChip(label: 'Email/Password', icon: Icons.email),
            if (auth.hasGoogleProvider)
              const _ProviderChip(label: 'Google', icon: Icons.g_mobiledata),
            if (auth.hasPhoneProvider)
              const _ProviderChip(label: 'Phone', icon: Icons.phone),
          ],
        ),
        const SizedBox(height: 24),

        // ── Delete Account ───────────────────────────────────────────
        const _SectionHeader(title: 'Danger Zone'),
        GestureDetector(
          onTap: () => _showDeleteConfirmation(context, auth),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: SupplyMapColors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(
                  color: SupplyMapColors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delete_forever,
                    size: 20, color: SupplyMapColors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delete Account',
                          style: _outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: SupplyMapColors.red)),
                      Text(
                          'Permanently delete your account and all data',
                          style: _outfit(
                              fontSize: 11,
                              color: SupplyMapColors.textTertiary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: SupplyMapColors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Account?',
            style: _outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SupplyMapColors.textBlack)),
        content: Text(
          'This will permanently delete your account, search history, '
          'favorites, and all data. This cannot be undone.',
          style: _outfit(fontSize: 14, color: SupplyMapColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: _outfit(color: SupplyMapColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await auth.deleteAccount();
              if (err != null) {
                _showMessage(err, isError: true);
              }
            },
            child: Text('Delete',
                style: _outfit(
                    fontWeight: FontWeight.w600,
                    color: SupplyMapColors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Security sub-widgets ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: _outfit(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: SupplyMapColors.textTertiary,
        ),
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final Color? iconColor;
  final String title, subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: SupplyMapColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  (iconColor ?? SupplyMapColors.accentGreen).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 18,
                color: iconColor ?? SupplyMapColors.accentGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: _outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SupplyMapColors.textBlack)),
                Text(subtitle,
                    style: _outfit(
                        fontSize: 11,
                        color: SupplyMapColors.textTertiary)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SupplyMapColors.accentGreen;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: c),
              )
            : Text(label,
                style: _outfit(
                    fontSize: 11, fontWeight: FontWeight.w600, color: c)),
      ),
    );
  }
}

class _SecurityInputField extends StatelessWidget {
  const _SecurityInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: SupplyMapColors.bodyBg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: SupplyMapColors.borderSubtle),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: _outfit(fontSize: 13, color: SupplyMapColors.textBlack),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              _outfit(fontSize: 13, color: SupplyMapColors.textTertiary),
          prefixIcon:
              Icon(icon, size: 16, color: SupplyMapColors.textTertiary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _SecurityInputRow extends StatelessWidget {
  const _SecurityInputRow({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.buttonLabel,
    required this.onTap,
    this.loading = false,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint, buttonLabel;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading, obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecurityInputField(
            controller: controller,
            hint: hint,
            icon: icon,
            obscure: obscure,
            keyboardType: keyboardType,
          ),
        ),
        const SizedBox(width: 8),
        _SmallButton(label: buttonLabel, onTap: onTap, loading: loading),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SupplyMapColors.accentGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(
            color: SupplyMapColors.accentGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: SupplyMapColors.accentGreen),
          const SizedBox(width: 6),
          Text(label,
              style: _outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: SupplyMapColors.accentGreen)),
        ],
      ),
    );
  }
}
