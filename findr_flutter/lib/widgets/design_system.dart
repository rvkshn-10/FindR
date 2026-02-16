import 'dart:async' show Timer;
import 'dart:ui' as ui show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// Design tokens from the HTML mockup
// ---------------------------------------------------------------------------

class SupplyMapColors {
  SupplyMapColors._();

  // Core accent palette (warm, nature-inspired)
  static const Color red = Color(0xFFE85D4A);
  static const Color yellow = Color(0xFFF2D96B);
  static const Color purple = Color(0xFF9B7FD4);
  static const Color blue = Color(0xFF6BA3E8);
  static const Color green = Color(0xFF3D8A5A);

  // Backgrounds (warm cream)
  static const Color darkBg = Color(0xFFEDECEA); // muted surface
  static const Color bodyBg = Color(0xFFF5F4F1); // warm cream primary

  // Glass → now soft white / muted fills
  static const Color glass = Color(0xFFEDECEA); // bg-muted
  static const Color glassBorder = Color(0xFFE5E4E1); // border-subtle

  // Text
  static const Color textWhite = Color(0xFF1A1918); // now dark for light bg
  static const Color textBlack = Color(0xFF1A1918);

  // Secondary / tertiary text
  static const Color textSecondary = Color(0xFF6D6C6A);
  static const Color textTertiary = Color(0xFF9C9B99);

  // Sidebar (white surface)
  static const Color sidebarBg = Color(0xFFFFFFFF);

  // Map area
  static const Color mapBg = Color(0xFFE8E7E4);

  // Borders
  static const Color borderSubtle = Color(0xFFE5E4E1);
  static const Color borderStrong = Color(0xFFD1D0CD);

  // Accent helpers
  static const Color accentGreen = Color(0xFF3D8A5A);
  static const Color accentLightGreen = Color(0xFFC8F0D8);
  static const Color accentWarm = Color(0xFFD89575);
}

// Radii (generous, soft, friendly)
const double kRadiusLg = 16;
const double kRadiusMd = 12;
const double kRadiusSm = 8;
const double kRadiusPill = 999;

// ---------------------------------------------------------------------------
// Gradient background – terrain map with fog-reveal on hover
// ---------------------------------------------------------------------------

/// A sample of the mouse position at a point in time.
class _HeatSample {
  final Offset pos;
  final int timeMs;
  const _HeatSample(this.pos, this.timeMs);
}

