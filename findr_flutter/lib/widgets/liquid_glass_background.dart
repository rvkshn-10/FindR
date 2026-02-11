import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Design tokens from the HTML mockup
// ---------------------------------------------------------------------------

class SupplyMapColors {
  SupplyMapColors._();

  // Core palette
  static const Color red = Color(0xFFFF453A);
  static const Color yellow = Color(0xFFFFE681);
  static const Color purple = Color(0xFFC282FF);
  static const Color blue = Color(0xFF78B6FF);
  static const Color green = Color(0xFFC9F269);

  // Backgrounds
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color bodyBg = Color(0xFF05050C);

  // Glass
  static const Color glass = Color(0x26FFFFFF); // rgba(255,255,255,0.15)
  static const Color glassBorder = Color(0x33FFFFFF); // rgba(255,255,255,0.2)

  // Text
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textBlack = Color(0xFF1C1C1E);

  // Sidebar
  static const Color sidebarBg = Color(0xB314141A); // rgba(20,20,25,0.7)

  // Map area
  static const Color mapBg = Color(0xFF15151A);
}

// Radii
const double kRadiusLg = 24;
const double kRadiusMd = 16;
const double kRadiusSm = 8;
const double kRadiusPill = 999;
const double kBlurStrength = 30;

// Keep the old name so existing imports don't break.
typedef LiquidGlassColors = SupplyMapColors;

// ---------------------------------------------------------------------------
// Gradient background (purple, red, blue radial blobs)
// ---------------------------------------------------------------------------

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SupplyMapColors.bodyBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The three radial gradient blobs
          CustomPaint(
            painter: _GradientBlobPainter(),
            size: Size.infinite,
          ),
          child,
        ],
      ),
    );
  }
}

class _GradientBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Purple blob – top-left
    _drawBlob(
      canvas,
      Offset(size.width * 0.1, size.height * 0.1),
      math.max(size.width, size.height) * 0.4,
      SupplyMapColors.purple.withValues(alpha: 0.30),
    );
    // Red blob – bottom-right
    _drawBlob(
      canvas,
      Offset(size.width * 0.9, size.height * 0.8),
      math.max(size.width, size.height) * 0.4,
      SupplyMapColors.red.withValues(alpha: 0.20),
    );
    // Blue blob – center
    _drawBlob(
      canvas,
      Offset(size.width * 0.5, size.height * 0.5),
      math.max(size.width, size.height) * 0.6,
      SupplyMapColors.blue.withValues(alpha: 0.15),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: kBlurStrength, sigmaY: kBlurStrength),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? SupplyMapColors.glass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border
                ? Border.all(color: SupplyMapColors.glassBorder, width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
