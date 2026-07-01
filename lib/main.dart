import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snakes_era/provider/ads_provider.dart';
import 'package:snakes_era/provider/review_provider.dart';
import 'package:snakes_era/provider/social_provider.dart';
import 'package:snakes_era/services/notification_services.dart';
import 'package:snakes_era/view/splash_screen.dart';
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

  // Notification Service initializer
  await NotificationService().initNotification();

  // Starting the App
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
        ChangeNotifierProvider(create: (_) => SocialProvider()),
      ],
      child: const QuantXGame(),
    ),
  );
}

class QuantXGame extends StatefulWidget {
  const QuantXGame({super.key});

  @override
  State<QuantXGame> createState() => _QuantXGameState();
}

class _QuantXGameState extends State<QuantXGame> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    // 🎯 Lifecycle changes track karne ke liye observer lazmi register hona chahiye
    WidgetsBinding.instance.addObserver(this);

    // Initial permissions trigger karo safely
    _initAppNotificationState();

    // 🔥 REAL TEST: App open hote hi 4 seconds baad direct notification phekega!
    Future.delayed(const Duration(seconds: 4), () {
      debugPrint("🚀 [FORCED TEST] Triggering actual leaderboard alert method...");

      // Aap ke exact notification service method ko test ke liye 1 second ke delay par fire kar rahe hain
      NotificationService().scheduleLeaderboardAlert(const Duration(seconds: 1));
    });
  }

  // ✅ Async initialization permissions smoothly mangne ke liye
  Future<void> _initAppNotificationState() async {
    try {
      // User ke samne Android 13+ ka permission pop-up pheko
      await NotificationService().requestNotificationPermission();

      // Purani background alerts saaf karo
      await _clearActiveNotifications();
    } catch (e) {
      debugPrint("Notification init error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint("🚨 [LIFECYCLE DETECTED]: App state is now -> $state");

    if (state == AppLifecycleState.paused) {
      // 🛑 JAB USER APP BAND KARE (Background mein jaye)
      debugPrint("📱 App went to background. Scheduling retention alerts...");

      // 1. 24 Ghante baad ka inactivity reminder schedule karein
      NotificationService().scheduleInactivityReminder();

      // 2. Leaderboard par active rakhne ke liye notification lagayein (e.g., 5 seconds baad)
      NotificationService().scheduleLeaderboardAlert(const Duration(seconds: 5));

    } else if (state == AppLifecycleState.resumed) {
      // 🚀 JAB USER APP WAPIS OPEN KARE (Foreground mein aaye)
      debugPrint("🎯 App resumed to foreground. Clearing passive alerts...");
      _clearActiveNotifications();
    }
  }

  // Async functions ko safely perform karne ke liye async lagaya hy
  Future<void> _clearActiveNotifications() async {
    // Jab user active ho jaye, to reminders ko cancel kar dein
    await NotificationService().cancel(NotificationService.idInactivity);
    await NotificationService().cancel(NotificationService.idLeaderboard);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AppOpenAdHandler(
            child: SplashScreen(),
          ),
        );
      },
    );
  }
}