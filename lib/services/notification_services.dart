import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _androidImplementation =>
      _localNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static const int idSpinWheel = 101;
  static const int idDailyReward = 202;
  static const int idLivesFull = 303;
  static const int idInactivity = 404;
  static const int idLeaderboard = 505;

  final List<Map<String, String>> _spinStrings = [
    {
      'title': '⚡ Free Spin Ready!',
      'body':
          'Ustad g, kismat aazmaein! Wheel ghumaein aur mega rewards jeetein.',
    },
    {
      'title': '🎁 Your Gift is Waiting!',
      'body':
          'Spin wheel ready ho chuka hy. Dekhein aaj aap jackpot jeet-te hain ya nahi!',
    },
    {
      'title': '🎡 Wheel of Fortune!',
      'body':
          'Coins aur Power ups chahiye? Aein aur apna free spin claim karein!',
    },
  ];

  final List<Map<String, String>> _dailyRewardStrings = [
    {
      'title': '📆 Daily Reward Claim!',
      'body':
          'Naya din, naya inaam! App open karein aur apna daily bonus collect karein.',
    },
    {
      'title': '💰 Free Coins Inside!',
      'body': 'Ustad g, aaj ka reward miss mat karein. Streak toot jayegi!',
    },
  ];

  final List<Map<String, String>> _livesFullStrings = [
    {
      'title': '❤️ Lives Fully Recharged!',
      'body':
          'Aap ki zindagiyan wapis full ho gayi hain. Chalein naya high score banayein!',
    },
    {
      'title': '🎮 Ready for Battle?',
      'body': 'Full health alert! Snake arena aap ka intezar kar raha hy.',
    },
  ];

  final List<Map<String, String>> _inactivityStrings = [
    {
      'title': '🐍 Snake Arena is Lonely...',
      'body':
          'Ustad g, 24 ghante ho gaye aap se mulaqat nahi hui. Aein ek match lagayein!',
    },
    {
      'title': '👑 Court Is Waiting for the King!',
      'body':
          'Kahan hain aap? Saanp bhookay hain aur arena khali hy. Wapis aein!',
    },
    {
      'title': "🔥 Don't Lose Your Touch!",
      'body':
          'Aap ki absence ka faida baqi players utha rahe hain. Come back now!',
    },
  ];

  final List<Map<String, String>> _leaderboardStrings = [
    {
      'title': '🏆 Leaderboard Danger!',
      'body':
          'Ustad g, koi aap ka record todne ki koshish kar raha hy. Top par raaj qaim rakhein!',
    },
    {
      'title': '🥇 Aim for Number 1!',
      'body': 'Leaderboard par naye challenges aa gaye hain. Beat them all!',
    },
  ];

  Future<void> initNotification() async {
    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    final initialized = await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification clicked. Payload: ${details.payload}');
      },
    );

    if (initialized != true) {
      debugPrint('Local notifications failed to initialize.');
      return;
    }

    _initialized = true;
    await _createAndroidChannels();
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Failed to set local timezone, falling back to UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _createAndroidChannels() async {
    final androidImplementation = _androidImplementation;
    if (androidImplementation == null) return;

    const channels = [
      ('spin_channel', 'Spin Wheel Alerts'),
      ('reward_channel', 'Daily Reward Alerts'),
      ('lives_channel', 'Life System Alerts'),
      ('retention_channel', 'Inactivity Alerts'),
      ('leaderboard_channel', 'Leaderboard Alerts'),
    ];

    for (final (channelId, channelName) in channels) {
      await androidImplementation.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          channelName,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  Future<bool> requestNotificationPermission() async {
    final androidImplementation = _androidImplementation;
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    return areNotificationsEnabled();
  }

  Future<bool> areNotificationsEnabled() async {
    final androidImplementation = _androidImplementation;
    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }

    final iosImplementation = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final settings = await iosImplementation.checkPermissions();
      return settings?.isEnabled ?? false;
    }

    return true;
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    required String channelId,
    required String channelName,
  }) async {
    if (!_initialized) {
      debugPrint('NotificationService not initialized. Skipping schedule for id $id.');
      return;
    }

    if (!await areNotificationsEnabled()) {
      debugPrint('Notifications disabled. Skipping schedule for id $id.');
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      );

      await _localNotificationsPlugin.cancel(id: id);
      await _localNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'payload_$id',
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to schedule notification $id: $e');
      debugPrint('$stackTrace');
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _localNotificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Failed to cancel notification $id: $e');
    }
  }

  Future<void> scheduleSpinWheel(Duration delay) async {
    final randomData = _spinStrings[Random().nextInt(_spinStrings.length)];
    await _schedule(
      id: idSpinWheel,
      title: randomData['title']!,
      body: randomData['body']!,
      delay: delay,
      channelId: 'spin_channel',
      channelName: 'Spin Wheel Alerts',
    );
  }

  Future<void> scheduleDailyReward(Duration delay) async {
    final randomData =
        _dailyRewardStrings[Random().nextInt(_dailyRewardStrings.length)];
    await _schedule(
      id: idDailyReward,
      title: randomData['title']!,
      body: randomData['body']!,
      delay: delay,
      channelId: 'reward_channel',
      channelName: 'Daily Reward Alerts',
    );
  }

  Future<void> scheduleLivesFull(Duration delay) async {
    final randomData =
        _livesFullStrings[Random().nextInt(_livesFullStrings.length)];
    await _schedule(
      id: idLivesFull,
      title: randomData['title']!,
      body: randomData['body']!,
      delay: delay,
      channelId: 'lives_channel',
      channelName: 'Life System Alerts',
    );
  }

  Future<void> scheduleInactivityReminder() async {
    final randomData =
        _inactivityStrings[Random().nextInt(_inactivityStrings.length)];
    await _schedule(
      id: idInactivity,
      title: randomData['title']!,
      body: randomData['body']!,
      delay: const Duration(hours: 24),
      channelId: 'retention_channel',
      channelName: 'Inactivity Alerts',
    );
  }

  Future<void> scheduleLeaderboardAlert(Duration delay) async {
    final randomData =
        _leaderboardStrings[Random().nextInt(_leaderboardStrings.length)];
    await _schedule(
      id: idLeaderboard,
      title: randomData['title']!,
      body: randomData['body']!,
      delay: delay,
      channelId: 'leaderboard_channel',
      channelName: 'Leaderboard Alerts',
    );
  }
}
