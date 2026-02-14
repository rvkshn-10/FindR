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
// Global mouse position – written by root-level MouseRegion in main.dart
// ---------------------------------------------------------------------------

/// Global mouse position in logical pixels.
/// Updated from the root MouseRegion that wraps the entire MaterialApp.
final ValueNotifier<Offset> globalMousePosition =
    ValueNotifier(Offset.zero);

// ---------------------------------------------------------------------------
// Keystroke ripple data
// ---------------------------------------------------------------------------

class _Ripple {
  _Ripple({required this.born});
  final double born;
  static const double lifespan = 1.2;
}

// ---------------------------------------------------------------------------
// Notifier for keystroke effects (accessed via InheritedWidget)
// ---------------------------------------------------------------------------

class BackgroundEffectNotifier extends ChangeNotifier {
  final List<_Ripple> ripples = [];
  double typingEnergy = 0.0;
  double elapsed = 0.0;

  void keystroke() {
    ripples.add(_Ripple(born: elapsed));
    typingEnergy = (typingEnergy + 0.45).clamp(0.0, 1.0);
    notifyListeners();
  }

  void tick(double elapsedSeconds) {
    elapsed = elapsedSeconds;
    typingEnergy = (typingEnergy - 0.008).clamp(0.0, 1.0);
    ripples.removeWhere(
        (r) => (elapsedSeconds - r.born) > _Ripple.lifespan);
  }
}

// ---------------------------------------------------------------------------
// InheritedWidget for keystroke notifier
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
// GradientBackground – interactive background
//
// Mouse tracking: reads from [globalMousePosition] (set by root MouseRegion).
// Keystroke effects: children call GradientBackground.maybeOf(ctx)?.keystroke()
// ---------------------------------------------------------------------------

class GradientBackground extends StatefulWidget {
  const GradientBackground({super.key, required this.child});
  final Widget child;

