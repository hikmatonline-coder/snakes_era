import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class AppConfigService {
  static final AppConfigService instance = AppConfigService._internal();
  AppConfigService._internal();

  bool _isVersionLessThan(String current, String min) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> minParts = min.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        int minPart = i < minParts.length ? minParts[i] : 0;

        if (currentPart < minPart) return true;
        if (currentPart > minPart) return false;
      }
    } catch (e) {
      debugPrint("Version parsing error: $e");
    }
    return false;
  }

  Future<bool> checkIsUpdateRequired() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // Testing ke liye cache zero
      ));
      await remoteConfig.fetchAndActivate();

      String minVersion = remoteConfig.getString('minVersion');
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (minVersion.isEmpty) return false;
      return _isVersionLessThan(packageInfo.version, minVersion);
    } catch (e) {
      return false;
    }
  }

  // Future<Map<String, dynamic>> getUpdateStatus() async {
  //   try {
  //     final remoteConfig = FirebaseRemoteConfig.instance;
  //
  //     await remoteConfig.setConfigSettings(RemoteConfigSettings(
  //       fetchTimeout: const Duration(seconds: 10),
  //       minimumFetchInterval: Duration.zero,
  //     ));
  //
  //     await remoteConfig.fetchAndActivate();
  //
  //     String minVersion = remoteConfig.getString('minVersion');
  //     PackageInfo packageInfo = await PackageInfo.fromPlatform();
  //     String currentVersion = packageInfo.version; // Local version (e.g., 1.0.12)
  //
  //     // Agar Firebase par minVersion khali ho
  //     if (minVersion.isEmpty) {
  //       return {
  //         'isRequired': false,
  //         'currentVersion': currentVersion,
  //         'minVersion': '1.0.0',
  //       };
  //     }
  //
  //     return {
  //       'isRequired': _isVersionLessThan(currentVersion, minVersion),
  //       'currentVersion': currentVersion,
  //       'minVersion': minVersion,
  //     };
  //   } catch (e) {
  //     debugPrint("Error in getUpdateStatus: $e");
  //     return {
  //       'isRequired': false,
  //       'currentVersion': '1.0.0',
  //       'minVersion': '1.0.0',
  //     };
  //   }
  // }

  Future<Map<String, dynamic>> getUpdateStatus() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));

      // 📝 LOG 1: Check karenge fetch shuru hua ya nahi
      print("⚡ [SNAKES ERA LOG] Firebase se data fetch hona shuru ho gaya hy...");

      await remoteConfig.fetchAndActivate();

      // 📝 LOG 2: Check karenge fetch kamyab hua ya nahi
      print("⚡ [SNAKES ERA LOG] Firebase Fetch and Activate SUCCESSFUL!");

      String minVersion = remoteConfig.getString('minVersion');
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 📝 LOG 3: Dono versions print karwa ke check karenge kya aa raha hy
      print("📊 [SNAKES ERA LOG] Mobile App Version (Local): $currentVersion");
      print("📊 [SNAKES ERA LOG] Firebase Min Version (Server): '$minVersion'");

      if (minVersion.isEmpty) {
        print("⚠️ [SNAKES ERA LOG] WARNING: Firebase se minVersion KHALI (Empty) mili hy!");
        return {
          'isRequired': false,
          'currentVersion': currentVersion,
          'minVersion': '1.0.0',
        };
      }

      bool required = _isVersionLessThan(currentVersion, minVersion);

      // 📝 LOG 4: Final decision kya hua
      print("🎯 [SNAKES ERA LOG] Final Decision -> Is Update Required?: $required");

      return {
        'isRequired': required,
        'currentVersion': currentVersion,
        'minVersion': minVersion,
      };
    } catch (e) {
      // 📝 LOG 5: Agar koi error aaya to woh yahan pakra jaye ga
      print("❌ [SNAKES ERA LOG] CRITICAL ERROR OCCURRED: $e");
      return {
        'isRequired': false,
        'currentVersion': '1.0.0',
        'minVersion': '1.0.0',
      };
    }
  }

  Future<void> launchStore() async {
    final Uri url = Uri.parse("https://play.google.com/store/apps/details?id=com.musalleh.snakes_era&pli=1");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}