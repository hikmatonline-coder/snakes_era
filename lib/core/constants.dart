import 'package:flutter/material.dart';

class AppConstants {

  /// ------------------------ APP STRINGS ------------------------

  // App Name
  static const String appName = "Snakes Era";
  static const String appName2 = "Quant X";

  // Navigation Strings
  static const String navShop = "Shop";
  static const String navGames = "Games";
  static const String navSpin = "Daily Spin";
  static const String navRank = "Ranking";
  static const String navProfile = "Profile";

  // System Strings
  static const String gamesScreen = "DISCOVER GAMES";
  static const String gameOver = "Game Over";
  static const String retry = "Try Again";
  static const String backHome = "Back to Hub";
  static const String promoBanner = "PROMO BANNER AREA";
  static const String noLiveSheetReward = "REWARD GRANTED: +1 LIFE";

  // Auth Strings
  static const String authSlogan = "Sync your progress";
  static const String authButton = "Continue with google";
  static const String authTerms = "By signing in, you agree to our Terms of Service";
  static const String authWarning = "Authentication Failed. Check your connection.";

  // GAME SCREEN Strings
  static const String noLivesHeader = "SYSTEM OFFLINE";
  static const String noLivesBody = "Insufficient power to launch game. Initialize emergency bypass or wait for reboot.";
  static const String watchAdBtn = "WATCH AD (+1 LIFE)";
  static const String waitBtn = "I'LL WAIT";

  /// ------------------------ APP COLORS ------------------------
  // App Colors
  static const Color primaryColor = Colors.deepPurpleAccent;
  static const Color secPrimaryColor = Colors.cyanAccent;
  static const Color deepPurpleColor = Colors.deepPurpleAccent;
  static const Color backgroundColor = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color textMain = Colors.white;
  static const Color textDark = Colors.black;
  static const Color textWhite = Colors.white70;
  static const Color gameWhite = Colors.white;
  static const Color gameBlack = Colors.black;
  static const Color navBarUnSelectedItem = Colors.white24;
  static const Color warningRed = Colors.redAccent;

  // Game Specific Colors
  static const Color snakeGreen = Colors.greenAccent;
  static const Color puzzleOrange = Colors.orangeAccent;
  static const Color numberBlue = Colors.lightBlueAccent;

  /// ------------------------ APP INTS ------------------------
  // Game Configs
  static const int maxLives = 5;
  static const int coins = 100;
  static const int powerUps = 10;
  static const int lifeRegenSeconds = 300; // 5 minutes
  static const int adCooldownSeconds = 120; // 2 minutes
  static const int freeSpinCooldownHours = 3;

  /// ------------------------ APP STORAGE KEYS ------------------------
  // Storage Keys
  static const String keyToken = 'auth_token';
  static const String keyUser = 'user_data';
  static const String keyTheme = 'app_theme';
  static const String keyLives = 'user_lives';
  static const String keyLastRegen = 'last_regen_time';
}
