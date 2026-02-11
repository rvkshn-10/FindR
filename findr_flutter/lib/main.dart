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

/// Strip/clamp text shadows to avoid blurRadius assertion (e.g. on hover).
/// Replaces shadows with empty list so no negative blurRadius can reach the engine.
TextStyle _noTextShadow(TextStyle s) {
  if (s.shadows == null || s.shadows!.isEmpty) return s;
  return s.copyWith(shadows: const <Shadow>[]);
}

/// Dark theme that matches the HTML hackathon design.
ThemeData get _supplyMapTheme {
  final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
  final textTheme = TextTheme(
    displayLarge: _noTextShadow(base.displayLarge!),
    displayMedium: _noTextShadow(base.displayMedium!),
    displaySmall: _noTextShadow(base.displaySmall!),
    headlineLarge: _noTextShadow(base.headlineLarge!),
    headlineMedium: _noTextShadow(base.headlineMedium!),
    headlineSmall: _noTextShadow(base.headlineSmall!),
    titleLarge: _noTextShadow(base.titleLarge!),
    titleMedium: _noTextShadow(base.titleMedium!),
    titleSmall: _noTextShadow(base.titleSmall!),
    bodyLarge: _noTextShadow(base.bodyLarge!),
    bodyMedium: _noTextShadow(base.bodyMedium!),
    bodySmall: _noTextShadow(base.bodySmall!),
    labelLarge: _noTextShadow(base.labelLarge!),
    labelMedium: _noTextShadow(base.labelMedium!),
    labelSmall: _noTextShadow(base.labelSmall!),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SupplyMapColors.bodyBg,
    colorScheme: const ColorScheme.dark(
      primary: SupplyMapColors.blue,
      secondary: SupplyMapColors.purple,
      error: SupplyMapColors.red,
      surface: SupplyMapColors.darkBg,
      onSurface: SupplyMapColors.textWhite,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: SupplyMapColors.bodyBg,
      foregroundColor: SupplyMapColors.textWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: _noTextShadow(GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: SupplyMapColors.textWhite,
      )),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SupplyMapColors.sidebarBg,
      contentTextStyle:
          _noTextShadow(GoogleFonts.inter(color: Colors.white, fontSize: 14)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd)),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: _noTextShadow(GoogleFonts.inter(
        color: Colors.white,
        fontSize: 12,
      )),
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
        theme: _supplyMapTheme,
        builder: (context, child) {
          // Force no text shadows app-wide to avoid blurRadius assertion on hover.
          final theme = Theme.of(context);
          return DefaultTextStyle(
            style: _noTextShadow(theme.textTheme.bodyLarge!),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SupplyMapShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
