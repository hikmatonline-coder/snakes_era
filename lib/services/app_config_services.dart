import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConfigService {
  static final AppConfigService instance = AppConfigService._internal();
  AppConfigService._internal();

  Future<bool> checkIsUpdateRequired() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      await remoteConfig.fetchAndActivate();

      String minVersion = remoteConfig.getString('min_version');
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (minVersion.isEmpty) return false;
      return packageInfo.version.compareTo(minVersion) < 0;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getUpdateStatus() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();

    String minVersion = remoteConfig.getString('min_version');
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    return {
      'isRequired': currentVersion.compareTo(minVersion) < 0,
      'currentVersion': currentVersion,
      'minVersion': minVersion,
    };
  }

  Future<void> launchStore() async {
    final Uri url = Uri.parse("https://play.google.com/store/apps/details?id=com.musalleh.snakes_era&pli=1");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}