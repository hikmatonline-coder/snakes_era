import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/snake_game_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../provider/ads_provider.dart';

class GameOverOverlay extends StatefulWidget {
  final int score;
  final VoidCallback onLoseLife;

  const GameOverOverlay({
    super.key,
    required this.score,
    required this.onLoseLife,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  final List<String> compliments = [
    "Spectacular Effort!",
    "You're a Snake Legend!",
    "That was Slitheringly Good!",
    "Epic Performance!",
    "So close to the Top!",
    "Unstoppable Energy!",
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameProvider = Provider.of<SnakeGameProvider>(context, listen: false);
      final user = Provider.of<UserProvider>(context, listen: false);

      // 🌟 STEP 1: Pehle TICKETS CLAIM KAREIN (Bina kisi delay ke, taake state 0 na ho)
      gameProvider.finalizeAndClaimRemainingTickets((remainingTickets) async {
        if (remainingTickets > 0) {
          await user.addFreeTickets(remainingTickets); // Safely added to total balance
        }
      });

      // 🌟 STEP 2: High Score baad mein update karein kyunki yeh internet par time leta hy
      await user.updateHighScore(gameProvider.score);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<SnakeGameProvider>(context);
    final user = Provider.of<UserProvider>(context, listen: false);
    final adProv = Provider.of<AdProvider>(context);

    final bool canRevive = gameProvider.adsWatchedThisSession < gameProvider.maxAdsPerSession;
    final isNewBest = widget.score > user.highScore;

    final randomCompliment = compliments[min(widget.score ~/ 10, compliments.length - 1)];

    bool adIsReady = adProv.isRewardedReady;
    bool isAdLoading = adProv.isAdLoading;
    int adCooldown = adProv.secondsRemaining;

    bool canClickActions = adIsReady && !isAdLoading && adCooldown == 0;

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: const Color(0xFF121212),
              border: Border.all(width: 2, color: Colors.cyanAccent)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "GAME OVER",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              // --- 2X SCORE SECTION WITH AD VALIDATION ---
              if (!gameProvider.isScoreDoubled)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15)),
                  child: TextButton.icon(
                    onPressed: canClickActions
                        ? () async {
                      gameProvider.isPaused = true;
                      await adProv.showRewardedAd(
                        onUserEarnedReward: (ad, rewardItem) async {
                          gameProvider.doubleScore();

                          // 🌟 STEP 1: Pehle double score wale mazeed tickets claim karein instantly
                          gameProvider.finalizeAndClaimRemainingTickets((doubleRemainingTickets) async {
                            if (doubleRemainingTickets > 0) {
                              await user.addFreeTickets(doubleRemainingTickets);
                            }
                          });

                          // 🌟 STEP 2: High score baad mein update karein
                          await user.updateHighScore(gameProvider.score);
                        },
                      );
                      gameProvider.isPaused = false;
                    }
                        : null,
                    icon: isAdLoading
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.yellow))
                        : const Icon(Icons.bolt, color: Colors.yellow, size: 26),
                    label: Text(
                      isAdLoading
                          ? "LOADING AD..."
                          : (adCooldown > 0 ? "COOLDOWN ${adCooldown}s" : "AD: DOUBLE SCORE"),
                      style: TextStyle(
                          color: canClickActions ? Colors.yellow : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                ),

              const SizedBox(height: 15),
              Text(randomCompliment,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontStyle: FontStyle.italic)),

              const SizedBox(height: 15),
              if (isNewBest)
                const Text("NEW BEST!",
                    style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 20)),

              Text("SCORE: ${gameProvider.score}",
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              Text("BEST: ${isNewBest ? gameProvider.score : user.highScore}",
                  style: const TextStyle(color: Colors.white54, fontSize: 18)),

              // --- TOTAL MATCH EARNINGS DISPLAY PANEL ---
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3))
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.confirmation_number, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "TOTAL EARNED: ${gameProvider.ticketsAwardedSoFar} TICKETS",
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- REVIVE BUTTON WITH AD VALIDATION ---
              if (canRevive)
                Column(
                  children: [
                    SizedBox(
                      width: 260,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (canClickActions && canRevive)
                            ? () async {
                          gameProvider.isPaused = true;
                          await adProv.showRewardedAd(
                            onUserEarnedReward: (ad, rewardItem) {
                              gameProvider.adsWatchedThisSession++;
                              gameProvider.revivePlayer();
                            },
                          );
                          gameProvider.isPaused = false;
                        }
                            : null,
                        icon: isAdLoading
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.favorite, color: Colors.white),
                        label: Text(
                            isAdLoading
                                ? "LOADING..."
                                : (adCooldown > 0
                                ? "WAIT ${adCooldown}s"
                                : "REVIVE (${gameProvider.maxAdsPerSession - gameProvider.adsWatchedThisSession} LEFT)"),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white30,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),

              // EXIT BUTTON
              TextButton(
                onPressed: () async {
                  try {
                    // Yahan widget.score use hoga kyunki hum StatefulWidget mein hain
                    await user.updateHighScore(widget.score).timeout(const Duration(seconds: 4));
                  } catch (e) {
                    debugPrint("Score update failed, skipping to exit: $e");
                  } finally {
                    widget.onLoseLife();
                  }
                },
                child: Text(
                  canRevive ? "No Thanks, Exit" : "Back to Home",
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}