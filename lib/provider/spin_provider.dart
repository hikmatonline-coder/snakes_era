import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/notification_services.dart';

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

    if (isNewDay) {
      _extraSpinsAvailable = 10;
      _nextAdSpinTime = null;
      await _storage.write(key: 'extra_spins', value: '10');
      await _storage.delete(key: 'next_ad_spin_time');

      // 🎯 Naya din shuru hote hi purana ad notification cancel karein aur naya Daily Reminder set karein
      NotificationService().cancel(NotificationService.idSpinWheel);
    } else {
      String? extra = await _storage.read(key: 'extra_spins');
      _extraSpinsAvailable = int.tryParse(extra ?? '10') ?? 10;

      String? nextAd = await _storage.read(key: 'next_ad_spin_time');
      if (nextAd != null) {
        _nextAdSpinTime = DateTime.parse(nextAd);
        _startCooldownTimer();
      }
    }

    // 🎯 Jab bhi user app kholay, usay pending Spin notification show na ho kyunke woh active hy
    NotificationService().cancel(NotificationService.idSpinWheel);

    notifyListeners();
  }

  void _startCooldownTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_nextAdSpinTime != null && DateTime.now().isAfter(_nextAdSpinTime!)) {
        _nextAdSpinTime = null;
        _ticker?.cancel();

        // Cooldown app ke andar hi khatam ho gaya, notification cancel kar dein
        NotificationService().cancel(NotificationService.idSpinWheel);
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

    int numberOfSlices = rewards.length;
    double sectorAngle = (2 * pi) / numberOfSlices;

    int winningIndex = (((2 * pi - _rotation) + (pi / 2)) % (2 * pi) / sectorAngle).floor();
    String result = rewards[winningIndex % numberOfSlices];

    // 3. Save State & Setup Notifications
    if (isDaily) {
      _canDailySpin = false;
      await _storage.write(key: 'last_daily_spin', value: DateTime.now().toIso8601String());

      // 🎯 Agle din (24 Hours baad) ke liye automatic Daily Reward Reminder schedule karein
      NotificationService().scheduleDailyReward(const Duration(hours: 24));
    } else {
      _extraSpinsAvailable--;
      _nextAdSpinTime = DateTime.now().add(const Duration(minutes: 4));
      await _storage.write(key: 'extra_spins', value: _extraSpinsAvailable.toString());

      // 🎯 4 Minutes ke exact cooldown ke baad automatic dynamic message send hoga!
      NotificationService().scheduleSpinWheel(const Duration(minutes: 4));

      _startCooldownTimer();
    }

    notifyListeners();
    return result;
  }
}