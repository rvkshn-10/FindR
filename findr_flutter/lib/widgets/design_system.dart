import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Design tokens from the HTML mockup
// ---------------------------------------------------------------------------

class SupplyMapColors {
  SupplyMapColors._();

  // Core accent palette (warm, nature-inspired)
  static const Color red = Color(0xFFE85D4A);
  static const Color purple = Color(0xFF9B7FD4);
  static const Color blue = Color(0xFF6BA3E8);

  // Backgrounds (warm cream)
  static const Color bodyBg = Color(0xFFF5F4F1); // warm cream primary

  // Glass → now soft white / muted fills
  static const Color glass = Color(0xFFEDECEA); // bg-muted
  static const Color glassBorder = Color(0xFFE5E4E1); // border-subtle

  // Text
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

/// Adaptive color palette — returns dark or light colors based on brightness.
class AppColors {
  final bool isDark;
  const AppColors._(this.isDark);

  factory AppColors.of(BuildContext context) {
    return AppColors._(Theme.of(context).brightness == Brightness.dark);
  }

  // Accent (brighter green in dark mode for visibility)
  Color get accentGreen => isDark ? const Color(0xFF4EBF75) : SupplyMapColors.accentGreen;
  Color get accentLightGreen => isDark ? const Color(0xFF1B3D28) : SupplyMapColors.accentLightGreen;
  Color get accentWarm => isDark ? const Color(0xFFE8A88A) : SupplyMapColors.accentWarm;

  // Core accents
  Color get red => SupplyMapColors.red;
  Color get purple => isDark ? const Color(0xFFB39DDF) : SupplyMapColors.purple;
  Color get blue => isDark ? const Color(0xFF82B5F0) : SupplyMapColors.blue;

  // Backgrounds
  Color get bodyBg => isDark ? const Color(0xFF121212) : SupplyMapColors.bodyBg;
  Color get sidebarBg => isDark ? const Color(0xFF1E1E1E) : SupplyMapColors.sidebarBg;
  Color get mapBg => isDark ? const Color(0xFF1A1A1A) : SupplyMapColors.mapBg;

  // Glass (cards, chips)
  Color get glass => isDark ? const Color(0xFF2A2A2A) : SupplyMapColors.glass;
  Color get glassBorder => isDark ? const Color(0xFF3A3A3A) : SupplyMapColors.glassBorder;

  // Text
  Color get textPrimary => isDark ? const Color(0xFFEAEAEA) : SupplyMapColors.textBlack;
  Color get textSecondary => isDark ? const Color(0xFFAAAAAA) : SupplyMapColors.textSecondary;
  Color get textTertiary => isDark ? const Color(0xFF777777) : SupplyMapColors.textTertiary;

  // Borders
  Color get borderSubtle => isDark ? const Color(0xFF333333) : SupplyMapColors.borderSubtle;
  Color get borderStrong => isDark ? const Color(0xFF444444) : SupplyMapColors.borderStrong;

  // Surfaces for inputs, cards
  Color get inputBg => isDark ? const Color(0xFF252525) : Colors.white;
  Color get cardBg => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get dimOverlay => isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.15);
}

// Radii (generous, soft, friendly)
const double kRadiusLg = 16;
const double kRadiusMd = 12;
const double kRadiusSm = 8;
const double kRadiusPill = 999;

