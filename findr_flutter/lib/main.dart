import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'screens/app_shell.dart';
import 'widgets/design_system.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WayvioApp());
}

/// Strip/clamp text shadows to avoid blurRadius assertion (e.g. on hover).
/// Replaces shadows with empty list so no negative blurRadius can reach the engine.
TextStyle _noTextShadow(TextStyle s) {
  if (s.shadows == null || s.shadows!.isEmpty) return s;
  return s.copyWith(shadows: const <Shadow>[]);
}

/// Warm, cream-toned light theme (Scandinavian minimal).
ThemeData get _supplyMapTheme {
  final base = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);
  TextStyle safe(TextStyle? s) => s != null ? _noTextShadow(s) : const TextStyle();
  final textTheme = TextTheme(
    displayLarge: safe(base.displayLarge),
    displayMedium: safe(base.displayMedium),
    displaySmall: safe(base.displaySmall),
    headlineLarge: safe(base.headlineLarge),
    headlineMedium: safe(base.headlineMedium),
    headlineSmall: safe(base.headlineSmall),
    titleLarge: safe(base.titleLarge),
    titleMedium: safe(base.titleMedium),
    titleSmall: safe(base.titleSmall),
    bodyLarge: safe(base.bodyLarge),
    bodyMedium: safe(base.bodyMedium),
    bodySmall: safe(base.bodySmall),
    labelLarge: safe(base.labelLarge),
    labelMedium: safe(base.labelMedium),
    labelSmall: safe(base.labelSmall),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: SupplyMapColors.bodyBg,
    colorScheme: const ColorScheme.light(
      primary: SupplyMapColors.accentGreen,
      secondary: SupplyMapColors.purple,
      error: SupplyMapColors.red,
      surface: SupplyMapColors.sidebarBg,
      onSurface: SupplyMapColors.textBlack,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: SupplyMapColors.bodyBg,
      foregroundColor: SupplyMapColors.textBlack,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: _noTextShadow(GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: SupplyMapColors.textBlack,
      )),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SupplyMapColors.sidebarBg,
      contentTextStyle: _noTextShadow(
          GoogleFonts.outfit(color: SupplyMapColors.textBlack, fontSize: 14)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd)),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: _noTextShadow(GoogleFonts.outfit(
        color: SupplyMapColors.textBlack,
        fontSize: 12,
      )),
    ),
  );
}

class WayvioApp extends StatelessWidget {
  const WayvioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
      ],
      child: MaterialApp(
        title: 'Wayvio',
        theme: _supplyMapTheme,
        builder: (context, child) {
          // Force no text shadows app-wide to avoid blurRadius assertion on hover.
          final theme = Theme.of(context);
          return DefaultTextStyle(
            style: _noTextShadow(theme.textTheme.bodyLarge ?? const TextStyle()),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SupplyMapShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
