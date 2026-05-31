import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';

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
    // Natural regen cap is maxLives; reward overfill above cap is kept.
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
    }
  }

  void addLives(int amount) {
    _lives += amount;

    if (_lives >= AppConstants.maxLives) {
      _lastRegen = null;
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
      notifyListeners();
      return true;
    }
    return false;
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
    notifyListeners();
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    super.dispose();
  }
}
