import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snakes_era/core/widgets/referral_dialogs.dart';
import 'package:snakes_era/provider/social_provider.dart';
import '../../../core/constants.dart';
import '../../../core/painters/home_snake_painter.dart';
import '../../../core/widgets/life_timer_widget.dart';
import '../../../core/widgets/no_live_sheet.dart';
import '../../../model/snake_skin_model.dart';
import '../../../provider/life_provider.dart';
import '../../../provider/user_provider.dart';
import '../leaderboard_screen.dart';
import 'snake_io_wrapper.dart';

class SnakeIOHomeScreen extends StatefulWidget {
  const SnakeIOHomeScreen({super.key});

  @override
  State<SnakeIOHomeScreen> createState() => _SnakeIOHomeScreenState();
}

class _SnakeIOHomeScreenState extends State<SnakeIOHomeScreen> {
  // ⚙️ TEMPORARY SETTINGS STATES (Saves value while app is running)
  bool _isSoundOn = true;
  bool _isHapticOn = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserProvider>(context);

    final activeSkin = snakeSkins.firstWhere(
          (s) => s.id == user.currentSkinId,
      orElse: () => snakeSkins.first,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. ADVANCED LAYERED GLOW BACKGROUND
          _buildDynamicGlows(activeSkin),

          // 2. MAIN USER INTERFACE
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                children: [

                  // ==========================================
                  // 💰 1. NEW TOP BALANCE BAR (SHOP STYLE)
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // LIVES / HEARTS (Left Side)
                      const LifeTimerWidget(),

                      // COINS & POWERUPS (Right Side)
                      Row(
                        children: [
                          _buildStatChip(context, Icons.confirmation_number, "${user.tickets}", Colors.cyanAccent),
                          const SizedBox(width: 10),
                          _buildStatChip(context, Icons.bolt, "${user.powerUps}", Colors.purpleAccent),
                          const SizedBox(width: 10),
                          _buildStatChip(context, Icons.monetization_on, "${user.coins}", Colors.amber),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Colors.white.withOpacity(0.08), height: 1),
                  const SizedBox(height: 12),

                  // ==========================================
                  // 🎮 TOP CONTROL DECK
                  // ==========================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      // 👈 TOP LEFT ACTION BUTTONS
                      Column(
                        children: [
                          _buildSidebarCard(
                            onTap: () => _showReferralOptions(context),
                            icon: Icons.card_giftcard,
                            label: "INVITE",
                            accentColor: Colors.amber,
                          ),
                          const SizedBox(height: 12),
                          _buildSidebarCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                              );
                            },
                            icon: Icons.emoji_events,
                            label: "RANKS",
                            accentColor: Colors.cyanAccent,
                          ),
                        ],
                      ),

                      // 🎯 TOP CENTER TITLE (SNAKES ERA)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            AppConstants.appName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                fontSize: 26,
                                shadows: [
                                  Shadow(
                                    color: AppConstants.deepPurpleColor.withOpacity(0.8),
                                    blurRadius: 20,
                                  ),
                                ]
                            ),
                          ),
                        ),
                      ),

                      // 👉 TOP RIGHT ACTION BUTTONS
                      Column(
                        children: [
                          _buildSidebarCard(
                            onTap: () {
                              // TODO: Navigate to Skins Shop directly
                            },
                            icon: Icons.style,
                            label: "SKINS",
                            accentColor: Colors.purpleAccent,
                          ),
                          const SizedBox(height: 12),
                          _buildSidebarCard(
                            onTap: () {
                              _showSettingsOptions(context);
                            },
                            icon: Icons.settings,
                            label: "SETTINGS",
                            accentColor: Colors.grey,
                          ),
                        ],
                      ),

                    ],
                  ),

                  // ==========================================
                  // 🎯 MAIN CENTER HERO PANEL
                  // ==========================================
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.015),
                              border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: activeSkin.bodyColors.first.withOpacity(0.05),
                                  blurRadius: 30,
                                )
                              ]
                          ),
                          child: CustomPaint(
                            painter: SimpleSnakePainter(
                              bodyColors: activeSkin.bodyColors,
                              eyeColor: activeSkin.eyeColor,
                              tongueColor: activeSkin.tongueColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        _buildThemeButton(
                          context,
                          label: "START GAME",
                          isPrimary: true,
                          onTap: () => _tryLaunch(context, const SnakeGameWrapper()),
                        ),
                      ],
                    ),
                  ),

                  // FOOTER INFO
                  Text(
                    "v1.0.0 • SNAKES ERA",
                    style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🎫 NEW STAT CHIP WIDGET HELPER
  // ==========================================
  Widget _buildStatChip(BuildContext context, IconData icon, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BACKGROUND GLOW BUILDER
  // ==========================================
  Widget _buildDynamicGlows(SnakeSkin activeSkin) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(seconds: 2),
        width: 340,
        height: 340,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: activeSkin.bodyColors.first.withOpacity(0.12),
              blurRadius: 120,
              spreadRadius: 60,
            ),
            BoxShadow(
              color: AppConstants.deepPurpleColor.withOpacity(0.08),
              blurRadius: 150,
              spreadRadius: 30,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SIDEBAR ACTION ITEM COMPONENT HELPER
  // ==========================================
  Widget _buildSidebarCard({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color accentColor,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Opacity(
        opacity: isLocked ? 0.4 : 1.0,
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(color: accentColor.withOpacity(0.03), blurRadius: 8, spreadRadius: 1)
              ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(height: 4),
              Text(
                isLocked ? "LOCK" : label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 0.6
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STYLISH THEME LAUNCH BUTTON
  // ==========================================
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
        width: 230,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppConstants.deepPurpleColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppConstants.deepPurpleColor.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ⚙️ INTERACTIVE SETTINGS MODAL (UPDATED)
  // ==========================================
  void _showSettingsOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // StatefulBuilder allows live toggling inside the BottomSheet dialog
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "GAME SETTINGS",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1),
                  ),
                  const Divider(color: Colors.white12, height: 30),

                  // Sound Effects Switch
                  ListTile(
                    leading: const Icon(Icons.volume_up, color: Colors.cyanAccent),
                    title: const Text("Sound Effects", style: TextStyle(color: Colors.white)),
                    trailing: Switch(
                      value: _isSoundOn,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) {
                        // Updates UI inside popup immediately
                        setModalState(() {
                          _isSoundOn = val;
                        });
                        // Future: soundProvider.setSound(val);
                      },
                    ),
                  ),

                  // Haptic Feedback Switch
                  ListTile(
                    leading: const Icon(Icons.vibration, color: Colors.purpleAccent),
                    title: const Text("Haptic Feedback", style: TextStyle(color: Colors.white)),
                    trailing: Switch(
                      value: _isHapticOn,
                      activeColor: Colors.purpleAccent,
                      onChanged: (val) {
                        setModalState(() {
                          _isHapticOn = val;
                        });
                        // Future: hapticProvider.setHaptic(val);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // SHEET & CORE LOGIC FUNCTIONS
  // ==========================================
  void _showReferralOptions(BuildContext rootContext) {
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Invite & Earn Rewards",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Share your code with friends or redeem a code to get instant coins and power-ups!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      final userProv = rootContext.read<UserProvider>();
                      rootContext.read<SocialProvider>().shareReferralCode(userProv.referralCode);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("SHARE CODE"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      ReferralDialogs.showRedeemDialog(rootContext);
                    },
                    icon: const Icon(Icons.redeem),
                    label: const Text("REDEEM"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

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