class GradientBackground extends StatefulWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  /// Call this from child widgets to trigger a typing pulse.
  static void onKeystroke(BuildContext context) {
    context.findAncestorStateOfType<_GradientBackgroundState>()?._keystroke();
  }

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with TickerProviderStateMixin {
  Offset? _mousePos;
  final List<_HeatSample> _trail = [];
  DateTime _lastMouseUpdate = DateTime(0);

  // Continuous ticker for trail decay animation.
  late final AnimationController _anim;

  // Smooth breath controller.
  late final AnimationController _breathe;
  Timer? _decayTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0, max: 1, period: const Duration(seconds: 1));
    _anim.addListener(_tick);

    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
  }

  void _tick() {
    // Prune trail samples older than 3.5s.
    final now = DateTime.now().millisecondsSinceEpoch;
    _trail.removeWhere((s) => now - s.timeMs > 3500);
  }

  @override
  void dispose() {
    _anim.removeListener(_tick);
    _decayTimer?.cancel();
    _anim.dispose();
    _breathe.dispose();
    super.dispose();
  }

  void _keystroke() {
    final target = (_breathe.value + 0.15).clamp(0.0, 1.0);
    _breathe.animateTo(target, duration: const Duration(milliseconds: 200));
    _decayTimer?.cancel();
    _decayTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _breathe.animateTo(0.0, duration: const Duration(milliseconds: 1200));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_anim, _breathe]),
      builder: (context, _) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final energy = _breathe.value;
        return Container(
          color: SupplyMapColors.bodyBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Bottom layer: decorative terrain map ──
              IgnorePointer(
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(46.8, 8.2), // Swiss Alps
                    initialZoom: 12,
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.findr.findr_flutter',
                    ),
                  ],
                ),
              ),
              // ── Fog overlay with mouse reveal ──
              CustomPaint(
                painter: _FogRevealPainter(
                  mousePos: _mousePos,
                  trail: List.of(_trail),
                  breathe: energy,
                  timeMs: now,
                ),
                size: Size.infinite,
              ),
              // ── Cursor glow ──
              CustomPaint(
                painter: _CursorGlowPainter(mousePos: _mousePos),
                size: Size.infinite,
              ),
              // ── Input layer ──
              MouseRegion(
                onHover: (e) {
                  if (e.kind == ui.PointerDeviceKind.mouse) {
                    final now = DateTime.now();
                    if (now.difference(_lastMouseUpdate).inMilliseconds >= 16) {
                      _lastMouseUpdate = now;
                      _mousePos = e.localPosition;
                      _trail.add(_HeatSample(
                        e.localPosition,
                        now.millisecondsSinceEpoch,
                      ));
                    }
                  }
                },
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Fog overlay – thick cream covers the map; cursor punches through it
// ---------------------------------------------------------------------------

class _FogRevealPainter extends CustomPainter {
  _FogRevealPainter({
    this.mousePos,
    required this.trail,
    this.breathe = 0.0,
    required this.timeMs,
  });

  final Offset? mousePos;
  final List<_HeatSample> trail;
  final double breathe;
  final int timeMs;

  // Reveal parameters (reduced size).
  static const double _cursorRadius = 160.0;
  static const double _cursorCoreRadius = 55.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Save layer so we can use blend modes to "cut holes" in the fog.
    canvas.saveLayer(Offset.zero & size, Paint());

    // 1) Fill entire canvas with cream fog.
    //    Typing breath makes fog slightly thinner globally.
    final fogAlpha = (0.82 - breathe * 0.12).clamp(0.55, 0.85);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = SupplyMapColors.bodyBg.withValues(alpha: fogAlpha),
    );

    // 2) Cut a reveal hole at the cursor using DstOut blend mode.
    if (mousePos != null) {
      final clearPaint = Paint()..blendMode = BlendMode.dstOut;
      clearPaint.shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.7),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: [0.0, _cursorCoreRadius / _cursorRadius, 1.0],
      ).createShader(
        Rect.fromCircle(center: mousePos!, radius: _cursorRadius),
      );
      canvas.drawCircle(mousePos!, _cursorRadius, clearPaint);
    }

    canvas.restore();

    // 3) Subtle green tint at cursor position.
    if (mousePos != null) {
      final greenPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            SupplyMapColors.accentGreen.withValues(alpha: 0.06),
            SupplyMapColors.accentGreen.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: mousePos!, radius: _cursorRadius),
        );
      canvas.drawCircle(mousePos!, _cursorRadius, greenPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FogRevealPainter old) => true; // ticking
}

// ---------------------------------------------------------------------------
// Subtle glow around the cursor
// ---------------------------------------------------------------------------

class _CursorGlowPainter extends CustomPainter {
  _CursorGlowPainter({this.mousePos});

  final Offset? mousePos;

  @override
  void paint(Canvas canvas, Size size) {
    final center = mousePos ?? Offset(size.width * 0.5, size.height * 0.55);
    const radius = 200.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SupplyMapColors.accentGreen.withValues(alpha: 0.14),
            SupplyMapColors.accentGreen.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _CursorGlowPainter old) =>
      old.mousePos != mousePos;
}

// ---------------------------------------------------------------------------
// Glass container (sidebar / panel style)
// ---------------------------------------------------------------------------

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = kRadiusLg,
    this.padding,
    this.color,
    this.border = true,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? SupplyMapColors.sidebarBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border
            ? Border.all(color: SupplyMapColors.borderSubtle, width: 1)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x081A1918),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
