import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../provider/user_provider.dart';

class GameOverOverlay extends StatelessWidget {
  final int score;
  final VoidCallback onWatchAd;
  final VoidCallback onLoseLife;

  GameOverOverlay({
    super.key,
    required this.score,
    required this.onWatchAd,
    required this.onLoseLife
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

    // Get the high score from your UserProvider
    final user = Provider.of<UserProvider>(context);
    final isNewBest = score > user.highScore;

    final randomCompliment = compliments[Random().nextInt(compliments.length)];

    return Container(
      color: Colors.black.withOpacity(0.50),
      child: Center(
        child: Container(
          height: 350,
          width: 350,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.black.withOpacity(0.6),
            border: BoxBorder.all(width: 2, color: Colors.cyanAccent)
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "GAME OVER",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                randomCompliment,
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 20),

              if (isNewBest)
                const Text("NEW BEST!", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),

              // CURRENT RUN SCORE
              Text("SCORE: $score", style: const TextStyle(color: Colors.white, fontSize: 32)),

              // ALL TIME BEST
              Text("BEST: ${isNewBest ? score : user.highScore}",
                  style: const TextStyle(color: Colors.white54, fontSize: 18)),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- BUTTON 1: LOSE LIFE ---
                  ElevatedButton.icon(
                    onPressed: onLoseLife,
                    // icon: const Icon(Icons.heart_broken, color: Colors.redAccent,),
                    label: const Text("No Thanks"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      // padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                  ),
                  const SizedBox(width : 15),
                  // --- BUTTON 2: WATCH AD ---
                  ElevatedButton.icon(
                    onPressed: onWatchAd,
                    icon: const Icon(Icons.favorite, color: Colors.redAccent),
                    label: const Text("SAVE ME!"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      // padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}