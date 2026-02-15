import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

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
// Gradient background – topo contour rings with color heatmap on hover
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
    // Prune trail samples older than 3s.
    final now = DateTime.now().millisecondsSinceEpoch;
    _trail.removeWhere((s) => now - s.timeMs > 3000);
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
              // Soft color blobs
              CustomPaint(
                painter: _GradientBlobPainter(),
                size: Size.infinite,
              ),
              // Topo rings with color heatmap
              CustomPaint(
                painter: _TopoHeatPainter(
                  mousePos: _mousePos,
                  trail: List.of(_trail),
                  breathe: energy,
                  timeMs: now,
                ),
                size: Size.infinite,
              ),
              // Glow around mouse
              CustomPaint(
                painter: _CursorGlowPainter(mousePos: _mousePos),
                size: Size.infinite,
              ),
              MouseRegion(
                onHover: (e) {
                  if (e.kind == PointerDeviceKind.mouse) {
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
// Soft gradient blobs
// ---------------------------------------------------------------------------

class _GradientBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _blob(canvas, Offset(size.width * 0.15, size.height * 0.1),
        math.max(size.width, size.height) * 0.45,
        SupplyMapColors.accentGreen.withValues(alpha: 0.06));
    _blob(canvas, Offset(size.width * 0.85, size.height * 0.85),
        math.max(size.width, size.height) * 0.45,
        SupplyMapColors.accentWarm.withValues(alpha: 0.06));
    _blob(canvas, Offset(size.width * 0.5, size.height * 0.45),
        math.max(size.width, size.height) * 0.55,
        SupplyMapColors.blue.withValues(alpha: 0.04));
  }

  void _blob(Canvas c, Offset center, double r, Color color) {
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ---------------------------------------------------------------------------
// Topo contour rings – lines stay still, color changes near the cursor
// ---------------------------------------------------------------------------

class _TopoHeatPainter extends CustomPainter {
  _TopoHeatPainter({
    this.mousePos,
    required this.trail,
    this.breathe = 0.0,
    required this.timeMs,
  });

  final Offset? mousePos;
  final List<_HeatSample> trail;
  final double breathe;
  final int timeMs;

  static const int _ringCount = 14;
  static const int _segments = 80;
  // Radius of the color influence around the cursor / trail points.
  static const double _heatRadius = 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rng = math.Random(42);
    final cx = size.width * 0.45;
    final cy = size.height * 0.48;
    final time = timeMs / 1000.0;

    // Warm color for the trailing wake.
    const heatGreen = SupplyMapColors.accentGreen;
    const heatWarm = SupplyMapColors.accentWarm;
    const coldColor = SupplyMapColors.borderStrong;

    for (int i = 1; i <= _ringCount; i++) {
      final baseRx = 50.0 * i + rng.nextDouble() * 14;
      final baseRy = 36.0 * i + rng.nextDouble() * 14;

      // Typing breath: rings expand smoothly.
      final scale = 1.0 + breathe * (0.08 + 0.025 * i);
      final rx = baseRx * scale;
      final ry = baseRy * scale;

      // Base appearance.
      final baseAlpha = (i > 8) ? (0.40 - (i - 8) * 0.05) : 0.40;

      // We draw each segment individually so each can have its own color.
      // Pre-compute all points first.
      final points = <Offset>[];
      for (int s = 0; s <= _segments; s++) {
        final angle = (s / _segments) * 2 * math.pi;
        final noise = 1.0 + (rng.nextDouble() - 0.5) * 0.12;
        double x = cx + rx * noise * math.cos(angle);
        double y = cy + ry * noise * math.sin(angle);

        // Typing breath wave (smooth radial pulse).
        if (breathe > 0) {
          final ax = x - cx;
          final ay = y - cy;
          final len = math.sqrt(ax * ax + ay * ay);
          if (len > 0) {
            final pulse = math.sin(angle * 3 + time * 4.0) * breathe * 3.0;
            x += pulse * (ax / len);
            y += pulse * (ay / len);
          }
        }

        points.add(Offset(x, y));
      }

      // Draw segments with per-segment color.
      for (int s = 0; s < _segments; s++) {
        final p1 = points[s];
        final p2 = points[s + 1];
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

        // Compute heat at segment midpoint.
        double heat = 0; // 0 = cold, 1 = hot (at cursor)
        double warmth = 0; // 0 = no trail, 1 = recent trail

        // Current mouse position.
        if (mousePos != null) {
          final d = (mid - mousePos!).distance;
          if (d < _heatRadius) {
            final proximity = 1.0 - (d / _heatRadius);
            heat = math.max(heat, proximity * proximity);
          }
        }

        // Trail: older samples contribute warmth (cooling).
        for (final sample in trail) {
          final d = (mid - sample.pos).distance;
          if (d < _heatRadius) {
            final age = (timeMs - sample.timeMs) / 1000.0;
            final decay = (1.0 - age / 3.0).clamp(0.0, 1.0);
            final proximity = 1.0 - (d / _heatRadius);
            warmth = math.max(warmth, proximity * proximity * decay);
          }
        }

        // Blend colors: cold -> warm trail -> hot green at cursor.
        Color segColor;
        double segAlpha;
        double segWidth;

        if (heat > 0.01) {
          // Near cursor: bright green, thicker, more opaque.
          segColor = Color.lerp(coldColor, heatGreen, heat)!;
          segAlpha = (baseAlpha + heat * 0.45 + breathe * 0.15).clamp(0.0, 0.9);
          segWidth = 1.2 + heat * 1.8 + breathe * 0.6;
        } else if (warmth > 0.01) {
          // In the trail wake: warm tone, slightly brighter.
          segColor = Color.lerp(coldColor, heatWarm, warmth * 0.7)!;
          segAlpha = (baseAlpha + warmth * 0.25 + breathe * 0.15).clamp(0.0, 0.75);
          segWidth = 1.2 + warmth * 0.8 + breathe * 0.6;
        } else {
          // Cold: default subtle grey (+ green tint when typing).
          segColor = Color.lerp(coldColor, heatGreen, breathe * 0.3)!;
          segAlpha = (baseAlpha + breathe * 0.15).clamp(0.0, 0.65);
          segWidth = 1.2 + breathe * 0.6;
        }

        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = segWidth
          ..strokeCap = StrokeCap.round
          ..color = segColor.withValues(alpha: segAlpha);

        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TopoHeatPainter old) => true; // ticking
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
    const radius = 250.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SupplyMapColors.accentGreen.withValues(alpha: 0.12),
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
