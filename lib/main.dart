import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'auth/auth_wrapper.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'provider/life_provider.dart';
import 'provider/snake_game_provider.dart';
import 'provider/spin_provider.dart';
import 'provider/theme_provider.dart';
import 'provider/auth_provider.dart';
import 'provider/user_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Services in parallel for faster startup
  await Future.wait([
    Firebase.initializeApp(),
    // MobileAds.instance.initialize(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LifeProvider()),
        ChangeNotifierProvider(create: (_) => SpinProvider()),
        // ChangeNotifierProvider(create: (_) => AdProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SnakeGameProvider()),
      ],
      child: const QuantXGame(),
    ),
  );
}

class QuantXGame extends StatelessWidget {
  const QuantXGame({super.key});

  @override
  Widget build(BuildContext context) {
    // Using Consumer is better for performance at the root level
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Theme Configuration
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

          // Navigation
          home: const AuthWrapper(),
        );
      },
    );
  }
}