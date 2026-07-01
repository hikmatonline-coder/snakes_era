import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> requestNotificationPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _localNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // 🎯 IDs Definitions
  static const int idSpinWheel = 101;
  static const int idDailyReward = 202;
  static const int idLivesFull = 303;
  static const int idInactivity = 404;
  static const int idLeaderboard = 505;

  // 📄 STRINGS/MESSAGES POOL
  final List<Map<String, String>> _spinStrings = [
    {"title": "⚡ Free Spin Ready!", "body": "Ustad g, kismat aazmaein! Wheel ghumaein aur mega rewards jeetein."},
    {"title": "🎁 Your Gift is Waiting!", "body": "Spin wheel ready ho chuka hy. Dekhein aaj aap jackpot jeet-te hain ya nahi!"},
    {"title": "🎡 Wheel of Fortune!", "body": "Coins aur Power ups chahiye? Aein aur apna free spin claim karein!"},
  ];

  final List<Map<String, String>> _dailyRewardStrings = [
    {"title": "📆 Daily Reward Claim!", "body": "Naya din, naya inaam! App open karein aur apna daily bonus collect karein."},
    {"title": "💰 Free Coins Inside!", "body": "Ustad g, aaj ka reward miss mat karein. Streak toot jayegi!"},
  ];

  final List<Map<String, String>> _livesFullStrings = [
    {"title": "❤️ Lives Fully Recharged!", "body": "Aap ki zindagiyan wapis full ho gayi hain. Chalein naya high score banayein!"},
    {"title": "🎮 Ready for Battle?", "body": "Full health alert! Snake arena aap ka intezar kar raha hy."},
  ];

  final List<Map<String, String>> _inactivityStrings = [
    {"title": "🐍 Snake Arena is Lonely...", "body": "Ustad g, 24 ghante ho gaye aap se mulaqat nahi hui. Aein ek match lagayein!"},
    {"title": "👑 Court Is Waiting for the King!", "body": "Kahan hain aap? Saanp bhookay hain aur arena khali hy. Wapis aein!"},
    {"title": "🔥 Don't Lose Your Touch!", "body": "Aap ki absence ka faida baqi players utha rahe hain. Come back now!"},
  ];

  final List<Map<String, String>> _leaderboardStrings = [
    {"title": "🏆 Leaderboard Danger!", "body": "Ustad g, koi aap ka record todne ki koshish kar raha hy. Top par raaj qaim rakhein!"},
    {"title": "🥇 Aim for Number 1!", "body": "Leaderboard par naye challenges aa gaye hain. Beat them all!"},
  ];

  Future<void> initNotification() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // ✅ FIXED: Accurately matched with your plugin source code parameter name 'settings:'
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint("🎯 Notification Clicked! Payload: ${details.payload}");
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _localNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final List<String> channels = ['spin_channel', 'reward_channel', 'lives_channel', 'retention_channel', 'leaderboard_channel'];
      final List<String> names = ['Spin Wheel Alerts', 'Daily Reward Alerts', 'Life System Alerts', 'Inactivity Alerts', 'Leaderboard Alerts'];

      for (int i = 0; i < channels.length; i++) {
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            channels[i],
            names[i],
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }
  }

  // Generic Scheduler Engine
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    required String channelId,
    required String channelName,
  }) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    // ✅ FIXED: Named parameter 'id:' specified
    await _localNotificationsPlugin.cancel(id: id);

    // ✅ FIXED: Perfectly mapped parameter names to match your plugin's zonedSchedule signature
    await _localNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'payload_$id',
    );
  }

  // 🛑 Cancel Engine
  // ✅ FIXED: Named parameter 'id:' mapped correctly
  Future<void> cancel(int id) async => await _localNotificationsPlugin.cancel(id: id);

  // ==========================================
  // 🎯 PUBLIC NOTIFICATION TRIGGERS
  // ==========================================

  void scheduleSpinWheel(Duration delay) {
    final randomData = _spinStrings[Random().nextInt(_spinStrings.length)];
    _schedule(
      id: idSpinWheel,
      title: randomData["title"]!,
      body: randomData["body"]!,
      delay: delay,
      channelId: 'spin_channel',
      channelName: 'Spin Wheel Alerts',
    );
  }

  void scheduleDailyReward(Duration delay) {
    final randomData = _dailyRewardStrings[Random().nextInt(_dailyRewardStrings.length)];
    _schedule(
      id: idDailyReward,
      title: randomData["title"]!,
      body: randomData["body"]!,
      delay: delay,
      channelId: 'reward_channel',
      channelName: 'Daily Reward Alerts',
    );
  }

  void scheduleLivesFull(Duration delay) {
    final randomData = _livesFullStrings[Random().nextInt(_livesFullStrings.length)];
    _schedule(
      id: idLivesFull,
      title: randomData["title"]!,
      body: randomData["body"]!,
      delay: delay,
      channelId: 'lives_channel',
      channelName: 'Life System Alerts',
    );
  }

  void scheduleInactivityReminder() {
    final randomData = _inactivityStrings[Random().nextInt(_inactivityStrings.length)];
    _schedule(
      id: idInactivity,
      title: randomData["title"]!,
      body: randomData["body"]!,
      delay: const Duration(hours: 24),
      channelId: 'retention_channel',
      channelName: 'Inactivity Alerts',
    );
  }

  void scheduleLeaderboardAlert(Duration delay) {
    final randomData = _leaderboardStrings[Random().nextInt(_leaderboardStrings.length)];
    _schedule(
      id: idLeaderboard,
      title: randomData["title"]!,
      body: randomData["body"]!,
      delay: delay,
      channelId: 'leaderboard_channel',
      channelName: 'Leaderboard Alerts',
    );
  }
}