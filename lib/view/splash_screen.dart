import 'package:flutter/material.dart';
import '../auth/auth_wrapper.dart';
import '../core/constants.dart';
import '../core/painters/logo_painter.dart';
import '../services/app_config_services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkUpdateAndNavigate();
    });
  }

  Future<void> _checkUpdateAndNavigate() async {
    try {
      var updateData = await AppConfigService.instance.getUpdateStatus();

      if (!mounted) return;

      if (updateData['isRequired']) {
        _showUpdateDialog(context, updateData['currentVersion'], updateData['minVersion']);
      } else {
        // use pushReplacement properly
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthWrapper())
        );
      }
    } catch (e) {
      // Agar API fail ho jaye to bhi app ko block na karein
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper())
      );
    }
  }

  void _showUpdateDialog(BuildContext context, String current, String min) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 10),
            Text("Update Required"),
          ],
        ),
        content: Text(
          "App version: $current \nRequired version: $min \n\nPlease update to continue.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => AppConfigService.instance.launchStore(),
            child: const Text("UPDATE NOW"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your Custom Painted Logo
            SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: AppLogoPainter(),
              ),
            ),

            const SizedBox(height: 24),

            // App Name from AppStrings
            Text(
              AppConstants.appName.toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: AppConstants.primaryColor,
              ),
            ),

            const SizedBox(height: 48),

            // Themed Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}