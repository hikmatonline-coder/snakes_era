import 'dart:async';
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
  double _progress = 0.0;
  bool _isConfigLoaded = false;
  Map<String, dynamic>? _updateData;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _startGameLoading();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _startGameLoading() {
    _fetchServerConfig();

    // Smooth increment (Takes around 3.5 to 4 seconds)
    const double incrementAmount = 0.0075;

    _loadingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;

      setState(() {
        if (_progress < 0.99) {
          _progress += incrementAmount;
        } else if (_isConfigLoaded) {
          _progress = 1.0;
          _loadingTimer?.cancel();
          _navigateAfterLoading();
        }
      });
    });
  }

  Future<void> _fetchServerConfig() async {
    try {
      _updateData = await AppConfigService.instance.getUpdateStatus();
    } catch (e) {
      debugPrint("🚀 [SPLASH UI LOG] Config fetch failed, bypassing: $e");
      _updateData = {'isRequired': false};
    } finally {
      _isConfigLoaded = true;
    }
  }

  void _navigateAfterLoading() {
    if (!mounted) return;

    print("🚀 [SPLASH UI LOG] _navigateAfterLoading triggered!");

    if (_updateData != null && _updateData!['isRequired'] == true) {
      print("🎯 [SPLASH UI LOG] Update Required! Showing custom dialog...");
      _showUpdateDialog(
          context,
          _updateData!['currentVersion'] ?? '1.0.0',
          _updateData!['minVersion'] ?? '1.0.0'
      );
    } else {
      print("➡️ [SPLASH UI LOG] No update needed, passing control to AuthWrapper...");
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper())
      );
    }
  }

  // 🎨 BEAUTIFIED GAMING UPDATE DIALOG
  void _showUpdateDialog(BuildContext context, String current, String min) {
    showDialog(
      context: context,
      barrierDismissible: false, // User dismiss nahi kar sakta (Force Update)
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false, // Android back button block
          child: Dialog(
            backgroundColor: const Color(0xFF1E293B), // Premium Dark Slate
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Update Icon/Badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(
                        Icons.system_update_rounded,
                        size: 40,
                        color: AppConstants.primaryColor
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    "UPDATE REQUIRED",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description text
                  Text(
                    "A new version of Snakes Era is available. Please update to the latest version to enjoy uninterrupted gameplay.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Version Badges Container
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildVersionInfo("Your Version", current),
                        Container(width: 1, height: 30, color: Colors.white10),
                        _buildVersionInfo("Required", min),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 5,
                        shadowColor: AppConstants.primaryColor.withOpacity(0.4),
                      ),
                      onPressed: () => AppConfigService.instance.launchStore(),
                      child: const Text(
                        "UPDATE NOW",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionInfo(String label, String version) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          version,
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int percentage = (_progress * 100).clamp(0, 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(painter: AppLogoPainter()),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "INITIALIZING GAME ENGINE...",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "$percentage%",
                      style: const TextStyle(
                        color: AppConstants.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: _progress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [AppConstants.primaryColor, Colors.cyanAccent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.primaryColor.withOpacity(0.6),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}