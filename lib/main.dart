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

  await Future.wait([
    Firebase.initializeApp(),
    AdsInitializer.instance.initialize(),
  ]);

  await NotificationService().initNotification();

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
    WidgetsBinding.instance.addObserver(this);
    _initAppNotificationState();
  }

  Future<void> _initAppNotificationState() async {
    try {
      final granted = await NotificationService().requestNotificationPermission();
      if (!granted) {
        debugPrint('Notification permission not granted.');
      }

      await _clearActiveNotifications();
    } catch (e) {
      debugPrint('Notification init error: $e');
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

    if (state == AppLifecycleState.paused) {
      NotificationService().scheduleInactivityReminder();
    } else if (state == AppLifecycleState.resumed) {
      _clearActiveNotifications();
    }
  }

  Future<void> _clearActiveNotifications() async {
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