/// Shared Outfit font helper — strips text shadows to avoid blurRadius assertion.
TextStyle outfit({
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

/// A single touch ripple: where it started and when.
class _Ripple {
  final Offset origin;
  final double startTime; // seconds since app start
  _Ripple(this.origin, this.startTime);
}

class _GradientBackgroundState extends State<GradientBackground>
    with TickerProviderStateMixin {
  Offset? _mousePos;
  DateTime _lastMouseUpdate = DateTime(0);

  // Typing energy: builds up with keystrokes, decays when idle.
  late final AnimationController _breathe;
  Timer? _decayTimer;

  // Touch ripples (phone only).
  final List<_Ripple> _ripples = [];
  late final AnimationController _rippleTicker;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _rippleCleanupTimer;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rippleTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _stopwatch.start();
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    _rippleCleanupTimer?.cancel();
    _breathe.dispose();
    _rippleTicker.dispose();
    super.dispose();
  }

  void _addRipple(Offset position) {
    final now = _stopwatch.elapsedMilliseconds / 1000.0;
    _ripples.add(_Ripple(position, now));
    if (_ripples.length > 6) _ripples.removeAt(0);
    if (!_rippleTicker.isAnimating) _rippleTicker.repeat();
    // Schedule cleanup 2.1s after this ripple will expire.
    _rippleCleanupTimer?.cancel();
    _rippleCleanupTimer = Timer(const Duration(milliseconds: 2100), () {
      // Remove expired ripples.
      final now = _stopwatch.elapsedMilliseconds / 1000.0;
      _ripples.removeWhere((r) => (now - r.startTime) > 2.0);
      if (_ripples.isEmpty && _rippleTicker.isAnimating) {
        _rippleTicker.stop();
      }
      if (mounted) setState(() {});
    });
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
      animation: Listenable.merge([_breathe, _rippleTicker]),
      builder: (context, _) {
        final energy = _breathe.value;
        final now = _stopwatch.elapsedMilliseconds / 1000.0;
        final ac = AppColors.of(context);
        return Container(
          color: ac.bodyBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _GradientBlobPainter(isDark: ac.isDark),
                size: Size.infinite,
              ),
              CustomPaint(
                painter: _TopoPainter(
                  breathe: energy,
                  mousePos: _mousePos,
                  ripples: _ripples,
                  time: now,
                  isDark: ac.isDark,
                ),
                size: Size.infinite,
              ),
              CustomPaint(
                painter: _SearchGlowPainter(mousePos: _mousePos, isDark: ac.isDark),
                size: Size.infinite,
              ),
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (e.kind != PointerDeviceKind.mouse) {
                    _addRipple(e.localPosition);
                  }
                },
                child: MouseRegion(
                  onHover: (e) {
                    if (e.kind == PointerDeviceKind.mouse) {
                      final now = DateTime.now();
                      if (now.difference(_lastMouseUpdate).inMilliseconds < 16) {
                        return;
                      }
                      _lastMouseUpdate = now;
                      setState(() => _mousePos = e.localPosition);
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

class _GradientBlobPainter extends CustomPainter {
  final bool isDark;
  _GradientBlobPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final greenAlpha = isDark ? 0.12 : 0.08;
    final warmAlpha = isDark ? 0.10 : 0.08;
    final blueAlpha = isDark ? 0.08 : 0.06;
    final green = isDark ? const Color(0xFF4EBF75) : SupplyMapColors.accentGreen;
    _drawBlob(
      canvas,
      Offset(size.width * 0.1, size.height * 0.1),
      math.max(size.width, size.height) * 0.4,
      green.withValues(alpha: greenAlpha),
    );
    _drawBlob(
      canvas,
      Offset(size.width * 0.9, size.height * 0.8),
      math.max(size.width, size.height) * 0.4,
      SupplyMapColors.accentWarm.withValues(alpha: warmAlpha),
    );
    _drawBlob(
      canvas,
      Offset(size.width * 0.5, size.height * 0.5),
      math.max(size.width, size.height) * 0.6,
      SupplyMapColors.blue.withValues(alpha: blueAlpha),
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
  bool shouldRepaint(covariant _GradientBlobPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

// ---------------------------------------------------------------------------
// Topographic contour line painter (map-themed background texture)
// ---------------------------------------------------------------------------

class _TopoPainter extends CustomPainter {
  _TopoPainter({
    this.breathe = 0.0,
    this.mousePos,
    this.ripples = const [],
    this.time = 0.0,
    this.isDark = false,
  });

  /// 0 = resting, 1 = fully expanded (keystroke pulse).
  final double breathe;

  /// Current mouse position (null = no mouse yet).
  final Offset? mousePos;

  /// Active touch ripples.
  final List<_Ripple> ripples;

  /// Current time in seconds (from stopwatch).
  final double time;

  /// Dark mode flag.
  final bool isDark;

  // Pre-filter ripples that are still alive to avoid per-point checks.
  late final List<_Ripple> _activeRipples = ripples
      .where((r) => (time - r.startTime) >= 0 && (time - r.startTime) <= 2.0)
      .toList(growable: false);

  @override
  void paint(Canvas canvas, Size size) {
    final baseCx = size.width * 0.5;
    final baseCy = size.height * 0.5;
    final rng = math.Random(42);

    // Parallax: how far the mouse is from center, normalized to -1..1.
    final mp = mousePos;
    double px = 0.0;
    double py = 0.0;
    if (mp != null && size.width > 0 && size.height > 0) {
      px = (mp.dx - size.width / 2) / (size.width / 2);
      py = (mp.dy - size.height / 2) / (size.height / 2);
    }

    // Reusable paint object.
    final paint = Paint()..style = PaintingStyle.stroke;

    const segments = 36;
    const twoPi = 2 * math.pi;
    const invSeg = 1.0 / segments;

    for (int i = 1; i <= 10; i++) {
      final baseRx = 55.0 * i + rng.nextDouble() * 12;
      final baseRy = 40.0 * i + rng.nextDouble() * 12;

      final scale = 1.0 + breathe * (0.10 + 0.03 * i);
      final rx = baseRx * scale;
      final ry = baseRy * scale;

      final strength = 15.0 + i * 8.0;
      final cx = baseCx + px * strength;
      final cy = baseCy + py * strength;

      // Proximity boost: thicken & brighten rings near the cursor.
      double proximity = 0.0;
      if (mp != null) {
        final dx = (mp.dx - cx) / rx;
        final dy = (mp.dy - cy) / ry;
        final normalDist = math.sqrt(dx * dx + dy * dy);
        final distFromRing = (normalDist - 1.0).abs();
        proximity = (1.0 - distFromRing * 2.5).clamp(0.0, 1.0); // 1/0.4=2.5
      }

      final baseAlpha = isDark
          ? ((i > 6) ? (0.5 - (i - 6) * 0.04) : 0.5)
          : ((i > 6) ? (0.7 - (i - 6) * 0.06) : 0.7);
      final alpha = (baseAlpha + breathe * 0.2 + proximity * 0.25).clamp(0.0, 0.95);
      final greenAmount = (breathe * 0.35 + proximity * 0.5).clamp(0.0, 1.0);
      final baseColor = isDark ? const Color(0xFF444444) : SupplyMapColors.borderStrong;
      final accentColor = isDark ? const Color(0xFF4EBF75) : SupplyMapColors.accentGreen;
      final color = Color.lerp(
        baseColor,
        accentColor,
        greenAmount,
      ) ?? baseColor;

      paint
        ..strokeWidth = 1.6 + breathe * 1.0 + proximity * 1.8
        ..color = color.withValues(alpha: alpha);

      final path = Path();

      for (int s = 0; s <= segments; s++) {
        final angle = s * invSeg * twoPi;
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);
        final noise = 1.0 + (rng.nextDouble() - 0.5) * 0.12;
        var x = cx + rx * noise * cosA;
        var y = cy + ry * noise * sinA;

        // Ripple displacement (only when there are active ripples).
        for (final ripple in _activeRipples) {
          final age = time - ripple.startTime;
          final waveRadius = age * 300.0;
          final rdx = x - ripple.origin.dx;
          final rdy = y - ripple.origin.dy;
          final dist = math.sqrt(rdx * rdx + rdy * rdy);
          final waveDelta = (dist - waveRadius).abs();
          if (waveDelta > 60) continue;
          final jiggle =
              (1.0 - age * 0.5) * (1.0 - waveDelta / 60.0) * 12.0;
          if (dist > 1) {
            final sinJiggle = jiggle * math.sin(age * 18.0);
            x += (rdx / dist) * sinJiggle;
            y += (rdy / dist) * sinJiggle;
          }
        }

        if (s == 0) {
          path.moveTo(x, y);
        } else {
          final prevAngle = (s - 1) * invSeg * twoPi;
          final midAngle = (prevAngle + angle) * 0.5;
          final prevNoise = 1.0 + (rng.nextDouble() - 0.5) * 0.10;
          final cpx = cx + rx * prevNoise * math.cos(midAngle);
          final cpy = cy + ry * prevNoise * math.sin(midAngle);
          path.quadraticBezierTo(cpx, cpy, x, y);
        }
      }

      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopoPainter oldDelegate) =>
      oldDelegate.breathe != breathe ||
      oldDelegate.mousePos != mousePos ||
      oldDelegate.isDark != isDark ||
      (ripples.isNotEmpty && oldDelegate.time != time);
}

// ---------------------------------------------------------------------------
// Radial glow painter (soft green halo behind the search bar)
// ---------------------------------------------------------------------------

class _SearchGlowPainter extends CustomPainter {
  _SearchGlowPainter({this.mousePos, this.isDark = false});

  final Offset? mousePos;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = mousePos ?? Offset(size.width * 0.5, size.height * 0.55);
    const radius = 350.0;
    final glowColor = isDark ? const Color(0xFF4EBF75) : SupplyMapColors.accentGreen;
    final glowAlpha = isDark ? 0.25 : 0.18;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: glowAlpha),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SearchGlowPainter oldDelegate) =>
      oldDelegate.mousePos != mousePos || oldDelegate.isDark != isDark;
}

