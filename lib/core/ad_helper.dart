import 'package:flutter/foundation.dart';

class AdHelper {
  /// Set `--dart-define=USE_TEST_ADS=true` to force test units in release builds.
  static const bool _useTestAdsInRelease =
      bool.fromEnvironment('USE_TEST_ADS', defaultValue: false);

  static bool get _useProductionAds => kReleaseMode && !_useTestAdsInRelease;
  // --- REAL IDS (Replace these with IDs from AdMob Console) ---
  static const String _androidRealRewardedID = "ca-app-pub-2435287255767686/4897434577";
  static const String _androidRealInterstitialID = "ca-app-pub-2435287255767686/3177158797";
  static const String _androidRealAppOpenID = "ca-app-pub-2435287255767686/5883213185";

  // --- TEST IDS (Google's Official IDs) ---
  static const String _androidTestRewardedID = "ca-app-pub-3940256099942544/5224354917";
  static const String _androidTestInterstitialID = "ca-app-pub-3940256099942544/1033173712";
  static const String _androidTestAppOpenID = "ca-app-pub-3940256099942544/9257395921";

  // REWARDED LOGIC
  static String get rewardedAdUnitId =>
      _useProductionAds ? _androidRealRewardedID : _androidTestRewardedID;

  static String get interstitialAdUnitId =>
      _useProductionAds ? _androidRealInterstitialID : _androidTestInterstitialID;

  static String get appOpenAdUnitId =>
      _useProductionAds ? _androidRealAppOpenID : _androidTestAppOpenID;

  static bool get isUsingProductionAds => _useProductionAds;
}