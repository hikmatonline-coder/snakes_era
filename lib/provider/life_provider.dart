import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

class LifeProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  int _lives = AppConstants.maxLives;
  DateTime? _lastRegen;
  Timer? _regenTimer;

  int get lives => _lives;

  // Formatted string for the UI (e.g., 04:59)
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

  Future<void> _init() async {
    String? livesStr = await _storage.read(key: AppConstants.keyLives);
    _lives = int.tryParse(livesStr ?? '') ?? AppConstants.maxLives;

    String? lastRegenStr = await _storage.read(key: AppConstants.keyLastRegen);
    if (lastRegenStr != null) {
      _lastRegen = DateTime.fromMillisecondsSinceEpoch(int.parse(lastRegenStr));
      _checkRegen();
    }
    _startTimer();
  }

  void _startTimer() {
    _regenTimer?.cancel();
    _regenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkRegen();
      notifyListeners();
    });
  }

  void _checkRegen() {
    // If we are overfilled (e.g., 10/5 lives), we don't regen and don't need a timer
    if (_lives >= AppConstants.maxLives) {
      _lastRegen = null;
      return;
    }

    _lastRegen ??= DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(_lastRegen!).inSeconds;

    if (difference >= AppConstants.lifeRegenSeconds) {
      final livesToGain = difference ~/ AppConstants.lifeRegenSeconds;
      // Note: We clamp here so natural regen doesn't push you over the cap
      _lives = (_lives + livesToGain).clamp(0, AppConstants.maxLives);
      _lastRegen = now.subtract(Duration(seconds: difference % AppConstants.lifeRegenSeconds));
      _saveState();
    }
  }

  // UPDATED: This allows for "Overfilling" lives from rewards
  void addLives(int amount) {
    _lives += amount; // No clamp here! If they win 50, they keep 50.

    // Stop regen if we are above or at max
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
    await _storage.write(key: AppConstants.keyLives, value: _lives.toString());
    if (_lastRegen != null) {
      await _storage.write(key: AppConstants.keyLastRegen, value: _lastRegen!.millisecondsSinceEpoch.toString());
    }
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    super.dispose();
  }
}