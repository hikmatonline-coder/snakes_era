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
  bool _adRewardEarned = false; // 🎯 Tracking context for the ad spin trigger

  final List<String> rewards = [
    "50 COINS",    // 0
    "1 POWER",     // 1
    "100 COINS",   // 2
    "2 POWER",     // 3
    "20 COINS",    // 4
    "0 POWER",     // 5 (Bad Luck)
    "150 COINS",   // 6
    "3 POWER",     // 7
    "50 COINS",    // 8
    "0 COINS",     // 9 (Bad Luck)
    "200 COINS",   // 10
    "1 POWER",     // 11
    "75 COINS",    // 12
    "5 POWER",     // 13 (Mega Power)
    "25 COINS",    // 14
    "500 COINS",   // 15 (Jackpot)
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
    final adProv = Provider.of<AdProvider>(context);
    int seconds = adProv.secondsRemaining;
    bool adReady = adProv.isRewardedReady && seconds == 0;
    bool isCurrentlyFetching = adProv.isAdLoading;

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

              else if (prov.extraSpinsAvailable > 0)
              // 🎯 NESTED CONDITION FOR AD COMPLETION BUTTON STATE
                _adRewardEarned
                    ? _actionButton(
                  prov,
                  "TAP TO SPIN! ⚡",
                      () async {
                    // Reset the flag first so button locks instantly
                    setState(() { _adRewardEarned = false; });

                    // Now fire the actual rotation system safely
                    String? result = await prov.spin(_controller, rewards, false);
                    if (result != null) _handleReward(result);
                  },
                  Colors.greenAccent, // Green highlight when ready to manually spin
                )
                    : _actionButton(
                  prov,
                  seconds > 0
                      ? "NEXT AD IN ${seconds}s"
                      : (adReady ? "WATCH AD TO SPIN" : "LOADING AD..."),
                      () async {
                    await adProv.showRewardedAd(
                      onUserEarnedReward: (ad, reward) {
                        // 🛑 COOLDOWN FIX: Ad complete hote hi spin nahi chalega!
                        // Sirf state set hogi jo "TAP TO SPIN" button samne layegi.
                        setState(() {
                          _adRewardEarned = true;
                        });
                      },
                    );
                  },
                  adReady ? Colors.orangeAccent : Colors.grey,
                  isTimerActive: seconds > 0 || !adReady || isCurrentlyFetching,
                )
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
    // A spin is only "Recharging" if the Daily Spin is used up.
    // For Ad spins, we only care if the timer is active AND no ad is ready.
    bool isDisabled = prov.isSpinning || isTimerActive;

    String buttonText = text;
    if (prov.isSpinning) {
      buttonText = "SPINNING...";
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

    final adProv = Provider.of<AdProvider>(context, listen: false);

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
                onPressed: () {
                  // 1. Close the dialog
                  Navigator.pop(context);

                  // 2. Show the Interstitial Ad after collecting
                  Future.delayed(const Duration(milliseconds: 300), () {
                    adProv.showInterstitialAd();
                  });
                },
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