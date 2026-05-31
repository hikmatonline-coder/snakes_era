import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snakes_era/provider/ads_provider.dart';
import 'package:snakes_era/provider/review_provider.dart';
import 'auth/auth_wrapper.dart';
import 'core/ads_initializer.dart';
import 'core/constants.dart';
import 'core/widgets/app_open_ad_handler.dart';
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
    AdsInitializer.instance.initialize(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LifeProvider()),
        ChangeNotifierProvider(create: (_) => SpinProvider()),
        ChangeNotifierProvider(create: (_) => AdProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
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
          home: const AppOpenAdHandler(
            child: AuthWrapper(),
          ),
        );
      },
    );
  }
}