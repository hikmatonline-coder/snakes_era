import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/painters/home_snake_painter.dart';
import '../../../core/widgets/no_live_sheet.dart';
import '../../../model/snake_skin_model.dart';
import '../../../provider/life_provider.dart';
import '../../../provider/user_provider.dart';
import 'snake_io_wrapper.dart';

class SnakeIOHomeScreen extends StatelessWidget {
  const SnakeIOHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Accessing the theme properties defined in your AppTheme
    final theme = Theme.of(context);
    final user = Provider.of<UserProvider>(context);

    final activeSkin = snakeSkins.firstWhere(
          (s) => s.id == user.currentSkinId,
      orElse: () => snakeSkins.first,
    );

    return Scaffold(
      // Automatically uses scaffoldBackgroundColor: 0xFF0F172A from your theme
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Dynamic Glow using the Theme's secondary color or Skin color
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeSkin.bodyColors.first.withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Title using Poppins from Theme
                Text(
                  AppConstants.appName.toUpperCase(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppConstants.deepPurpleColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 40),

                // Snake Character Preview
                Center(
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: CustomPaint(
                      painter: SimpleSnakePainter(
                        bodyColors: activeSkin.bodyColors,
                        eyeColor: activeSkin.eyeColor,
                        tongueColor: activeSkin.tongueColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 180),

                // Action Buttons
                _buildThemeButton(
                  context,
                  label: "START GAME",
                  isPrimary: true,
                  onTap: () => _tryLaunch(context, const SnakeGameWrapper()),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A helper that respects the AppTheme buttons/colors
  Widget _buildThemeButton(
      BuildContext context, {
        required String label,
        required bool isPrimary,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          // Primary uses Neon Green, Secondary uses Surface color with border
          color: isPrimary ? AppConstants.deepPurpleColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: isPrimary
              ? Border.all(color: AppConstants.deepPurpleColor.withOpacity(0.5), width: 5)
              : Border.all(color: AppConstants.deepPurpleColor.withOpacity(0.5),  width: 5),
          boxShadow: [
            if (isPrimary)
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // Method Logic (Keep these as they were)
  void _tryLaunch(BuildContext context, Widget gameWidget) {
    final lifeProv = Provider.of<LifeProvider>(context, listen: false);
    if (lifeProv.lives > 0) {
      lifeProv.consumeLife();
      Navigator.push(context, MaterialPageRoute(builder: (_) => gameWidget));
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => const NoLivesSheet(),
      );
    }
  }
}