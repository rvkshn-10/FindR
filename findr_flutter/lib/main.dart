import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'screens/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // App still runs without Firebase until you run: dart run flutterfire_cli:flutterfire configure
    debugPrint('Firebase init failed (run flutterfire configure): $e');
  }
  runApp(const FindRApp());
}

class FindRApp extends StatelessWidget {
  const FindRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: MaterialApp(
        title: 'FindR – Supply Map',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF534a3f)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFfefdfb),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shadowColor: Colors.transparent,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.brown.shade200),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              minimumSize: const Size(140, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        home: const SearchScreen(),
      ),
    );
  }
}
