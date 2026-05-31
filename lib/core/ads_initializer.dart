import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Bootstraps UMP consent + Mobile Ads SDK before any ad loads.
class AdsInitializer {
  AdsInitializer._();

  static final AdsInitializer instance = AdsInitializer._();

  final Completer<void> _ready = Completer<void>();
  bool _canRequestAds = false;
  bool _started = false;

  Future<void> get ready => _ready.future;

  bool get canRequestAds => _canRequestAds;

  Future<void> initialize() async {
    if (_started) return _ready.future;
    _started = true;

    try {
      await _gatherConsent();
      final status = await MobileAds.instance.initialize();
      _logAdapterStatus(status);
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      _log('Mobile Ads ready. canRequestAds=$_canRequestAds');
    } catch (e, st) {
      _log('Ads init failed: $e', error: e, stackTrace: st);
      try {
        await MobileAds.instance.initialize();
        _canRequestAds = true;
      } catch (inner) {
        _log('Mobile Ads fallback init failed: $inner');
        _canRequestAds = false;
      }
    } finally {
      if (!_ready.isCompleted) {
        _ready.complete();
      }
    }

    return _ready.future;
  }

  Future<void> _gatherConsent() async {
    final params = ConsentRequestParameters();

    final consentCompleter = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) {
            _log('Consent form error: ${error.errorCode} ${error.message}');
          }
          if (!consentCompleter.isCompleted) {
            consentCompleter.complete();
          }
        });
      },
      (FormError error) {
        _log('Consent info update failed: ${error.errorCode} ${error.message}');
        if (!consentCompleter.isCompleted) {
          consentCompleter.complete();
        }
      },
    );

    await consentCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _log('Consent flow timed out — continuing');
      },
    );

    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _log('After consent: canRequestAds=$_canRequestAds');
  }

  void _logAdapterStatus(InitializationStatus status) {
    status.adapterStatuses.forEach((name, adapterStatus) {
      _log(
        'Adapter $name: ${adapterStatus.state.name} '
        'desc=${adapterStatus.description} '
        'latency=${adapterStatus.latency}ms',
      );
    });
  }

  void _log(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'SnakesEraAds',
      error: error,
      stackTrace: stackTrace,
    );
    if (kReleaseMode) {
      // Visible in `adb logcat` for release builds.
      print('[SnakesEraAds] $message');
    }
  }
}
