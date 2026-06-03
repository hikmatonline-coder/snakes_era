import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ad_helper.dart';
import '../core/ads_initializer.dart';

class AdProvider with ChangeNotifier {

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

  // State Variables
  DateTime? _lastAdTimestamp;
  int _dailyAdsWatched = 0;
  final int _maxDailyAds = 5;
  final int _cooldownSeconds = 30;
  bool _isAdLoading = false;

  // Exponential Backoff Retry tracking to satisfy Google Policies
  int _rewardedRetryAttempts = 0;
  int _interstitialRetryAttempts = 0;
  int _appOpenRetryAttempts = 0;

  // Getters
  bool get isAdLoading => _isAdLoading;
  int get dailyAdsWatched => _dailyAdsWatched;
  bool get reachedLimit => _dailyAdsWatched >= _maxDailyAds;
  InterstitialAd? get interstitialAd => _interstitialAd;

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

    String? lastDate = prefs.getString('last_ad_date');
    String today = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != today) {
      _dailyAdsWatched = 0;
      await prefs.setString('last_ad_date', today);
      await prefs.setInt('daily_ads_watched', 0);
    } else {
      _dailyAdsWatched = prefs.getInt('daily_ads_watched') ?? 0;
    }

    int? lastMillis = prefs.getInt('last_ad_timestamp');
    if (lastMillis != null) {
      _lastAdTimestamp = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    }

    await _startAdsWhenReady();

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

  // --- App Open Ad ---
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
          _appOpenRetryAttempts = 0; // Reset retry counter
          debugPrint('AppOpenAd loaded');
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _appOpenAdLoadTime = null;
          _isLoadingAppOpenAd = false;
          _logAd('AppOpenAd failed (${AdHelper.appOpenAdUnitId})', error: error);

          // Exponential backoff to prevent network flooding (Max 1 minute delay)
          _appOpenRetryAttempts++;
          int delaySeconds = (_appOpenRetryAttempts * 10).clamp(10, 60);
          Future.delayed(Duration(seconds: delaySeconds), loadAppOpenAd);
        },
      ),
    );
  }

  bool get _isAppOpenAdAvailable {
    if (_appOpenAd == null || _appOpenAdLoadTime == null) return false;
    return DateTime.now().difference(_appOpenAdLoadTime!) < _appOpenAdMaxCache;
  }

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
          _appOpenRetryAttempts = 0;
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

  // --- Interstitial Ad ---
  void loadInterstitialAd() {
    if (_interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialRetryAttempts = 0; // Reset retries
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _logAd('InterstitialAd failed (${AdHelper.interstitialAdUnitId})', error: error);
          _interstitialAd = null;

          _interstitialRetryAttempts++;
          int delaySeconds = (_interstitialRetryAttempts * 15).clamp(15, 120);
          Future.delayed(Duration(seconds: delaySeconds), loadInterstitialAd);
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
        completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        completer.complete();
      },
    );

    _interstitialAd!.show();
    return completer.future;
  }

  // --- Rewarded Ad ---
  void loadRewardedAd() {
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
          _rewardedRetryAttempts = 0; // Reset safe retries
          debugPrint("Rewarded Ad Loaded");
          notifyListeners();
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          _isAdLoading = false;
          _logAd('RewardedAd failed (${AdHelper.rewardedAdUnitId})', error: err);
          notifyListeners();

          // CRITICAL REVIEW FIX: Prevents rapid fires when network errors happen
          _rewardedRetryAttempts++;
          int delaySeconds = (_rewardedRetryAttempts * 15).clamp(15, 120);
          Future.delayed(Duration(seconds: delaySeconds), loadRewardedAd);
        },
      ),
    );
  }

  Future<void> showRewardedAd({required Function(AdWithoutView, RewardItem) onUserEarnedReward}) async {
    if (_rewardedAd == null) return;

    final adToShow = _rewardedAd;
    _rewardedAd = null; // Instantly dump pointer to prevent spam triggers

    _isAdLoading = true;
    notifyListeners();

    bool rewardedEarned = false;

    adToShow!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isAdLoading = false;
        notifyListeners();

        // CRITICAL FIX: Only kick-start cooldown here if the user backed out early.
        // If they completed the ad, _recordRewardSuccess handled the scheduling.
        if (!rewardedEarned) {
          Future.delayed(Duration(seconds: _cooldownSeconds), () => loadRewardedAd());
        }
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _isAdLoading = false;
        loadRewardedAd();
      },
    );

    await adToShow.show(onUserEarnedReward: (ad, reward) async {
      rewardedEarned = true; // Mark true so onAdDismissed doesn't double-call loader
      await _recordRewardSuccess();
      onUserEarnedReward(ad, reward);
    });
  }

  Future<void> _recordRewardSuccess() async {
    _lastAdTimestamp = DateTime.now();
    _dailyAdsWatched++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_ads_watched', _dailyAdsWatched);
    await prefs.setInt('last_ad_timestamp', _lastAdTimestamp!.millisecondsSinceEpoch);

    _rewardedAd = null;
    _isAdLoading = false;
    notifyListeners();

    // Safe cooldown execution
    Future.delayed(Duration(seconds: _cooldownSeconds), () {
      loadRewardedAd();
    });
  }
}