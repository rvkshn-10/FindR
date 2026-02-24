import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config.dart';
import '../services/firestore_service.dart' as db;
import '../widgets/design_system.dart';

final RegExp _jsonFenceStart = RegExp(r'^```json\s*', multiLine: true);
final RegExp _fenceEnd = RegExp(r'^```\s*', multiLine: true);

GenerativeModel? _recsModel;
GenerativeModel get _getSummaryModelForRecs => _recsModel ??= GenerativeModel(
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

  const ProfileScreen({
    super.key,
    this.onBack,
    this.onSearchAgain,
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
    _tabController = TabController(length: 3, vsync: this);
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
      final response = await _getSummaryModelForRecs
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 12));

      final text = response.text?.trim();
      if (text != null && text.isNotEmpty) {
        final cleaned = text
            .replaceAll(_jsonFenceStart, '')
            .replaceAll(_fenceEnd, '')
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
      debugPrint('[Wayvio] AI recommendation generation failed: $e');
    }

    if (mounted) setState(() => _generatingRecs = false);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ac.cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: ac.borderSubtle),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 18),
                        onPressed: widget.onBack,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  if (widget.onBack != null) const SizedBox(width: 12),
                  Expanded(child: _buildProfileHeader()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: ac.glass,
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: ac.accentGreen,
                unselectedLabelColor: ac.textTertiary,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: ac.cardBg,
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
                labelStyle: outfit(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    outfit(fontSize: 13, fontWeight: FontWeight.w500),
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSearchHistory(),
                  _buildFavorites(),
                  _buildRecommendations(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ac.accentGreen.withValues(alpha: 0.15),
            border: Border.all(
              color: ac.accentGreen.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              'F',
              style: outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ac.accentGreen,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Profile',
                style: outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ac.textPrimary,
                ),
              ),
              Text(
                'Search history, favorites & more',
                style: outfit(fontSize: 12, color: ac.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Search History Tab
  // ---------------------------------------------------------------------------

  Widget _buildSearchHistory() {
    final ac = AppColors.of(context);
    if (_loadingSearches) {
      return Center(
        child: CircularProgressIndicator(color: ac.accentGreen),
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
                  style: outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ac.red),
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
                  final ms = ts is int ? ts : (ts as num).toInt();
                  final date = DateTime.fromMillisecondsSinceEpoch(ms);
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
    final ac = AppColors.of(context);
    if (_loadingFavorites) {
      return Center(
        child: CircularProgressIndicator(color: ac.accentGreen),
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
    final ac = AppColors.of(context);
    if (_loadingRecs) {
      return Center(
        child: CircularProgressIndicator(color: ac.accentGreen),
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
                    ac.accentGreen,
                    ac.accentGreen.withValues(alpha: 0.85),
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
                    style: outfit(
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
              style: outfit(fontSize: 13, color: ac.textTertiary),
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
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: ac.accentGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: ac.accentGreen),
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
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ac.cardBg,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: ac.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ac.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.search,
                  size: 20, color: ac.accentGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item,
                      style: outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ac.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '$resultCount results  ·  $location',
                    style: outfit(
                        fontSize: 11, color: ac.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (timeLabel.isNotEmpty)
              Text(timeLabel,
                  style: outfit(
                      fontSize: 10, color: ac.textTertiary)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close,
                  size: 16, color: ac.textTertiary),
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
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ac.cardBg,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: ac.borderSubtle),
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
                          color: ac.glass,
                          child: Center(
                            child: Icon(Icons.store,
                                size: 32,
                                color: ac.borderStrong),
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
                            style: outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: ac.textPrimary)),
                        const SizedBox(height: 2),
                        Text(address,
                            style: outfit(
                                fontSize: 12,
                                color: ac.textSecondary),
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
                                  style: outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: ac.textSecondary)),
                              const SizedBox(width: 8),
                            ],
                            if (shopType != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ac.glass,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(shopType!.replaceAll('_', ' '),
                                    style: outfit(
                                        fontSize: 10,
                                        color: ac.textTertiary)),
                              ),
                            const SizedBox(width: 8),
                            Icon(Icons.search,
                                size: 12,
                                color: ac.textTertiary),
                            const SizedBox(width: 2),
                            Text(searchItem,
                                style: outfit(
                                    fontSize: 10,
                                    color: ac.textTertiary)),
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
                        color: ac.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.favorite,
                          size: 18, color: ac.red),
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
    final ac = AppColors.of(context);
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
              color: ac.accentGreen.withValues(alpha: 0.2)),
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
                        ac.accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.auto_awesome,
                      size: 14, color: ac.accentGreen),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ac.textPrimary)),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: ac.textTertiary),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(content,
                  style: outfit(
                      fontSize: 12,
                      color: ac.textSecondary,
                      height: 1.4)),
            ],
            if (basedOn.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(basedOn,
                  style: outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: ac.accentGreen)),
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
    final ac = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 48,
              color: ac.borderStrong.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title,
              style: outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ac.textSecondary)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  outfit(fontSize: 13, color: ac.textTertiary)),
        ],
      ),
    );
  }
}
