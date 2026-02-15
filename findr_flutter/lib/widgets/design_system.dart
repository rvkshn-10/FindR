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
// Gradient background – dense topo lines with string-vibration on hover
// ---------------------------------------------------------------------------

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
    with SingleTickerProviderStateMixin {
  Offset? _mousePos;
  // Trail of recent mouse positions to create a wake of vibration.
  final List<_MouseSample> _trail = [];
  DateTime _lastMouseUpdate = DateTime(0);

  late final AnimationController _anim;
  Timer? _decayTimer;

  // Typing energy: 0 = idle, 1 = active typing.
  double _breathe = 0.0;

  @override
  void initState() {
    super.initState();
    // Continuous ticker for the vibration animation.
    _anim = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0, max: 1, period: const Duration(seconds: 1));
    _anim.addListener(_tick);
  }

  void _tick() {
    // Prune old trail samples (keep last 1.5s).
    final now = DateTime.now().millisecondsSinceEpoch;
    _trail.removeWhere((s) => now - s.time > 1500);
    // We rely on the ticker to drive repaints – no extra setState needed
    // because AnimatedBuilder already rebuilds on each tick.
  }

  @override
  void dispose() {
    _anim.removeListener(_tick);
    _decayTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _keystroke() {
    _breathe = (_breathe + 0.15).clamp(0.0, 1.0);
    _decayTimer?.cancel();
    _decayTimer = Timer(const Duration(milliseconds: 600), () {
      _startDecay();
    });
  }

  void _startDecay() {
    // Gradually decay _breathe back to 0.
    const step = Duration(milliseconds: 50);
    _decayTimer?.cancel();
    _decayTimer = Timer.periodic(step, (t) {
      _breathe -= 0.025;
      if (_breathe <= 0) {
        _breathe = 0;
        t.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return Container(
          color: SupplyMapColors.bodyBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Soft color blobs (subtle depth)
              CustomPaint(
                painter: _GradientBlobPainter(),
                size: Size.infinite,
              ),
              // Dense topo lines with vibration
              CustomPaint(
                painter: _TopoStringPainter(
                  mousePos: _mousePos,
                  trail: List.of(_trail),
                  breathe: _breathe,
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
                    if (now.difference(_lastMouseUpdate).inMilliseconds < 16) {
                      return;
                    }
                    _lastMouseUpdate = now;
                    _mousePos = e.localPosition;
                    _trail.add(_MouseSample(
                      e.localPosition,
                      now.millisecondsSinceEpoch,
                    ));
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

class _MouseSample {
  final Offset pos;
  final int time;
  const _MouseSample(this.pos, this.time);
}

// ---------------------------------------------------------------------------
// Soft gradient blobs (subtle color depth behind the lines)
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
// Dense topographic lines with string-vibration on mouse proximity
// ---------------------------------------------------------------------------

class _TopoStringPainter extends CustomPainter {
  _TopoStringPainter({
    this.mousePos,
    required this.trail,
    this.breathe = 0.0,
    required this.timeMs,
  });

  final Offset? mousePos;
  final List<_MouseSample> trail;
  final double breathe;
  final int timeMs;

  // How many horizontal lines to draw.
  static const int _lineCount = 50;
  // Radius around cursor that triggers vibration.
  static const double _influenceRadius = 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rng = math.Random(7);
    final w = size.width;
    final h = size.height;
    final spacing = h / (_lineCount + 1);
    final time = timeMs / 1000.0; // seconds

    for (int i = 0; i < _lineCount; i++) {
      final baseY = spacing * (i + 1);
      // Each line has a unique subtle vertical wobble (static topo character).
      final seed = rng.nextDouble() * 1000;
      final amplitude = 2.0 + rng.nextDouble() * 3.0; // gentle base wave

      // Color: alternate subtle greens / warm greys for topo feel.
      final hue = rng.nextDouble();
      final baseColor = Color.lerp(
        SupplyMapColors.borderStrong,
        SupplyMapColors.accentGreen,
        0.1 + hue * 0.15 + breathe * 0.3,
      )!;
      final alpha = (0.25 + rng.nextDouble() * 0.2 + breathe * 0.15)
          .clamp(0.0, 0.7);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 + breathe * 0.4
        ..color = baseColor.withValues(alpha: alpha);

      final path = Path();
      const segments = 120;

      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        final x = t * w;

        // Base topographic wave (static, unique per line).
        double y = baseY +
            math.sin(t * 6.0 + seed) * amplitude +
            math.cos(t * 3.2 + seed * 0.7) * amplitude * 0.6;

        // Breathing pulse from typing.
        if (breathe > 0) {
          y += math.sin(t * 10.0 + time * 4.0) * breathe * 4.0;
        }

        // ── String vibration from mouse proximity ──
        // Check current mouse position.
        double vibration = 0;
        if (mousePos != null) {
          vibration = _calcVibration(
            x, y, mousePos!, time, 1.0, _influenceRadius,
          );
        }
        // Check trail for lingering vibration (decays over time).
        for (final sample in trail) {
          final age = (timeMs - sample.time) / 1000.0; // seconds since sample
          final decay = (1.0 - age / 1.5).clamp(0.0, 1.0);
          if (decay > 0.01) {
            vibration += _calcVibration(
              x, y, sample.pos, time, decay * 0.6, _influenceRadius,
            );
          }
        }

        y += vibration;

        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  /// Calculate vibration displacement at point (px, py) from a source.
  double _calcVibration(
    double px, double py, Offset source,
    double time, double strength, double radius,
  ) {
    final dx = px - source.dx;
    final dy = py - source.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist > radius) return 0;

    // Proximity factor: strongest at cursor, fades to zero at radius.
    final proximity = 1.0 - (dist / radius);
    // Damped sinusoidal oscillation (like a plucked string).
    final freq = 14.0 + dist * 0.05; // higher freq further from center
    final phase = dist * 0.04; // wave ripples outward
    final vibAmp = proximity * proximity * 18.0 * strength;
    return math.sin(time * freq - phase) * vibAmp;
  }

  @override
  bool shouldRepaint(covariant _TopoStringPainter old) => true; // ticking
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
