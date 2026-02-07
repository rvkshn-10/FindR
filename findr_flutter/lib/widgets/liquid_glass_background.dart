import 'dart:ui';
import 'package:flutter/material.dart';

/// Earth-from-space background with gradient overlay for Liquid Glass look.
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  static const String _backgroundAsset = 'assets/earth_from_space.png';

  const LiquidGlassBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: LiquidGlassColors.surfaceLight),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Frosted glass bar for the app bar area so title/actions are easily visible.
class LiquidGlassAppBarBar extends StatelessWidget {
  const LiquidGlassAppBarBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: LiquidGlassColors.glassFill,
            border: Border(
              bottom: BorderSide(color: LiquidGlassColors.glassBorder, width: 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass card: blur + semi-transparent fill (Apple Liquid Glass style).
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blurSigma;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.blurSigma = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: LiquidGlassColors.glassFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: LiquidGlassColors.glassBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Apple Liquid Glass–style color palette (public for theme use).
/// Use onDark* for text on the Earth/space background.
class LiquidGlassColors {
  LiquidGlassColors._();

  static const Color surfaceLight = Color(0xFFF5F5F7);
  static const Color glassFill = Color(0x28FFFFFF);
  static const Color glassBorder = Color(0x32FFFFFF);
  static const Color primary = Color(0xFF007AFF);
  static const Color label = Color(0xFF1D1D1F);
  static const Color labelSecondary = Color(0xFF6E6E73);
  /// Text on dark background (Earth image).
  static const Color onDarkLabel = Color(0xFFFFFFFF);
  static const Color onDarkLabelSecondary = Color(0xFFE5E5EA);
}
