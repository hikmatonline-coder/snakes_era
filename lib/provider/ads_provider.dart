import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ad_helper.dart';
import '../core/ads_initializer.dart';

class AdProvider extends ChangeNotifier {

  static const String _appOpenCountKey = 'app_open_count';
  static const int _showAppOpenEveryNthOpen = 3;
  static const Duration _appOpenAdMaxCache = Duration(hours: 4);

  // Ad objects
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenAdLoadTime;
  bool _isLoadingAppOpenAd = false;
  bool _isShowingAppOpenAd = false;

  bool get isShowingAppOpenAd => _isShowingAppOpenAd;

  RewardedAd? get rewardedAd => _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;

  // State Variables
  DateTime? _lastAdTimestamp;
  int _dailyAdsWatched = 0;
  final int _maxDailyAds = 5;
  final int _cooldownSeconds = 30;
  bool _isAdLoading = false;

  // Getters
  bool get isAdLoading => _isAdLoading;
  int get dailyAdsWatched => _dailyAdsWatched;
  bool get reachedLimit => _dailyAdsWatched >= _maxDailyAds;
  InterstitialAd? get interstitialAd => _interstitialAd;

  // 1. Add this helper to check if an ad is ready to show
  bool get isRewardedReady => _rewardedAd != null && !reachedLimit;

  int get secondsRemaining {
    if (_lastAdTimestamp == null) return 0;
    final diff = DateTime.now().difference(_lastAdTimestamp!).inSeconds;
    final remaining = _cooldownSeconds - diff;
    return remaining > 0 ? remaining : 0;
  }

  AdProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Daily Reset Logic
    String? lastDate = prefs.getString('last_ad_date');
    String today = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != today) {
      _dailyAdsWatched = 0;
      await prefs.setString('last_ad_date', today);
      await prefs.setInt('daily_ads_watched', 0);
    } else {
      _dailyAdsWatched = prefs.getInt('daily_ads_watched') ?? 0;
    }

    // 2. Load Cooldown Timestamp
    int? lastMillis = prefs.getInt('last_ad_timestamp');
    if (lastMillis != null) {
      _lastAdTimestamp = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    }

    // 3. Load ads only after UMP + Mobile Ads SDK are ready
    await _startAdsWhenReady();

    // 4. UI Refresh Ticker
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 0) notifyListeners();
    });
  }

  Future<void> _startAdsWhenReady() async {
    await AdsInitializer.instance.ready;

    if (!AdsInitializer.instance.canRequestAds) {
      _logAd('Cannot request ads yet (consent pending). Retrying in 15s...');
      Future.delayed(const Duration(seconds: 15), () async {
        if (await ConsentInformation.instance.canRequestAds()) {
          _loadAllAds();
        }
      });
      return;
    }

    _logAd(
      'Loading ads (${AdHelper.isUsingProductionAds ? "PRODUCTION" : "TEST"} units)',
    );
    _loadAllAds();
  }

  void _loadAllAds() {
    if (!AdsInitializer.instance.canRequestAds) return;
    loadInterstitialAd();
    loadRewardedAd();
    loadAppOpenAd();
  }

  void _logAd(String message, {LoadAdError? error}) {
    developer.log(message, name: 'SnakesEraAds');
    if (error != null) {
      developer.log(
        'code=${error.code} domain=${error.domain} message=${error.message}',
        name: 'SnakesEraAds',
      );
    }
    if (kReleaseMode) {
      print('[SnakesEraAds] $message${error != null ? " | ${error.message}" : ""}');
    } else {
      debugPrint('[SnakesEraAds] $message${error != null ? " | $error" : ""}');
    }
  }

  // --- App Open Ad (every 3rd app open) ---
  void loadAppOpenAd() {
    if (_isLoadingAppOpenAd || _isAppOpenAdAvailable) return;

    _isLoadingAppOpenAd = true;

    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAdLoadTime = DateTime.now();
          _isLoadingAppOpenAd = false;
          debugPrint('AppOpenAd loaded');
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _appOpenAdLoadTime = null;
          _isLoadingAppOpenAd = false;
          _logAd('AppOpenAd failed (${AdHelper.appOpenAdUnitId})', error: error);
          Future.delayed(const Duration(seconds: 8), loadAppOpenAd);
        },
      ),
    );
  }

  bool get _isAppOpenAdAvailable {
    if (_appOpenAd == null || _appOpenAdLoadTime == null) return false;
    return DateTime.now().difference(_appOpenAdLoadTime!) < _appOpenAdMaxCache;
  }

  /// Called when the app enters foreground. Shows an app-open ad every 3rd open.
  Future<void> onAppOpen() async {
    if (_isShowingAppOpenAd) return;

    final prefs = await SharedPreferences.getInstance();
    final openCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_appOpenCountKey, openCount);

    debugPrint('App open count: $openCount');

    if (openCount % _showAppOpenEveryNthOpen != 0) {
      if (!_isAppOpenAdAvailable && !_isLoadingAppOpenAd) {
        loadAppOpenAd();
      }
      return;
    }

    await _showAppOpenAdIfAvailable();
  }

  Future<void> _showAppOpenAdIfAvailable() async {
    if (_isShowingAppOpenAd) return;

    if (!_isAppOpenAdAvailable) {
      await _loadAndShowAppOpenAd();
      return;
    }

    _isShowingAppOpenAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AppOpenAd showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        _isShowingAppOpenAd = false;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: $error');
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        _isShowingAppOpenAd = false;
        loadAppOpenAd();
      },
    );

    await _appOpenAd!.show();
  }

  Future<void> _loadAndShowAppOpenAd() async {
    if (_isLoadingAppOpenAd || _isShowingAppOpenAd) return;

    final completer = Completer<void>();
    _isLoadingAppOpenAd = true;

    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAdLoadTime = DateTime.now();
          _isLoadingAppOpenAd = false;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _appOpenAdLoadTime = null;
          _isLoadingAppOpenAd = false;
          _logAd('AppOpenAd on-demand failed', error: error);
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    await completer.future;

    if (_isAppOpenAdAvailable) {
      await _showAppOpenAdIfAvailable();
    }
  }

  // --- 1. Banner Ad ---
  // BannerAd createBannerAd() {
  //   return BannerAd(
  //     adUnitId: _bannerId,
  //     size: AdSize.banner,
  //     request: const AdRequest(),
  //     listener: BannerAdListener(
  //       onAdFailedToLoad: (ad, error) {
  //         debugPrint("Banner failed: $error");
  //         ad.dispose();
  //       },
  //     ),
  //   )..load();
  // }

  // --- 2. Interstitial Ad ---
  void loadInterstitialAd() {
    if (_interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _logAd('InterstitialAd failed (${AdHelper.interstitialAdUnitId})', error: error);
          _interstitialAd = null;
          Future.delayed(const Duration(seconds: 8), loadInterstitialAd);
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null) return;

    final completer = Completer<void>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        completer.complete(); // This tells the game screen it's safe to resume
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        completer.complete();
      },
    );

    _interstitialAd!.show();
    return completer.future;
  }

  // --- 3. Rewarded Ad (Main handler for NoLivesSheet) ---
  void loadRewardedAd() {
    // If already loading, or we have an ad, or reached limit, don't trigger another fetch
    if (_isAdLoading || _rewardedAd != null || reachedLimit) return;

    _isAdLoading = true;
    notifyListeners();

    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          debugPrint("Rewarded Ad Loaded");
          notifyListeners();
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          _isAdLoading = false;
          _logAd('RewardedAd failed (${AdHelper.rewardedAdUnitId})', error: err);
          notifyListeners();
          Future.delayed(const Duration(seconds: 8), loadRewardedAd);
        },
      ),
    );
  }

  Future<void> showRewardedAd({required Function(AdWithoutView, RewardItem) onUserEarnedReward}) async {
    if (_rewardedAd == null) return;

    final adToShow = _rewardedAd;
    _rewardedAd = null; // Clear immediately to prevent double-tap issues

    _isAdLoading = true;
    notifyListeners();

    adToShow!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isAdLoading = false;
        // Start cooldown then reload
        Future.delayed(Duration(seconds: _cooldownSeconds), () => loadRewardedAd());
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _isAdLoading = false;
        loadRewardedAd();
      },
    );

    // Use the callback passed from the Game Screen
    await adToShow.show(onUserEarnedReward: (ad, reward) async {
      await _recordRewardSuccess();
      onUserEarnedReward(ad, reward); // Execute the revive or double score logic
    });
  }

  // --- 4. Rewarded Interstitial ---
  // void _loadRewardedInterstitial() {
  //   RewardedInterstitialAd.load(
  //     adUnitId: _rewardedInterstitialId,
  //     request: const AdRequest(),
  //     rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
  //       onAdLoaded: (ad) => _rewardedInterstitialAd = ad,
  //       onAdFailedToLoad: (err) => _rewardedInterstitialAd = null,
  //     ),
  //   );
  // }
  //
  // Future<bool> showRewardedInterstitial() async {
  //   if (_rewardedInterstitialAd == null || reachedLimit) return false;
  //   Completer<bool> completer = Completer();
  //
  //   await _rewardedInterstitialAd!.show(onUserEarnedReward: (_, reward) async {
  //     await _recordRewardSuccess();
  //     completer.complete(true);
  //   });
  //
  //   _rewardedInterstitialAd = null;
  //   _loadRewardedInterstitial();
  //   return completer.future;
  // }

  // --- Helper: Save States ---
  // Inside AdProvider.dart

  Future<void> _recordRewardSuccess() async {
    _lastAdTimestamp = DateTime.now();
    _dailyAdsWatched++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_ads_watched', _dailyAdsWatched);
    await prefs.setInt('last_ad_timestamp', _lastAdTimestamp!.millisecondsSinceEpoch);

    // 2. Clear the current ad
    _rewardedAd = null;

    // 3. WAIT before loading the next ad (The 20-30s cooldown you requested)
    // This prevents spamming the Google Servers
    notifyListeners();

    Future.delayed(Duration(seconds: _cooldownSeconds), () {
      loadRewardedAd();
    });
  }
}