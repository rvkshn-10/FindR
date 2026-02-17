import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/app_shell.dart';
import 'widgets/design_system.dart';

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

/// Warm, cream-toned light theme (Scandinavian minimal).
ThemeData get _supplyMapTheme {
  final base = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);
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

class FindRApp extends StatelessWidget {
  const FindRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'FindR',
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
