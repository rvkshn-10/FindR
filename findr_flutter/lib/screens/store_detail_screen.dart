import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/search_models.dart';
import '../services/firestore_service.dart' as db;
import '../widgets/design_system.dart';

/// Shows a store detail bottom sheet.
Future<void> showStoreDetailSheet(
  BuildContext context, {
  required Store store,
  required String searchItem,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StoreDetailSheet(store: store, searchItem: searchItem),
  );
}

class _StoreDetailSheet extends StatefulWidget {
  final Store store;
  final String searchItem;
  const _StoreDetailSheet({required this.store, required this.searchItem});

  @override
  State<_StoreDetailSheet> createState() => _StoreDetailSheetState();
}

class _StoreDetailSheetState extends State<_StoreDetailSheet> {
  List<String> _commonItems = [];
  String? _note;
  final _noteController = TextEditingController();
  bool _noteEditing = false;

  int _availability = 0;
  int _speed = 0;
  int _parking = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final items = await db.getStoreItems(widget.store.id);
    final review = await db.getStoreReview(widget.store.id);
    final note = await db.getStoreNote(widget.store.id);
    if (mounted) {
      setState(() {
        _commonItems = items;
        _note = note;
        _noteController.text = note ?? '';
        if (review != null) {
          _availability = review['availability'] as int? ?? 0;
          _speed = review['speed'] as int? ?? 0;
          _parking = review['parking'] as int? ?? 0;
        }
      });
    }
  }

  Future<void> _saveReview() async {
    await db.saveStoreReview(
        widget.store.id, _availability, _speed, _parking);
    HapticFeedback.lightImpact();
  }

  Future<void> _saveNote() async {
    final text = _noteController.text.trim();
    await db.saveStoreNote(widget.store.id, text);
    if (mounted) {
      setState(() {
        _note = text.isEmpty ? null : text;
        _noteEditing = false;
      });
    }
  }

  List<String> _bestForTags() {
    final tags = <String>[];
    final type = widget.store.shopType ?? widget.store.amenityType;
    if (type != null && type.isNotEmpty) {
      tags.add(type.replaceAll('_', ' '));
    }
    for (final item in _commonItems.take(3)) {
      tags.add(item);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final store = widget.store;
    final bestForTags = _bestForTags();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: ac.sidebarBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: ac.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Thumbnail + name header
              if (store.thumbnail != null && store.thumbnail!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    store.thumbnail!,
                    height: 160, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (store.thumbnail != null) const SizedBox(height: 14),
              Text(
                store.name,
                style: outfit(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: ac.textPrimary,
                ),
              ),
              if (store.brand != null && store.brand!.isNotEmpty &&
                  store.brand!.toLowerCase() != store.name.toLowerCase())
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(store.brand!,
                      style: outfit(fontSize: 13, color: ac.textTertiary)),
                ),

              const SizedBox(height: 12),

              // "Best for" tags
              if (bestForTags.isNotEmpty) ...[
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: bestForTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ac.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(kRadiusPill),
                      ),
                      child: Text(
                        'Best for $tag',
                        style: outfit(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: ac.accentGreen,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Rating + price level row
              _buildRatingRow(ac, store),

              // Confidence badge
              if (store.confidence != StoreConfidence.low) ...[
                const SizedBox(height: 8),
                _buildConfidenceBadge(ac, store.confidence),
              ],

              const SizedBox(height: 16),
              Divider(color: ac.borderSubtle, height: 1),
              const SizedBox(height: 16),

              // Opening hours
              _buildInfoRow(ac, Icons.schedule, 'Hours',
                  store.openingHours ?? 'Unknown'),

              // Address
              _buildInfoRow(ac, Icons.location_on_outlined, 'Address',
                  store.address),

              // Phone
              if (store.phone != null && store.phone!.isNotEmpty)
                _buildTappableRow(ac, Icons.phone_outlined, 'Phone',
                    store.phone!, () => _launch('tel:${store.phone}')),

              // Website
              if (store.website != null && store.website!.isNotEmpty)
                _buildTappableRow(ac, Icons.language, 'Website',
                    store.website!, () => _launch(store.website!)),

              const SizedBox(height: 12),

              // Service options
              if (store.serviceOptions.isNotEmpty) ...[
                Text('Services',
                    style: outfit(fontSize: 13, fontWeight: FontWeight.w600,
                        color: ac.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: store.serviceOptions.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ac.glass,
                        borderRadius: BorderRadius.circular(kRadiusPill),
                        border: Border.all(color: ac.borderSubtle),
                      ),
                      child: Text(s,
                          style: outfit(fontSize: 11, color: ac.textPrimary)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Common items
              if (_commonItems.isNotEmpty) ...[
                Text('Common items people find here',
                    style: outfit(fontSize: 13, fontWeight: FontWeight.w600,
                        color: ac.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _commonItems.take(8).map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ac.glass,
                        borderRadius: BorderRadius.circular(kRadiusPill),
                      ),
                      child: Text(item,
                          style: outfit(fontSize: 11, color: ac.textPrimary)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              Divider(color: ac.borderSubtle, height: 1),
              const SizedBox(height: 16),

              // Your rating section
              Text('Your Rating',
                  style: outfit(fontSize: 15, fontWeight: FontWeight.w700,
                      color: ac.textPrimary)),
              const SizedBox(height: 10),
              _buildRatingSlider(ac, 'Availability', _availability,
                  (v) => setState(() { _availability = v; _saveReview(); })),
              _buildRatingSlider(ac, 'Speed', _speed,
                  (v) => setState(() { _speed = v; _saveReview(); })),
              _buildRatingSlider(ac, 'Parking', _parking,
                  (v) => setState(() { _parking = v; _saveReview(); })),

              if (_availability > 0 || _speed > 0 || _parking > 0) ...[
                const SizedBox(height: 8),
                _buildReviewSummary(ac),
              ],

              const SizedBox(height: 16),
              Divider(color: ac.borderSubtle, height: 1),
              const SizedBox(height: 16),

              // Note section
              Row(
                children: [
                  Icon(Icons.note_outlined, size: 16, color: ac.textSecondary),
                  const SizedBox(width: 6),
                  Text('Your Note',
                      style: outfit(fontSize: 13, fontWeight: FontWeight.w600,
                          color: ac.textSecondary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _noteEditing = !_noteEditing),
                    child: Text(
                      _noteEditing ? 'Done' : (_note != null ? 'Edit' : 'Add'),
                      style: outfit(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: ac.accentGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_noteEditing)
                Column(
                  children: [
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      style: outfit(fontSize: 13, color: ac.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add a note about this store...',
                        hintStyle: outfit(fontSize: 13, color: ac.textTertiary),
                        filled: true,
                        fillColor: ac.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: ac.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: ac.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: ac.accentGreen),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _saveNote,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: ac.accentGreen,
                            borderRadius: BorderRadius.circular(kRadiusPill),
                          ),
                          child: Text('Save',
                              style: outfit(fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_note != null && _note!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ac.glass,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_note!,
                      style: outfit(fontSize: 13, color: ac.textPrimary,
                          height: 1.4)),
                )
              else
                Text('No note yet',
                    style: outfit(fontSize: 12, color: ac.textTertiary)),

              const SizedBox(height: 24),

              // Directions buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Apple Maps',
                      icon: Icons.map_outlined,
                      onTap: () => _launch(
                          'https://maps.apple.com/?daddr=${store.lat},${store.lng}&dirflg=d'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Google Maps',
                      icon: Icons.directions,
                      onTap: () => _launch(
                          'https://www.google.com/maps/dir/?api=1&destination=${store.lat},${store.lng}'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingRow(AppColors ac, Store store) {
    return Row(
      children: [
        if (store.rating != null) ...[
          ...List.generate(5, (i) {
            final filled = store.rating! >= i + 1;
            final half = store.rating! >= i + 0.5 && store.rating! < i + 1;
            return Icon(
              filled ? Icons.star : (half ? Icons.star_half : Icons.star_border),
              size: 16,
              color: const Color(0xFFE8B730),
            );
          }),
          const SizedBox(width: 4),
          Text(store.rating!.toStringAsFixed(1),
              style: outfit(fontSize: 13, fontWeight: FontWeight.w600,
                  color: ac.textPrimary)),
          if (store.reviewCount != null) ...[
            const SizedBox(width: 4),
            Text('(${_formatCount(store.reviewCount!)})',
                style: outfit(fontSize: 12, color: ac.textTertiary)),
          ],
        ],
        if (store.priceLevel != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ac.glass,
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
            child: Text(store.priceLevel!,
                style: outfit(fontSize: 12, fontWeight: FontWeight.w600,
                    color: ac.textSecondary)),
          ),
        ],
      ],
    );
  }

  Widget _buildConfidenceBadge(AppColors ac, StoreConfidence confidence) {
    final Color color;
    final String label;
    switch (confidence) {
      case StoreConfidence.high:
        color = ac.accentGreen;
        label = 'High confidence';
        break;
      case StoreConfidence.medium:
        color = const Color(0xFFE8B730);
        label = 'Medium confidence';
        break;
      case StoreConfidence.low:
        color = ac.textTertiary;
        label = 'Low confidence';
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: outfit(fontSize: 11, fontWeight: FontWeight.w500,
                color: color)),
      ],
    );
  }

  Widget _buildInfoRow(AppColors ac, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ac.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: outfit(fontSize: 11, fontWeight: FontWeight.w600,
                        color: ac.textTertiary)),
                const SizedBox(height: 1),
                Text(value,
                    style: outfit(fontSize: 13, color: ac.textPrimary,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTappableRow(
      AppColors ac, IconData icon, String label, String value,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: ac.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: outfit(fontSize: 11, fontWeight: FontWeight.w600,
                          color: ac.textTertiary)),
                  const SizedBox(height: 1),
                  Text(value,
                      style: outfit(fontSize: 13, color: ac.accentGreen,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSlider(
      AppColors ac, String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(label,
                style: outfit(fontSize: 12, color: ac.textSecondary)),
          ),
          ...List.generate(5, (i) {
            final active = value >= i + 1;
            return GestureDetector(
              onTap: () => onChanged(value == i + 1 ? 0 : i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  active ? Icons.star : Icons.star_border,
                  size: 22,
                  color: active ? const Color(0xFFE8B730) : ac.borderStrong,
                ),
              ),
            );
          }),
          if (value > 0) ...[
            const SizedBox(width: 6),
            Text('$value/5',
                style: outfit(fontSize: 11, color: ac.textTertiary)),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewSummary(AppColors ac) {
    final scores = <String, int>{
      'availability': _availability,
      'speed': _speed,
      'parking': _parking,
    };
    final best = scores.entries.reduce(
        (a, b) => a.value >= b.value ? a : b);
    if (best.value == 0) return const SizedBox.shrink();
    final tips = {
      'availability': 'good stock availability; reliable for essentials',
      'speed': 'quick in-and-out; great for fast trips',
      'parking': 'easy parking; consider it for bigger hauls',
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ac.accentGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 14, color: ac.accentGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You rated this store high for ${best.key} — ${tips[best.key]}.',
              style: outfit(fontSize: 11, color: ac.accentGreen, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _formatCount(int c) {
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(c >= 10000 ? 0 : 1)}K';
    return '$c';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label, required this.icon, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: ac.accentGreen,
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: outfit(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
