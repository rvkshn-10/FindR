import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

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
// Keystroke ripple data
// ---------------------------------------------------------------------------

/// A single expanding ring triggered by a keystroke.
class _Ripple {
  _Ripple({required this.born});
  final double born; // elapsed seconds when created
  static const double lifespan = 1.2; // seconds to fully expand & fade
}

// ---------------------------------------------------------------------------
// Notifier that child widgets (search bar) use to trigger background effects
// ---------------------------------------------------------------------------

class BackgroundEffectNotifier extends ChangeNotifier {
  final List<_Ripple> ripples = [];

  /// Current "typing energy" (0..1). Rises with keystrokes, decays over time.
  double typingEnergy = 0.0;

  /// Running elapsed seconds (set by the background ticker).
  double elapsed = 0.0;

  /// Call this on each keystroke to push a ripple.
  void keystroke() {
    ripples.add(_Ripple(born: elapsed));
    // Boost energy (capped at 1.0).
    typingEnergy = (typingEnergy + 0.35).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Tick: decay energy and prune dead ripples.
  void tick(double elapsedSeconds) {
    elapsed = elapsedSeconds;
    // Decay typing energy smoothly.
    typingEnergy = (typingEnergy - 0.012).clamp(0.0, 1.0);
    // Remove expired ripples.
    ripples.removeWhere(
        (r) => (elapsedSeconds - r.born) > _Ripple.lifespan);
  }
}

// ---------------------------------------------------------------------------
// InheritedWidget so children can access the notifier via
// GradientBackground.of(context)
// ---------------------------------------------------------------------------

class _BackgroundEffectScope extends InheritedWidget {
  const _BackgroundEffectScope({
    required this.notifier,
    required super.child,
  });

  final BackgroundEffectNotifier notifier;

