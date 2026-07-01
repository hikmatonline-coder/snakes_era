import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Internal Core & Providers
import '../provider/auth_provider.dart';
import '../view/auth_screen.dart';
import '../view/navigation_screens/navigation_screen.dart';
import '../core/painters/logo_painter.dart'; // 🎯 Logo painter import kiya

/// Decisions based on Firebase/SecureStorage state.
class AuthWrapper extends StatefulWidget { // 🎯 State management ke liye StatefulWidget kiya taake breathe animation chal sake
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 🎨 Wahi same Splash wala smooth pulse effect create kiya
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        // 1. Agar background mein auth data fetch ho rha hu (Splash look seamless matching loader)
        if (auth.isInitializing) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A), // Same deep dark color
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🎯 CircularProgressIndicator hata kar smooth breathe logo laga diya
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: CustomPaint(painter: AppLogoPainter()),
                    ),
                  ),
                  const SizedBox(height: 35),
                  // Chota sa cool looking gaming status text
                  Text(
                    "VERIFYING SESSION...",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 2. User logged in hy -> Send to Main Game Navigation
        if (auth.isAuthenticated) {
          return const NavigationScreen();
        }

        // 3. Koi session nahi mila -> Send to Login/Signup Screen
        return const AuthScreen();
      },
    );
  }
}