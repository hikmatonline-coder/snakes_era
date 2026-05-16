import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SpinProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  // State Variables
  double _rotation = 0;
  bool _isSpinning = false;
  bool _canDailySpin = false;
  int _extraSpinsAvailable = 5;
  DateTime? _nextAdSpinTime;
  Timer? _ticker;

  // Getters
  double get rotation => _rotation;
  bool get isSpinning => _isSpinning;
  bool get canDailySpin => _canDailySpin;
  int get extraSpinsAvailable => _extraSpinsAvailable;

  String get cooldownText {
    if (_nextAdSpinTime == null) return "";
    final diff = _nextAdSpinTime!.difference(DateTime.now());
    return diff.isNegative ? "" : "${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  SpinProvider() {
    _init();
  }

  Future<void> _init() async {
    final now = DateTime.now();
    String? lastDaily = await _storage.read(key: 'last_daily_spin');

    // Check if it's a new day
    bool isNewDay = false;
    if (lastDaily == null) {
      isNewDay = true;
      _canDailySpin = true;
    } else {
      final lastDate = DateTime.parse(lastDaily);
      isNewDay = lastDate.day != now.day || lastDate.month != now.month || lastDate.year != now.year;
      _canDailySpin = isNewDay;
    }

    // --- THE FIX ---
    if (isNewDay) {
      // If it's a new day, reset extra spins and clear cooldowns
      _extraSpinsAvailable = 10;
      _nextAdSpinTime = null;
      await _storage.write(key: 'extra_spins', value: '10');
      await _storage.delete(key: 'next_ad_spin_time');
    } else {
      // If same day, load existing progress
      String? extra = await _storage.read(key: 'extra_spins');
      _extraSpinsAvailable = int.tryParse(extra ?? '10') ?? 10;

      String? nextAd = await _storage.read(key: 'next_ad_spin_time');
      if (nextAd != null) {
        _nextAdSpinTime = DateTime.parse(nextAd);
        _startCooldownTimer();
      }
    }

    notifyListeners();
  }

  void _startCooldownTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_nextAdSpinTime != null && DateTime.now().isAfter(_nextAdSpinTime!)) {
        _nextAdSpinTime = null;
        _ticker?.cancel();
      }
      notifyListeners();
    });
  }

  // The Spin Logic
  Future<String?> spin(AnimationController controller, List<String> rewards, bool isDaily) async {
    if (_isSpinning) return null;
    _isSpinning = true;
    notifyListeners();

    // 1. Calculate rotation
    double totalSpinAngle = (2 * pi * 10) + (Random().nextDouble() * 2 * pi);
    double startAngle = _rotation;
    double endAngle = _rotation + totalSpinAngle;

    final animation = CurvedAnimation(parent: controller, curve: Curves.easeOutExpo);

    controller.addListener(() {
      _rotation = lerpDouble(startAngle, endAngle, animation.value)!;
      notifyListeners();
    });

    await controller.forward(from: 0);

    // 2. Determine Winning Slice
    _rotation = endAngle % (2 * pi);
    _isSpinning = false;

    // The arrow is at the bottom (pi), so we calculate relative to that
    int numberOfSlices = rewards.length;
    double sectorAngle = (2 * pi) / numberOfSlices;

    // Adjusted calculation to find what is at the pointer
    int winningIndex = (((2 * pi - _rotation) + (pi / 2)) % (2 * pi) / sectorAngle).floor();
    String result = rewards[winningIndex % numberOfSlices];

    // 3. Save State
    if (isDaily) {
      _canDailySpin = false;
      await _storage.write(key: 'last_daily_spin', value: DateTime.now().toIso8601String());
    } else {
      _extraSpinsAvailable--;
      _nextAdSpinTime = DateTime.now().add(const Duration(minutes: 4));
      await _storage.write(key: 'extra_spins', value: _extraSpinsAvailable.toString());
      _startCooldownTimer();
    }

    notifyListeners();
    return result; // Return the winning string
  }
}