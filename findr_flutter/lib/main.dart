import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'screens/supply_map_shell.dart';
import 'widgets/liquid_glass_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed (run flutterfire configure): $e');
  }
  runApp(const FindRApp());
}

/// Distinctive typography: Fraunces (display serif) + Outfit (body).
TextTheme _creativeTextTheme(TextTheme base) {
  final display = GoogleFonts.fraunces(color: LiquidGlassColors.label);
  final body = GoogleFonts.outfit(color: LiquidGlassColors.label);
  final bodySecondary = GoogleFonts.outfit(color: LiquidGlassColors.labelSecondary);
  return base.copyWith(
    bodyLarge: body.copyWith(fontSize: 16),
    bodyMedium: body.copyWith(fontSize: 14),
    bodySmall: bodySecondary.copyWith(fontSize: 12),
    titleLarge: display.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: display.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
    titleSmall: display.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: bodySecondary.copyWith(fontSize: 12),
    labelSmall: bodySecondary.copyWith(fontSize: 11),
  );
}

/// Apple Liquid Glass–inspired theme with creative fonts.
ThemeData get _liquidGlassTheme {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LiquidGlassColors.primary,
      brightness: Brightness.light,
      primary: LiquidGlassColors.primary,
      surface: LiquidGlassColors.surfaceLight,
      onSurface: LiquidGlassColors.label,
      onSurfaceVariant: LiquidGlassColors.labelSecondary,
    ),
    scaffoldBackgroundColor: LiquidGlassColors.surfaceLight,
  );
  return base.copyWith(
    textTheme: _creativeTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: LiquidGlassColors.surfaceLight,
      foregroundColor: LiquidGlassColors.label,
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: LiquidGlassColors.label,
      ),
      iconTheme: const IconThemeData(color: LiquidGlassColors.label),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: LiquidGlassColors.glassFillLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: LiquidGlassColors.glassBorderLight, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.25),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.outfit(color: LiquidGlassColors.labelSecondary),
      labelStyle: GoogleFonts.outfit(color: LiquidGlassColors.label),
      floatingLabelStyle: GoogleFonts.outfit(color: LiquidGlassColors.label),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LiquidGlassColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(140, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LiquidGlassColors.label,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.5),
      selectedColor: LiquidGlassColors.primary.withValues(alpha: 0.4),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: GoogleFonts.outfit(color: LiquidGlassColors.label, fontSize: 12),
      secondaryLabelStyle: GoogleFonts.outfit(color: LiquidGlassColors.label),
    ),
    dividerColor: LiquidGlassColors.labelSecondary.withValues(alpha: 0.4),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return LiquidGlassColors.primary;
        return Colors.transparent;
      }),
      side: BorderSide(color: LiquidGlassColors.labelSecondary.withValues(alpha: 0.7)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: LiquidGlassColors.label,
      iconColor: LiquidGlassColors.label,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return LiquidGlassColors.primary;
        return LiquidGlassColors.labelSecondary;
      }),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: GoogleFonts.outfit(color: LiquidGlassColors.label),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.outfit(color: LiquidGlassColors.labelSecondary),
      ),
    ),
  );
}

class FindRApp extends StatelessWidget {
  const FindRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: MaterialApp(
        title: 'FindR – Supply Map',
        theme: _liquidGlassTheme,
        home: const _RootWithBackground(),
      ),
    );
  }
}

/// Ensures the first frame always paints a visible background (fixes white screen on Safari/local).
class _RootWithBackground extends StatelessWidget {
  const _RootWithBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: LiquidGlassColors.surfaceLight),
        const SupplyMapShell(),
      ],
    );
  }
}