  @override
  bool updateShouldNotify(covariant _BackgroundEffectScope oldWidget) =>
      oldWidget.notifier != notifier;
}

// ---------------------------------------------------------------------------
// Gradient background (interactive: parallax + cursor glow + keystroke pulse)
// ---------------------------------------------------------------------------

class GradientBackground extends StatefulWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  /// Retrieve the [BackgroundEffectNotifier] from the nearest ancestor.
  static BackgroundEffectNotifier of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_BackgroundEffectScope>();
    assert(scope != null, 'No GradientBackground found in widget tree');
    return scope!.notifier;
  }

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  // ── Mouse tracking ──
  Offset _rawMouse = Offset.zero;
  Offset _smoothMouse = Offset.zero;
  Offset _parallax = Offset.zero;

  // ── Keystroke effects ──
  late final BackgroundEffectNotifier _effectNotifier;

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _effectNotifier = BackgroundEffectNotifier();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _effectNotifier.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final secs = elapsed.inMicroseconds / 1e6;

    // Smooth mouse lerp.
    const smoothing = 0.08;
    _smoothMouse = Offset(
      _smoothMouse.dx + (_rawMouse.dx - _smoothMouse.dx) * smoothing,
      _smoothMouse.dy + (_rawMouse.dy - _smoothMouse.dy) * smoothing,
    );

    final size = context.size;
    if (size != null && size.width > 0 && size.height > 0) {
      _parallax = Offset(
        (_smoothMouse.dx - size.width / 2) / (size.width / 2),
        (_smoothMouse.dy - size.height / 2) / (size.height / 2),
      );
    }

    // Tick the effect notifier (decay energy, prune ripples).
    _effectNotifier.tick(secs);

    setState(() {});
  }

  void _onHover(PointerEvent event) {
    _rawMouse = event.localPosition;
  }

  @override
  Widget build(BuildContext context) {
    return _BackgroundEffectScope(
      notifier: _effectNotifier,
      child: MouseRegion(
        onHover: _onHover,
        child: Container(
          color: SupplyMapColors.bodyBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Warm, subtle radial gradient blobs
              CustomPaint(
                painter: _GradientBlobPainter(),
                size: Size.infinite,
              ),
              // Topographic contour lines – parallax + typing breathe
              CustomPaint(
                painter: _TopoPainter(
                  parallax: _parallax,
                  breatheScale: _effectNotifier.typingEnergy,
                ),
                size: Size.infinite,
              ),
              // Keystroke pulse rings
              CustomPaint(
                painter: _KeystrokePulsePainter(
                  ripples: _effectNotifier.ripples,
                  elapsed: _effectNotifier.elapsed,
                ),
                size: Size.infinite,
              ),
              // Green radial glow – follows cursor smoothly
              CustomPaint(
                painter: _CursorGlowPainter(mousePos: _smoothMouse),
                size: Size.infinite,
              ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Green blob – top-left
    _drawBlob(
      canvas,
      Offset(size.width * 0.1, size.height * 0.1),
      math.max(size.width, size.height) * 0.4,
      SupplyMapColors.accentGreen.withValues(alpha: 0.08),
    );
    // Warm coral blob – bottom-right
    _drawBlob(
      canvas,
      Offset(size.width * 0.9, size.height * 0.8),
      math.max(size.width, size.height) * 0.4,
      SupplyMapColors.accentWarm.withValues(alpha: 0.08),
    );
    // Blue blob – center
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
  _TopoPainter({required this.parallax, this.breatheScale = 0.0});

  /// Normalized (-1..1) mouse offset from screen center.
  final Offset parallax;

  /// 0..1 "typing energy" – rings expand slightly when > 0.
  final double breatheScale;

  @override
  void paint(Canvas canvas, Size size) {
    // Base center, offset slightly from screen center for organic feel.
    final baseCx = size.width * 0.45;
    final baseCy = size.height * 0.48;

    // Use a seeded random for deterministic wobble across frames.
    final rng = math.Random(42);

    // Breathing: rings scale 1.0 → 1.08 with typing energy.
    final breathe = 1.0 + breatheScale * 0.08;

    // Draw 10 concentric contour rings, each slightly irregular.
    for (int i = 1; i <= 10; i++) {
      final baseRx = 55.0 * i + rng.nextDouble() * 12;
      final baseRy = 40.0 * i + rng.nextDouble() * 12;

      // Apply breathe scaling (outer rings breathe more).
      final ringBreathe = breathe + breatheScale * 0.02 * i;
      final rx = baseRx * ringBreathe;
      final ry = baseRy * ringBreathe;

      // Parallax: outer rings shift MORE than inner rings.
      final parallaxStrength = 8.0 + i * 4.0;
      final cx = baseCx + parallax.dx * parallaxStrength;
      final cy = baseCy + parallax.dy * parallaxStrength;

      // Alpha increases slightly when typing (lines glow a bit).
      final baseAlpha = (i > 6)
          ? (0.5 - (i - 6) * 0.08)
          : 0.5;
      final alpha = (baseAlpha + breatheScale * 0.15).clamp(0.0, 0.8);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + breatheScale * 0.6 // thickens slightly
        ..color = SupplyMapColors.borderStrong.withValues(alpha: alpha);

      final path = Path();

      // Build the ring from 64 sample points with small noise offsets.
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
      oldDelegate.parallax != parallax ||
      oldDelegate.breatheScale != breatheScale;
}

// ---------------------------------------------------------------------------
// Keystroke pulse painter (expanding rings on each keypress)
// ---------------------------------------------------------------------------

class _KeystrokePulsePainter extends CustomPainter {
  _KeystrokePulsePainter({required this.ripples, required this.elapsed});

  final List<_Ripple> ripples;
  final double elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    if (ripples.isEmpty) return;

    // Ripples expand from the center of the screen (search bar area).
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final maxRadius = math.max(size.width, size.height) * 0.6;

    for (final ripple in ripples) {
      final age = elapsed - ripple.born;
      if (age < 0 || age > _Ripple.lifespan) continue;

      final t = age / _Ripple.lifespan; // 0..1 progress
      final radius = 30 + maxRadius * Curves.easeOutCubic.transform(t);
      final opacity = (1.0 - Curves.easeInQuad.transform(t)) * 0.18;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - t * 0.7) // thins as it expands
        ..color = SupplyMapColors.accentGreen.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _KeystrokePulsePainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Cursor-following glow painter (green halo tracks mouse smoothly)
// ---------------------------------------------------------------------------

class _CursorGlowPainter extends CustomPainter {
  _CursorGlowPainter({required this.mousePos});

  final Offset mousePos;

  @override
  void paint(Canvas canvas, Size size) {
    // If mouse hasn't entered yet, default to center-ish (search bar area).
    final center = (mousePos == Offset.zero)
        ? Offset(size.width * 0.5, size.height * 0.55)
        : mousePos;

    const radius = 300.0;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          SupplyMapColors.accentGreen.withValues(alpha: 0.10),
          SupplyMapColors.accentGreen.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _CursorGlowPainter oldDelegate) =>
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
