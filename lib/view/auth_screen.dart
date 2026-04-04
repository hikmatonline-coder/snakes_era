import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/painters/logo_painter.dart';
import '../provider/auth_provider.dart';


class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppConstants.backgroundColor,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Background Gradient Glow
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.primaryColor.withOpacity(0.05),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // 1. Custom Painted Logo
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: CustomPaint(painter: AppLogoPainter()),
                      ),

                      const SizedBox(height: 32),

                      // 2. Branded Typography
                      Text(
                        AppConstants.appName.toUpperCase(),
                        style: const TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        AppConstants.authSlogan,
                        style: TextStyle(
                          color: AppConstants.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      const Spacer(),

                      // 3. The Refined Sign-In Button
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          if (auth.isLoading) {
                            return const CircularProgressIndicator(color: AppConstants.primaryColor);
                          }

                          return Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppConstants.primaryColor.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () => _handleSignIn(context, auth),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryColor,
                                foregroundColor: AppConstants.textDark,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.g_mobiledata, size: 32),
                                  SizedBox(width: 8),
                                  Text(
                                    AppConstants.authButton,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        AppConstants.authTerms,
                        style: TextStyle(color: AppConstants.textWhite, fontSize: 10),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignIn(BuildContext context, AuthProvider auth) async {
    try {
      final success = await auth.signInWithGoogle();
      if (!success && context.mounted) {
        // User simply cancelled
      }
    } catch (e) {
      // This catches the [cloud_firestore/unavailable] error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server unreachable. Check internet!")),
        );
      }
    }
  }
}