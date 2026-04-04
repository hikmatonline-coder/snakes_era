// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../core/ad_helper.dart';
//
// class AdProvider extends ChangeNotifier {
//
//   final _storage = const FlutterSecureStorage();
//
//   // --- Test Ad Unit IDs ---
//   final String _bannerId = "ca-app-pub-3940256099942544/6300978111";
//   final String _rewardedInterstitialId = "ca-app-pub-3940256099942544/5354046379";
//
//   // Ad objects
//   InterstitialAd? _interstitialAd;
//   RewardedAd? _rewardedAd;
//   RewardedInterstitialAd? _rewardedInterstitialAd;
//
//   // State Variables
//   DateTime? _lastAdTimestamp;
//   int _dailyAdsWatched = 0;
//   final int _maxDailyAds = 5;
//   final int _cooldownSeconds = 30;
//   bool _isAdLoading = false;
//
//   // Getters
//   bool get isAdLoading => _isAdLoading;
//   int get dailyAdsWatched => _dailyAdsWatched;
//   bool get reachedLimit => _dailyAdsWatched >= _maxDailyAds;
//   InterstitialAd? get interstitialAd => _interstitialAd;
//
//   // 1. Add this helper to check if an ad is ready to show
//   bool get isRewardedReady => _rewardedAd != null && secondsRemaining == 0 && !reachedLimit;
//
//   int get secondsRemaining {
//     if (_lastAdTimestamp == null) return 0;
//     final diff = DateTime.now().difference(_lastAdTimestamp!).inSeconds;
//     final remaining = _cooldownSeconds - diff;
//     return remaining > 0 ? remaining : 0;
//   }
//
//   AdProvider() {
//     _init();
//   }
//
//   Future<void> _init() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // 1. Daily Reset Logic
//     String? lastDate = prefs.getString('last_ad_date');
//     String today = DateTime.now().toIso8601String().split('T')[0];
//
//     if (lastDate != today) {
//       _dailyAdsWatched = 0;
//       await prefs.setString('last_ad_date', today);
//       await prefs.setInt('daily_ads_watched', 0);
//     } else {
//       _dailyAdsWatched = prefs.getInt('daily_ads_watched') ?? 0;
//     }
//
//     // 2. Load Cooldown Timestamp
//     int? lastMillis = prefs.getInt('last_ad_timestamp');
//     if (lastMillis != null) {
//       _lastAdTimestamp = DateTime.fromMillisecondsSinceEpoch(lastMillis);
//     }
//
//     // 3. Start Background Loading
//     _loadAllAds();
//
//     // 4. UI Refresh Ticker
//     Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (secondsRemaining > 0) notifyListeners();
//     });
//   }
//
//   void _loadAllAds() {
//     loadInterstitialAd();
//     _loadRewarded();
//     _loadRewardedInterstitial();
//   }
//
//   // --- 1. Banner Ad ---
//   BannerAd createBannerAd() {
//     return BannerAd(
//       adUnitId: _bannerId,
//       size: AdSize.banner,
//       request: const AdRequest(),
//       listener: BannerAdListener(
//         onAdFailedToLoad: (ad, error) {
//           debugPrint("Banner failed: $error");
//           ad.dispose();
//         },
//       ),
//     )..load();
//   }
//
//   // --- 2. Interstitial Ad ---
//   void loadInterstitialAd() {
//     if (_interstitialAd != null) return;
//
//     InterstitialAd.load(
//       adUnitId: AdHelper.interstitialAdUnitId,
//       request: const AdRequest(),
//       adLoadCallback: InterstitialAdLoadCallback(
//         onAdLoaded: (ad) {
//           _interstitialAd = ad;
//           notifyListeners();
//         },
//         onAdFailedToLoad: (error) {
//           debugPrint('InterstitialAd failed: $error');
//           _interstitialAd = null;
//         },
//       ),
//     );
//   }
//
//   Future<void> showInterstitialAd() async {
//     if (_interstitialAd == null) return;
//
//     final completer = Completer<void>();
//
//     _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
//       onAdDismissedFullScreenContent: (ad) {
//         ad.dispose();
//         _interstitialAd = null;
//         loadInterstitialAd();
//         completer.complete(); // This tells the game screen it's safe to resume
//       },
//       onAdFailedToShowFullScreenContent: (ad, err) {
//         ad.dispose();
//         completer.complete();
//       },
//     );
//
//     _interstitialAd!.show();
//     return completer.future;
//   }
//
//   // --- 3. Rewarded Ad (Main handler for NoLivesSheet) ---
//   void _loadRewarded() {
//     // If already loading, or we have an ad, or reached limit, don't trigger another fetch
//     if (_isAdLoading || _rewardedAd != null || reachedLimit) return;
//
//     _isAdLoading = true;
//     notifyListeners();
//
//     RewardedAd.load(
//       adUnitId: AdHelper.interstitialAdUnitId,
//       request: const AdRequest(),
//       rewardedAdLoadCallback: RewardedAdLoadCallback(
//         onAdLoaded: (ad) {
//           _rewardedAd = ad;
//           _isAdLoading = false;
//           debugPrint("Rewarded Ad Loaded");
//           notifyListeners();
//         },
//         onAdFailedToLoad: (err) {
//           _rewardedAd = null;
//           _isAdLoading = false;
//           debugPrint("Rewarded Ad Failed: $err");
//           notifyListeners();
//           // Optional: retry after 5 seconds if failed
//           Future.delayed(const Duration(seconds: 5), () => _loadRewarded());
//         },
//       ),
//     );
//   }
//
//   Future<bool> showRewarded() async {
//     if (!isRewardedReady) {
//       _loadRewarded();
//       return false;
//     }
//
//     Completer<bool> completer = Completer();
//
//     // 1. Assign the reference to a local variable
//     final adToShow = _rewardedAd;
//
//     // 2. IMMEDIATELY set the class variable to null
//     // This prevents other parts of the app from touching the same ad object
//     _rewardedAd = null;
//
//     adToShow!.fullScreenContentCallback = FullScreenContentCallback(
//       onAdDismissedFullScreenContent: (ad) {
//         ad.dispose();
//         _loadRewarded(); // Fetch the next one
//       },
//       onAdFailedToShowFullScreenContent: (ad, err) {
//         ad.dispose();
//         _loadRewarded();
//         if (!completer.isCompleted) completer.complete(false);
//       },
//     );
//
//     adToShow.show(onUserEarnedReward: (_, reward) async {
//       await _recordRewardSuccess();
//       if (!completer.isCompleted) completer.complete(true);
//     });
//
//     return completer.future;
//   }
//
//   // --- 4. Rewarded Interstitial ---
//   void _loadRewardedInterstitial() {
//     RewardedInterstitialAd.load(
//       adUnitId: _rewardedInterstitialId,
//       request: const AdRequest(),
//       rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
//         onAdLoaded: (ad) => _rewardedInterstitialAd = ad,
//         onAdFailedToLoad: (err) => _rewardedInterstitialAd = null,
//       ),
//     );
//   }
//
//   Future<bool> showRewardedInterstitial() async {
//     if (_rewardedInterstitialAd == null || reachedLimit) return false;
//     Completer<bool> completer = Completer();
//
//     await _rewardedInterstitialAd!.show(onUserEarnedReward: (_, reward) async {
//       await _recordRewardSuccess();
//       completer.complete(true);
//     });
//
//     _rewardedInterstitialAd = null;
//     _loadRewardedInterstitial();
//     return completer.future;
//   }
//
//   // --- Helper: Save States ---
//   Future<void> _recordRewardSuccess() async {
//     _lastAdTimestamp = DateTime.now();
//     _dailyAdsWatched++;
//
//     // Encrypted Write to Storage
//     await _storage.write(key: 'daily_ads_watched', value: _dailyAdsWatched.toString());
//     await _storage.write(
//         key: 'last_ad_timestamp',
//         value: _lastAdTimestamp!.millisecondsSinceEpoch.toString()
//     );
//
//     notifyListeners();
//   }
// }