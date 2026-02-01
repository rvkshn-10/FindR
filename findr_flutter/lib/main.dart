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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
          useMaterial3: true,
        ),
        home: const SearchScreen(),
      ),
    );
  }
}
