import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../core/painters/spin_wheel_painter.dart';
import '../../../provider/ads_provider.dart';
import '../../../provider/life_provider.dart';
import '../../../provider/spin_provider.dart';
import '../../../provider/user_provider.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen> with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  final List<String> rewards = [
    "50 COINS",   // 0
    "1 LIFE",     // 1
    "1 POWER",    // 2
    "100 COINS",  // 3
    "2 LIVES",    // 4
    "0 LIVES",    // 5
    "500 COINS",  // 6 (Jackpot)
    "5 LIVES",    // 7
    "2 POWER",    // 8
    "0 COINS",    // 9
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpinProvider>(
      builder: (context, prov, child) {
        return Scaffold(
          body: Stack(
            children: [
              _buildBackgroundGlow(),
              Container(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    const Text(
                        "DAILY SPIN",
                        style: TextStyle(
                            color: AppConstants.deepPurpleColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8
                        )
                    ),
                    const Spacer(),
                    _buildWheelAssembly(prov),
                    const Spacer(),
                    _buildControlPanel(prov),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 4. SUB-WIDGETS ---
  Widget _buildControlPanel(SpinProvider prov) {
    // Access AdProvider to get the countdown value
    // final adProv = Provider.of<AdProvider>(context);
    // final int adCooldown = adProv.secondsRemaining;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppConstants.deepPurpleColor.withOpacity(0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: AppConstants.deepPurpleColor),
          ),
          child: Column(
            children: [
              if (prov.canDailySpin)
                _actionButton(prov, "LAUNCH DAILY SPIN", () async {
                  String? result = await prov.spin(_controller, rewards, true);
                  if (result != null) _handleReward(result);
                }, AppConstants.deepPurpleColor)

              // else if (prov.extraSpinsAvailable > 0)
              //   _actionButton(
              //     prov,
              //     adCooldown > 0
              //         ? "WAIT ${adCooldown}s" // This text will show if not "RECHARGING"
              //         : "WATCH AD TO SPIN",
              //         () async {
              //       bool success = await adProv.showRewarded();
              //       if (success) {
              //         String? result = await prov.spin(_controller, rewards, false);
              //         if (result != null) _handleReward(result);
              //       }
              //     },
              //     adCooldown > 0 ? Colors.grey : Colors.orangeAccent,
              //     isTimerActive: adCooldown > 0,
              //   )

              else
                _statusText("DAILY LIMIT REACHED"),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWheelAssembly(SpinProvider prov) {
    return SizedBox(
      height: 320,
      width: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            // Look at provider for rotation now
            angle: prov.rotation,
            child: CustomPaint(
              size: const Size(300, 300),
              painter: SpinWheelPainter(rewards),
            ),
          ),
          Positioned(
            bottom: -5, // Changed from bottom to top so it points down at the wheel
            child: Icon(Icons.arrow_drop_up, color: AppConstants.secPrimaryColor, size: 50),
          ),
          const CircleAvatar(
              radius: 20,
              backgroundColor: AppConstants.deepPurpleColor,
              child: Icon(Icons.bolt, color: Colors.white)
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Center(
      child: Container(
        width: 350, height: 350,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppConstants.primaryColor.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
        ),
      ),
    );
  }

  // Added SpinProvider here to check for isSpinning
  Widget _actionButton(SpinProvider prov, String text, VoidCallback onTap, Color color, {bool isTimerActive = false}) {
    bool isDailyCoolingDown = prov.cooldownText.isNotEmpty && !prov.canDailySpin;

    // Disable if: Spinning OR Daily Cooldown OR 30s Ad Timer is active
    bool isDisabled = prov.isSpinning || isDailyCoolingDown || isTimerActive;

    // Determine the text to display
    String buttonText = text;
    if (prov.isSpinning) {
      buttonText = "SPINNING...";
    } else if (isDailyCoolingDown) {
      buttonText = "RECHARGING...";
    } else if (isTimerActive) {
      buttonText = "COOLDOWN..."; // Or use the text passed from build which has the seconds
    }

    return ElevatedButton(
      onPressed: isDisabled ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDisabled ? 0 : 8,
      ),
      child: Text(
          buttonText,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)
      ),
    );
  }
  // The Reward Distributor
  void _handleReward(String result) {
    final lifeProv = Provider.of<LifeProvider>(context, listen: false);
    final userProv = Provider.of<UserProvider>(context, listen: false);

    // Normalize the string (e.g., "50 COINS" -> [50, COINS])
    final parts = result.trim().toUpperCase().split(" ");
    if (parts.length < 2) return;

    int amount = int.tryParse(parts[0]) ?? 0;
    String type = parts[1];

    if (amount == 0) {
      _showLootDialog("UNLUCKY", "No luck this time!", Icons.sentiment_dissatisfied, Colors.grey);
      return;
    }

    // 1. Lives Logic
    if (type.contains("LIFE")) {
      // Note: LifeProvider usually has a 'lives' limit (e.g., max 5)
      // Ensure addLives respects your game's max capacity
      lifeProv.addLives(amount);
      _showLootDialog("VITALITY", "YOU GAINED $amount ${amount > 1 ? 'LIVES' : 'LIFE'}", Icons.favorite, Colors.redAccent);
    }
    // 2. Coins Logic
    else if (type.contains("COIN")) {
      userProv.addCoins(amount);
      _showLootDialog("TREASURE", "YOU FOUND $amount COINS", Icons.monetization_on, Colors.amber);
    }
    // 3. Power/Boost Logic
    else if (type.contains("POWER")) {
      userProv.addPowerUps(amount);
      _showLootDialog("ENERGY", "YOU GAINED $amount POWER BOOSTS", Icons.bolt, Colors.purpleAccent);
    }
  }

  void _showLootDialog(String title, String sub, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: color.withOpacity(0.5), width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 60),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context),
                child: const Text("COLLECT"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusText(String text) {
    return Text(text, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold));
  }
}