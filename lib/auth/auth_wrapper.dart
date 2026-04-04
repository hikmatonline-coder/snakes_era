import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Internal Core & Providers
import '../provider/auth_provider.dart';
import '../view/auth_screen.dart';
import '../view/navigation_screens/navigation_screen.dart';
import '../view/splash_screen.dart';

// Screens


/// Decisions based on Firebase/SecureStorage state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // We use Consumer to listen to AuthProvider changes specifically
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {

        // 1. App is still loading local tokens or Firebase state
        if (auth.isInitializing) {
          return const SplashScreen();
        }

        // 2. User is logged in (UserModel exists)
        if (auth.isAuthenticated) {
          return const NavigationScreen();
        }

        // 3. No user session found - show Login
        return const AuthScreen();
      },
    );
  }
}