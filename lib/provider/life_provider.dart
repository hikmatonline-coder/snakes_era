import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';
import '../services/notification_services.dart';

class LifeProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _lives = AppConstants.maxLives;
  DateTime? _lastRegen;
  Timer? _regenTimer;
  bool _remoteLoaded = false;

  int get lives => _lives;
  bool get remoteLoaded => _remoteLoaded;

  String get timeUntilNextLifeStr {
    final duration = timeUntilNextLife;
    if (duration == Duration.zero) return "FULL";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  Duration get timeUntilNextLife {
    if (_lives >= AppConstants.maxLives || _lastRegen == null) return Duration.zero;
    final nextRegen = _lastRegen!.add(const Duration(seconds: AppConstants.lifeRegenSeconds));
    final diff = nextRegen.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  LifeProvider() {
    _init();
  }

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  Future<void> _init() async {
    _startTimer();
  }

  /// Loads lives and regen timer from Firestore. Call after login.
  Future<void> loadRemoteUserData() async {
    final docRef = _userDoc;
    if (docRef == null) return;

    try {
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final remoteLives = (data['lives'] as num?)?.toInt();

        if (remoteLives != null) {
          _lives = remoteLives;
        } else {
          await _migrateFromLocalStorage();
        }

        final lastRegenMs = data['lastRegenMs'];
        if (lastRegenMs is int) {
          _lastRegen = DateTime.fromMillisecondsSinceEpoch(lastRegenMs);
        } else {
          _lastRegen = null;
        }
      } else {
        await _migrateFromLocalStorage();
        await _ensureDefaultLivesOnFirestore();
      }

      _applyMaxLivesCapOnLoad();
      _checkRegen();
      await _clearLocalLifeStorage();
      _remoteLoaded = true;

      // 🎯 Safe Check: Agar data load hone par lives already full hain, to pending notification hata do
      if (_lives >= AppConstants.maxLives) {
        NotificationService().cancel(NotificationService.idLivesFull);
      }
    } catch (e) {
      debugPrint('Failed to load lives from Firestore: $e');
      await _migrateFromLocalStorage();
      _applyMaxLivesCapOnLoad();
      _checkRegen();
    }

    notifyListeners();
  }

  Future<void> _migrateFromLocalStorage() async {
    final livesStr = await _storage.read(key: AppConstants.keyLives);
    final lastRegenStr = await _storage.read(key: AppConstants.keyLastRegen);

    if (livesStr != null) {
      _lives = int.tryParse(livesStr) ?? AppConstants.maxLives;
    } else {
      _lives = AppConstants.maxLives;
    }

    if (lastRegenStr != null) {
      _lastRegen = DateTime.fromMillisecondsSinceEpoch(int.parse(lastRegenStr));
    }
  }

  void _applyMaxLivesCapOnLoad() {
    if (_lives > AppConstants.maxLives && _lives <= 7) {
      _lives = AppConstants.maxLives;
    }
  }

  Future<void> _ensureDefaultLivesOnFirestore() async {
    final docRef = _userDoc;
    if (docRef == null) return;

    await docRef.set({
      'lives': _lives,
      'lastRegenMs': _lastRegen?.millisecondsSinceEpoch,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _clearLocalLifeStorage() async {
    await _storage.delete(key: AppConstants.keyLives);
    await _storage.delete(key: AppConstants.keyLastRegen);
  }

  void _startTimer() {
    _regenTimer?.cancel();
    _regenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkRegen();
      notifyListeners();
    });
  }

  void _checkRegen() {
    if (_lives >= AppConstants.maxLives) {
      _lastRegen = null;
      return;
    }

    _lastRegen ??= DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(_lastRegen!).inSeconds;

    if (difference >= AppConstants.lifeRegenSeconds) {
      final livesToGain = difference ~/ AppConstants.lifeRegenSeconds;
      _lives = (_lives + livesToGain).clamp(0, AppConstants.maxLives);
      _lastRegen = now.subtract(Duration(seconds: difference % AppConstants.lifeRegenSeconds));
      _saveState();

      // 🎯 Check if lives became full after this incremental step
      if (_lives >= AppConstants.maxLives) {
        NotificationService().cancel(NotificationService.idLivesFull);
      }
    }
  }

  void addLives(int amount) {
    _lives += amount;

    if (_lives >= AppConstants.maxLives) {
      _lastRegen = null;
      // 🎯 Health full ho chuki hy, kisi notification ki zaroorat nahi abhi
      NotificationService().cancel(NotificationService.idLivesFull);
    } else {
      // Remaining recovery duration re-schedule karein
      _scheduleRechargeNotification();
    }

    _saveState();
    notifyListeners();
  }

  Future<bool> consumeLife() async {
    if (_lives > 0) {
      if (_lives == AppConstants.maxLives) {
        _lastRegen = DateTime.now();
      }
      _lives--;
      await _saveState();

      // 🎯 Jab bhi life use ho, calculated delay ke sath notification throw karo
      _scheduleRechargeNotification();

      notifyListeners();
      return true;
    }
    return false;
  }

  // 🎯 HELPER TO CALCULATE AND SCHEDULE LIVES REMINDER
  void _scheduleRechargeNotification() {
    if (_lives >= AppConstants.maxLives) return;

    // Har missing life ka delta convert karein seconds mein
    int missingLives = AppConstants.maxLives - _lives;
    int secondsToFull = (missingLives * AppConstants.lifeRegenSeconds);

    // Pehle segment ka calculated duration minus karein jo timer already chal chuka hy
    if (_lastRegen != null) {
      final elapsed = DateTime.now().difference(_lastRegen!).inSeconds;
      secondsToFull -= elapsed;
    }

    if (secondsToFull > 0) {
      NotificationService().scheduleLivesFull(Duration(seconds: secondsToFull));
    }
  }

  Future<void> _saveState() async {
    final docRef = _userDoc;
    if (docRef == null) return;

    try {
      await docRef.set({
        'lives': _lives,
        'lastRegenMs': _lastRegen?.millisecondsSinceEpoch,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync lives to Firestore: $e');
    }
  }

  void resetLocalState() {
    _lives = AppConstants.maxLives;
    _lastRegen = null;
    _remoteLoaded = false;
    NotificationService().cancel(NotificationService.idLivesFull);
    notifyListeners();
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    super.dispose();
  }
}