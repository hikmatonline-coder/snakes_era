import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../provider/snake_game_provider.dart';
import '../../../provider/user_provider.dart';

class GameOverOverlay extends StatelessWidget {
  final int score;
  final VoidCallback onWatchAd;   // This calls gameProvider.revivePlayer()
  final VoidCallback onLoseLife;  // This exits to home
  final VoidCallback onDoubleScore; // NEW: Triggers the 2x ad

  GameOverOverlay({
    super.key,
    required this.score,
    required this.onWatchAd,
    required this.onLoseLife,
    required this.onDoubleScore,
  });

  // Simple compliments list
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
    final user = Provider.of<UserProvider>(context);

    final canRevive = gameProvider.adsWatchedThisSession < gameProvider.maxAdsPerSession;
    final isNewBest = score > user.highScore;
    final randomCompliment = compliments[Random().nextInt(compliments.length)];

    return Container(
      color: Colors.black.withOpacity(0.7), // Darker background for better focus
      child: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10), // Flexible height
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: const Color(0xFF121212), // Solid dark color looks cleaner
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

              // 2X SCORE SECTION
              if (!gameProvider.isScoreDoubled)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15)
                  ),
                  child: TextButton.icon(
                    onPressed: onDoubleScore,
                    icon: const Icon(Icons.bolt, color: Colors.yellow, size: 30),
                    label: const Text("AD: DOUBLE SCORE",
                        style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

              const SizedBox(height: 15),
              Text(randomCompliment,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontStyle: FontStyle.italic)),

              const SizedBox(height: 15),
              if (isNewBest)
                const Text("NEW BEST!", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 20)),

              Text("SCORE: ${gameProvider.score}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              Text("BEST: ${isNewBest ? gameProvider.score : user.highScore}",
                  style: const TextStyle(color: Colors.white54, fontSize: 18)),

              const SizedBox(height: 30),

              // REVIVE BUTTON (The main action)
              if (canRevive)
                Column(
                  children: [
                    SizedBox(
                      width: 220,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: onWatchAd,
                        icon: const Icon(Icons.favorite, color: Colors.white),
                        label: Text("REVIVE (${gameProvider.maxAdsPerSession - gameProvider.adsWatchedThisSession} LEFT)",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),

              // EXIT BUTTON
              TextButton(
                onPressed: () {
                  // Ensure score is saved before exiting
                  user.updateHighScore(gameProvider.score);
                  onLoseLife();
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