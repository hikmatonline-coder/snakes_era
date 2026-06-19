import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Internal Core & Providers
import '../provider/auth_provider.dart';
import '../view/auth_screen.dart';
import '../view/navigation_screens/navigation_screen.dart';

// Screens


/// Decisions based on Firebase/SecureStorage state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        // 1. Agar background mein auth data fetch ho rha hu
        if (auth.isInitializing) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
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