  static BackgroundEffectNotifier? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_BackgroundEffectScope>()
        ?.notifier;
  }

  static BackgroundEffectNotifier of(BuildContext context) {
    final n = maybeOf(context);
    assert(n != null, 'No GradientBackground ancestor');
    return n!;
  }

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  Offset _smoothMouse = Offset.zero;
  bool _mouseInit = false;
  Offset _parallax = Offset.zero;

  late final BackgroundEffectNotifier _fx;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _fx = BackgroundEffectNotifier();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fx.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final secs = elapsed.inMicroseconds / 1e6;

    // Read mouse from the global notifier (written by root MouseRegion).
    final raw = globalMousePosition.value;

    // Snap on first real mouse event (avoid slow lerp from 0,0).
    if (!_mouseInit && raw != Offset.zero) {
      _smoothMouse = raw;
      _mouseInit = true;
    }

    // Smooth lerp.
    const k = 0.10;
    _smoothMouse = Offset(
      _smoothMouse.dx + (raw.dx - _smoothMouse.dx) * k,
      _smoothMouse.dy + (raw.dy - _smoothMouse.dy) * k,
    );

    final sz = context.size;
    if (sz != null && sz.width > 0 && sz.height > 0) {
      _parallax = Offset(
        (_smoothMouse.dx - sz.width / 2) / (sz.width / 2),
        (_smoothMouse.dy - sz.height / 2) / (sz.height / 2),
      );
    }

    _fx.tick(secs);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _BackgroundEffectScope(
      notifier: _fx,
      child: Container(
        color: SupplyMapColors.bodyBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GradientBlobPainter(), size: Size.infinite),
            CustomPaint(
              painter: _TopoPainter(
                parallax: _parallax,
                breatheScale: _fx.typingEnergy,
              ),
              size: Size.infinite,
            ),
            CustomPaint(
              painter: _KeystrokePulsePainter(
                ripples: _fx.ripples,
                elapsed: _fx.elapsed,
              ),
              size: Size.infinite,
            ),
            CustomPaint(
              painter: _CursorGlowPainter(mousePos: _smoothMouse),
              size: Size.infinite,
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blob painter (static warm radial gradients)
// ---------------------------------------------------------------------------

class _GradientBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawBlob(canvas, Offset(size.width * 0.1, size.height * 0.1),
        math.max(size.width, size.height) * 0.4,
        SupplyMapColors.accentGreen.withValues(alpha: 0.08));
    _drawBlob(canvas, Offset(size.width * 0.9, size.height * 0.8),
        math.max(size.width, size.height) * 0.4,
        SupplyMapColors.accentWarm.withValues(alpha: 0.08));
    _drawBlob(canvas, Offset(size.width * 0.5, size.height * 0.5),
        math.max(size.width, size.height) * 0.6,
        SupplyMapColors.blue.withValues(alpha: 0.06));
  }

  void _drawBlob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Topographic contour painter (parallax + typing breathe)
// ---------------------------------------------------------------------------

class _TopoPainter extends CustomPainter {
  _TopoPainter({required this.parallax, this.breatheScale = 0.0});

  final Offset parallax;
  final double breatheScale;

  @override
  void paint(Canvas canvas, Size size) {
    final baseCx = size.width * 0.45;
    final baseCy = size.height * 0.48;
    final rng = math.Random(42);

    final breathe = 1.0 + breatheScale * 0.15;

    for (int i = 1; i <= 10; i++) {
      final baseRx = 55.0 * i + rng.nextDouble() * 12;
      final baseRy = 40.0 * i + rng.nextDouble() * 12;

      final ringBreathe = breathe + breatheScale * 0.04 * i;
      final rx = baseRx * ringBreathe;
      final ry = baseRy * ringBreathe;

      // Parallax: outer rings shift much more than inner.
      final strength = 20.0 + i * 12.0;
      final cx = baseCx + parallax.dx * strength;
      final cy = baseCy + parallax.dy * strength;

      final baseAlpha = (i > 6) ? (0.5 - (i - 6) * 0.08) : 0.5;
      final alpha = (baseAlpha + breatheScale * 0.3).clamp(0.0, 0.9);

      final lineColor = Color.lerp(
        SupplyMapColors.borderStrong,
        SupplyMapColors.accentGreen,
        breatheScale * 0.4,
      )!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + breatheScale * 1.2
        ..color = lineColor.withValues(alpha: alpha);

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
  bool shouldRepaint(covariant _TopoPainter old) =>
      old.parallax != parallax || old.breatheScale != breatheScale;
}

// ---------------------------------------------------------------------------
// Keystroke pulse painter
// ---------------------------------------------------------------------------

class _KeystrokePulsePainter extends CustomPainter {
  _KeystrokePulsePainter({required this.ripples, required this.elapsed});
  final List<_Ripple> ripples;
  final double elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    if (ripples.isEmpty) return;
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final maxRadius = math.max(size.width, size.height) * 0.6;

    for (final r in ripples) {
      final age = elapsed - r.born;
      if (age < 0 || age > _Ripple.lifespan) continue;
      final t = age / _Ripple.lifespan;
      final radius = 30 + maxRadius * Curves.easeOutCubic.transform(t);
      final opacity = (1.0 - Curves.easeInQuad.transform(t)) * 0.35;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1.0 - t * 0.5)
        ..color = SupplyMapColors.accentGreen.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _KeystrokePulsePainter old) => true;
}

// ---------------------------------------------------------------------------
// Cursor-following glow painter
// ---------------------------------------------------------------------------

class _CursorGlowPainter extends CustomPainter {
  _CursorGlowPainter({required this.mousePos});
  final Offset mousePos;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (mousePos == Offset.zero)
        ? Offset(size.width * 0.5, size.height * 0.55)
        : mousePos;
    const radius = 350.0;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          SupplyMapColors.accentGreen.withValues(alpha: 0.22),
          SupplyMapColors.accentGreen.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
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
