import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../provider/snake_game_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../provider/ads_provider.dart'; // Make sure this path points to your AdProvider

class GameOverOverlay extends StatelessWidget {
  final int score;
  final VoidCallback onLoseLife; // Exits to home screen

  GameOverOverlay({
    super.key,
    required this.score,
    required this.onLoseLife,
  });

  final List<String> compliments = [
    "Spectacular Effort!",
    "You're a Snake Legend!",
    "That was Slitheringly Good!",
    "Epic Performance!",
    "So close to the Top!",
    "Unstoppable Energy!",
  ];

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<SnakeGameProvider>(context);
    final user = Provider.of<UserProvider>(context, listen: false); // CHANGE: Set listen to false for stable callback execution
    final adProv = Provider.of<AdProvider>(context);

    // -------------------------------------------------------------------------
    // CHANGE: AUTOMATIC BACKUP COMMIT
    // Fires immediately when the game-over screen mounts to ensure the match is
    // registered to weekly/monthly leaderboards, even if the player exits early.
    // -------------------------------------------------------------------------
    WidgetsBinding.instance.addPostFrameCallback((_) {
      user.updateHighScore(gameProvider.score);
    });

    final bool canRevive = gameProvider.adsWatchedThisSession < gameProvider.maxAdsPerSession;
    final isNewBest = score > user.highScore;

    final randomCompliment = compliments[min(score ~/ 10, compliments.length - 1)];

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
                        onUserEarnedReward: (ad, rewardItem) async { // CHANGE: Added async wrapper
                          gameProvider.doubleScore();
                          // CHANGE: Instantly push the new doubled score to Firestore indexes
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

              const SizedBox(height: 30),

              // --- REVIVE BUTTON WITH AD VALIDATION ---
              if (canRevive)
                Column(
                  children: [
                    SizedBox(
                      width: 260,
                      height: 52,
                      child: ElevatedButton.icon(
                        // Logic: Agar ad ready hai, cooldown 0 hai, AUR revives bache hain
                        onPressed: (canClickActions && canRevive)
                            ? () async {
                          gameProvider.isPaused = true;
                          await adProv.showRewardedAd(
                            onUserEarnedReward: (ad, rewardItem) {
                              // 1. Ads counter increment
                              gameProvider.adsWatchedThisSession++;
                              // 2. Game revive
                              gameProvider.revivePlayer();
                            },
                          );
                          // Reset game state after ad interaction
                          gameProvider.isPaused = false;
                        }
                            : null, // Yeh null button ko grey aur non-clickable bana dega
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
                            disabledBackgroundColor: Colors.white12, // Disabled state color
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
                    await user.updateHighScore(score).timeout(const Duration(seconds: 4));
                  } catch (e) {
                    debugPrint("Score update failed, skipping to exit: $e");
                  } finally {
                    onLoseLife();
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