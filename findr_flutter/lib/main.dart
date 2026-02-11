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

/// Dark theme that matches the HTML hackathon design.
ThemeData get _supplyMapTheme {
  final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
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
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: SupplyMapColors.textWhite,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SupplyMapColors.sidebarBg,
      contentTextStyle:
          GoogleFonts.inter(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd)),
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
        home: const SupplyMapShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
