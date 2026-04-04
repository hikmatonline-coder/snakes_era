import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/painters/logo_painter.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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