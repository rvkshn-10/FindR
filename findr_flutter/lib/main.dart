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
  final display = GoogleFonts.fraunces(color: LiquidGlassColors.onDarkLabel);
  final body = GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabel);
  final bodySecondary = GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabelSecondary);
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
      surface: Colors.transparent,
      onSurface: LiquidGlassColors.onDarkLabel,
      onSurfaceVariant: LiquidGlassColors.onDarkLabelSecondary,
    ),
    scaffoldBackgroundColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: _creativeTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: LiquidGlassColors.onDarkLabel,
      titleTextStyle: GoogleFonts.syne(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: LiquidGlassColors.onDarkLabel,
      ),
      iconTheme: const IconThemeData(color: LiquidGlassColors.onDarkLabel),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: LiquidGlassColors.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: LiquidGlassColors.glassBorder, width: 1),
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
      hintStyle: GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabelSecondary),
      labelStyle: GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabel),
      floatingLabelStyle: GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabel),
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
        foregroundColor: LiquidGlassColors.onDarkLabel,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.3),
      selectedColor: LiquidGlassColors.primary.withValues(alpha: 0.4),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabel, fontSize: 12),
      secondaryLabelStyle: GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabel),
    ),
    dividerColor: LiquidGlassColors.onDarkLabelSecondary.withValues(alpha: 0.4),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return LiquidGlassColors.primary;
        return Colors.transparent;
      }),
      side: BorderSide(color: LiquidGlassColors.onDarkLabelSecondary.withValues(alpha: 0.7)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: LiquidGlassColors.onDarkLabel,
      iconColor: LiquidGlassColors.onDarkLabel,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return LiquidGlassColors.primary;
        return LiquidGlassColors.onDarkLabelSecondary;
      }),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabel),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.outfit(color: LiquidGlassColors.onDarkLabelSecondary),
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
        home: const SupplyMapShell(),
      ),
    );
  }
}
