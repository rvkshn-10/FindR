import 'dart:async' show Timer;
import 'dart:math' as math;
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
const double kBlurStrength = 30;

// Keep the old name so existing imports don't break.
typedef LiquidGlassColors = SupplyMapColors;

// ---------------------------------------------------------------------------
// Gradient background (static warm blobs + topo lines + glow)
// ---------------------------------------------------------------------------

class GradientBackground extends StatefulWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  /// Call this from child widgets to trigger a typing pulse.
  /// Usage: GradientBackground.onKeystroke(context)
  static void onKeystroke(BuildContext context) {
    context.findAncestorStateOfType<_GradientBackgroundState>()?._keystroke();
  }

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  Offset? _mousePos;

  // Typing energy: builds up with keystrokes, decays when idle.
  late final AnimationController _breathe;
  Timer? _decayTimer;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    _breathe.dispose();
    super.dispose();
  }

  void _keystroke() {
    // Each keystroke nudges the energy up a bit (capped at 1.0).
    // When typing stops, it decays back to 0.
    final target = (_breathe.value + 0.15).clamp(0.0, 1.0);
    _breathe.animateTo(target, duration: const Duration(milliseconds: 200));

    // Schedule decay: after a pause, animate back to 0.
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
      animation: _breathe,
      builder: (context, _) {
        final energy = _breathe.value;
        return Container(
          color: SupplyMapColors.bodyBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _GradientBlobPainter(),
                size: Size.infinite,
              ),
              CustomPaint(
                painter: _TopoPainter(
                  breathe: energy,
                  mousePos: _mousePos,
                ),
                size: Size.infinite,
              ),
              CustomPaint(
                painter: _SearchGlowPainter(mousePos: _mousePos),
                size: Size.infinite,
              ),
              MouseRegion(
                onHover: (e) => setState(() => _mousePos = e.localPosition),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawBlob(
      canvas,
      Offset(size.width * 0.1, size.height * 0.1),
      math.max(size.width, size.height) * 0.4,
      SupplyMapColors.accentGreen.withValues(alpha: 0.08),
    );
    _drawBlob(
      canvas,
      Offset(size.width * 0.9, size.height * 0.8),
      math.max(size.width, size.height) * 0.4,
      SupplyMapColors.accentWarm.withValues(alpha: 0.08),
    );
    _drawBlob(
      canvas,
      Offset(size.width * 0.5, size.height * 0.5),
      math.max(size.width, size.height) * 0.6,
      SupplyMapColors.blue.withValues(alpha: 0.06),
    );
  }

  void _drawBlob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Topographic contour line painter (map-themed background texture)
// ---------------------------------------------------------------------------

class _TopoPainter extends CustomPainter {
  _TopoPainter({this.breathe = 0.0, this.mousePos});

  /// 0 = resting, 1 = fully expanded (keystroke pulse).
  final double breathe;

  /// Current mouse position (null = no mouse yet).
  final Offset? mousePos;

  @override
  void paint(Canvas canvas, Size size) {
    final baseCx = size.width * 0.45;
    final baseCy = size.height * 0.48;
    final rng = math.Random(42);

    // Parallax: how far the mouse is from center, normalized to -1..1.
    double px = 0.0;
    double py = 0.0;
    if (mousePos != null && size.width > 0 && size.height > 0) {
      px = (mousePos!.dx - size.width / 2) / (size.width / 2);
      py = (mousePos!.dy - size.height / 2) / (size.height / 2);
    }

    for (int i = 1; i <= 10; i++) {
      final baseRx = 55.0 * i + rng.nextDouble() * 12;
      final baseRy = 40.0 * i + rng.nextDouble() * 12;

      // Scale up when typing – outer rings expand more.
      final scale = 1.0 + breathe * (0.10 + 0.03 * i);
      final rx = baseRx * scale;
      final ry = baseRy * scale;

      // Parallax shift: outer rings move more than inner.
      final strength = 15.0 + i * 8.0;
      final cx = baseCx + px * strength;
      final cy = baseCy + py * strength;

      // Lines get thicker and slightly greener when typing.
      final baseAlpha = (i > 6) ? (0.5 - (i - 6) * 0.08) : 0.5;
      final alpha = (baseAlpha + breathe * 0.25).clamp(0.0, 0.85);
      final color = Color.lerp(
        SupplyMapColors.borderStrong,
        SupplyMapColors.accentGreen,
        breathe * 0.35,
      )!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + breathe * 1.0
        ..color = color.withValues(alpha: alpha);

      final path = Path();

      const segments = 64;
      for (int s = 0; s <= segments; s++) {
        final angle = (s / segments) * 2 * math.pi;
        final noise = 1.0 + (rng.nextDouble() - 0.5) * 0.12;
        final x = cx + rx * noise * math.cos(angle);
        final y = cy + ry * noise * math.sin(angle);
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          final prevAngle = ((s - 1) / segments) * 2 * math.pi;
          final prevNoise = 1.0 + (rng.nextDouble() - 0.5) * 0.10;
          final cpx = cx + rx * prevNoise * math.cos((prevAngle + angle) / 2);
          final cpy = cy + ry * prevNoise * math.sin((prevAngle + angle) / 2);
          path.quadraticBezierTo(cpx, cpy, x, y);
        }
      }

      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopoPainter oldDelegate) =>
      oldDelegate.breathe != breathe || oldDelegate.mousePos != mousePos;
}

// ---------------------------------------------------------------------------
// Radial glow painter (soft green halo behind the search bar)
// ---------------------------------------------------------------------------

class _SearchGlowPainter extends CustomPainter {
  _SearchGlowPainter({this.mousePos});

  final Offset? mousePos;

  @override
  void paint(Canvas canvas, Size size) {
    // Follow mouse if available, otherwise default to center.
    final center = mousePos ?? Offset(size.width * 0.5, size.height * 0.55);
    const radius = 350.0;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          SupplyMapColors.accentGreen.withValues(alpha: 0.18),
          SupplyMapColors.accentGreen.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SearchGlowPainter oldDelegate) =>
      oldDelegate.mousePos != mousePos;
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
