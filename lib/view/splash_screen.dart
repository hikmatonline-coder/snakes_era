import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_wrapper.dart';
import '../core/constants.dart';
import '../core/painters/logo_painter.dart';
import '../services/app_config_services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  bool _isConfigLoaded = false;
  bool _isNetworkChecked = false;
  Map<String, dynamic>? _updateData;
  Timer? _loadingTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 🎨 LOGO ANIMATION (Breathe Effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startPremiumLoading();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPremiumLoading() {
    // Background mein chup-chaap internet aur config check shuru kar do
    _checkConnectivityAndConfig();

    // Smoothly progress bar barhao (30ms ke ticks par)
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;

      setState(() {
        if (_progress < 0.82) {
          // 80% tak smoothly barhega bina ruke
          _progress += 0.0095;
        } else if (_isConfigLoaded && _isNetworkChecked) {
          // Jaise hi data load ho jaye, bar ko 100% par phek do ek dum se fast!
          if (_progress < 1.0) {
            _progress += 0.04; // Fast boost to 100%
          } else {
            _loadingTimer?.cancel();
            _navigateAfterLoading();
          }
        }
      });
    });
  }

  Future<void> _checkConnectivityAndConfig() async {
    var connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _loadingTimer?.cancel();
      _showNoInternetDialog();
    } else {
      _isNetworkChecked = true;
      // Server se details le aao
      try {
        _updateData = await AppConfigService.instance.getUpdateStatus();
      } catch (e) {
        debugPrint("🚀 [SPLASH] Config bypass: $e");
        _updateData = {'isRequired': false};
      } finally {
        _isConfigLoaded = true; // Timer ko green signal de do
      }
    }
  }

  void _navigateAfterLoading() {
    if (!mounted) return;

    if (_updateData != null && _updateData!['isRequired'] == true) {
      _showUpdateDialog(
          context,
          _updateData!['currentVersion'] ?? '1.0.0',
          _updateData!['minVersion'] ?? '1.0.0'
      );
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper())
      );
    }
  }

  // 🚫 NO INTERNET GAMING DIALOG
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "CONNECTION ERROR",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Snakes Era requires an active internet connection to sync data and load arena. Please check your network.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => SystemNavigator.pop(),
                          child: Text("EXIT", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _progress = 0.0;
                              _isConfigLoaded = false;
                              _isNetworkChecked = false;
                            });
                            _startPremiumLoading(); // Retry everything
                          },
                          child: const Text("RETRY", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🎨 BEAUTIFIED GAMING UPDATE DIALOG
  void _showUpdateDialog(BuildContext context, String current, String min) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.system_update_rounded, size: 40, color: AppConstants.primaryColor),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "UPDATE REQUIRED",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "A new version of Snakes Era is available. Please update to the latest version to enjoy uninterrupted gameplay.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
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
                      child: const Text("UPDATE NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(version, style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 Percentage calculation (0 se 100 tak clamp kiya hua)
    final int percentage = (_progress * 100).clamp(0, 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: CustomPaint(painter: AppLogoPainter()),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName.toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppConstants.primaryColor),
                ),
              ],
            ),
          ),

          // 🔥 NEON PROGRESS ENGINE (0% TO 100%)
          // 🔥 THICK NEON PROGRESS ENGINE (LEFT TO RIGHT)
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
                      _progress < 0.82 ? "CONNECTING TO ARENA SERVER..." : "COMPLETING AUTHENTICATION...",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5
                      ),
                    ),
                    Text(
                      "$percentage%",
                      style: const TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 14, // Text thora bara kiya hy thick bar ke sath match karne ke liye
                          fontWeight: FontWeight.w900
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Outer Track Container
                Container(
                  height: 22, // Thick gaming look
                  width: double.infinity, // Poori width track set karne k liye
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft, // 🎯 Yeh progress ko sirf LEFT se RIGHT chalaaye ga
                    child: FractionallySizedBox(
                      widthFactor: _progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [AppConstants.primaryColor, Colors.cyanAccent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primaryColor.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),
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