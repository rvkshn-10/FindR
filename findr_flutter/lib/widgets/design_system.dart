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
// Gradient background – topo contour rings with ripple wave on hover/click
// ---------------------------------------------------------------------------

/// A ripple expanding outward from a point.
class _Ripple {
  final Offset center;
  final int birthMs;
  final double strength; // 1.0 = hover, 3.0 = click
  const _Ripple(this.center, this.birthMs, this.strength);
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
    with SingleTickerProviderStateMixin {
  Offset? _mousePos;
  final List<_Ripple> _ripples = [];
  DateTime _lastMouseUpdate = DateTime(0);
  DateTime _lastRippleEmit = DateTime(0);

  late final AnimationController _anim;
  Timer? _decayTimer;

  // Typing energy: 0 = idle, 1 = active typing.
  double _breathe = 0.0;

  @override
  void initState() {
    super.initState();
    // Continuous ticker drives ripple animation.
    _anim = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0, max: 1, period: const Duration(seconds: 1));
    _anim.addListener(_tick);
  }

  void _tick() {
    // Prune ripples older than 1.5s.
    final now = DateTime.now().millisecondsSinceEpoch;
    _ripples.removeWhere((r) => now - r.birthMs > 1500);
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
              // Concentric topo rings with ripple displacement
              CustomPaint(
                painter: _TopoRipplePainter(
                  ripples: List.of(_ripples),
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
              // Input layer: hover emits gentle ripples, click emits big one
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (e.kind == PointerDeviceKind.mouse) {
                    _ripples.add(_Ripple(
                      e.localPosition,
                      DateTime.now().millisecondsSinceEpoch,
                      3.0,
                    ));
                  }
                },
                child: MouseRegion(
                  onHover: (e) {
                    if (e.kind == PointerDeviceKind.mouse) {
                      final now = DateTime.now();
                      // Throttle mouse position updates (~60fps).
                      if (now.difference(_lastMouseUpdate).inMilliseconds >= 16) {
                        _lastMouseUpdate = now;
                        _mousePos = e.localPosition;
                      }
                      // Emit a hover ripple every ~120ms.
                      if (now.difference(_lastRippleEmit).inMilliseconds >= 120) {
                        _lastRippleEmit = now;
                        _ripples.add(_Ripple(
                          e.localPosition,
                          now.millisecondsSinceEpoch,
                          1.0,
                        ));
                      }
                    }
                  },
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
// Concentric topo contour rings with smooth ripple-wave displacement
// ---------------------------------------------------------------------------

class _TopoRipplePainter extends CustomPainter {
  _TopoRipplePainter({
    required this.ripples,
    this.breathe = 0.0,
    required this.timeMs,
  });

  final List<_Ripple> ripples;
  final double breathe;
  final int timeMs;

  static const int _ringCount = 14;
  static const int _segments = 80;

  // Ripple physics.
  static const double _rippleSpeed = 400.0; // px per second
  static const double _rippleLifespan = 1.2; // seconds
  static const double _rippleSpread = 2200.0; // bell-curve width (squared)

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rng = math.Random(42);
    final cx = size.width * 0.45;
    final cy = size.height * 0.48;
    final time = timeMs / 1000.0;

    for (int i = 1; i <= _ringCount; i++) {
      final baseRx = 50.0 * i + rng.nextDouble() * 14;
      final baseRy = 36.0 * i + rng.nextDouble() * 14;

      // Scale up when typing – outer rings expand more.
      final scale = 1.0 + breathe * (0.08 + 0.025 * i);
      final rx = baseRx * scale;
      final ry = baseRy * scale;

      // Color: subtle grey -> slightly green when typing.
      final baseAlpha = (i > 8) ? (0.45 - (i - 8) * 0.06) : 0.45;
      final alpha = (baseAlpha + breathe * 0.2).clamp(0.0, 0.75);
      final color = Color.lerp(
        SupplyMapColors.borderStrong,
        SupplyMapColors.accentGreen,
        breathe * 0.35,
      )!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + breathe * 0.8
        ..color = color.withValues(alpha: alpha);

      final path = Path();

      for (int s = 0; s <= _segments; s++) {
        final angle = (s / _segments) * 2 * math.pi;
        final noise = 1.0 + (rng.nextDouble() - 0.5) * 0.12;
        double x = cx + rx * noise * math.cos(angle);
        double y = cy + ry * noise * math.sin(angle);

        // ── Ripple displacement ──
        double dispDx = 0;
        double dispDy = 0;

        // Radial unit vector (outward from ring center).
        final ax = x - cx;
        final ay = y - cy;
        final len = math.sqrt(ax * ax + ay * ay);
        final nx = len > 0 ? ax / len : 0.0;
        final ny = len > 0 ? ay / len : 0.0;

        for (final ripple in ripples) {
          final age = (timeMs - ripple.birthMs) / 1000.0;
          if (age > _rippleLifespan || age < 0) continue;

          // Expanding wavefront radius.
          final wavefront = age * _rippleSpeed;

          // Distance from this point to ripple center.
          final rdx = x - ripple.center.dx;
          final rdy = y - ripple.center.dy;
          final dist = math.sqrt(rdx * rdx + rdy * rdy);

          // Bell curve: peaks when dist == wavefront, drops off on both sides.
          final delta = dist - wavefront;
          final bell = math.exp(-(delta * delta) / _rippleSpread);

          // Fade out as ripple ages.
          final fade = 1.0 - (age / _rippleLifespan);

          // Displacement magnitude.
          final disp = ripple.strength * bell * fade * 12.0;

          // Push radially outward from ring center.
          dispDx += disp * nx;
          dispDy += disp * ny;
        }

        // Typing breath wave.
        if (breathe > 0) {
          final pulse = math.sin(angle * 3 + time * 4.0) * breathe * 3.0;
          dispDx += pulse * nx;
          dispDy += pulse * ny;
        }

        x += dispDx;
        y += dispDy;

        if (s == 0) {
          path.moveTo(x, y);
        } else {
          final prevAngle = ((s - 1) / _segments) * 2 * math.pi;
          final prevNoise = 1.0 + (rng.nextDouble() - 0.5) * 0.10;
          final midAngle = (prevAngle + angle) / 2;
          final cpx = cx + rx * prevNoise * math.cos(midAngle) + dispDx * 0.5;
          final cpy = cy + ry * prevNoise * math.sin(midAngle) + dispDy * 0.5;
          path.quadraticBezierTo(cpx, cpy, x, y);
        }
      }

      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopoRipplePainter old) => true; // ticking
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
