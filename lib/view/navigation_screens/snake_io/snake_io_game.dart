import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/painters/snake_game_mini_map_painter.dart';
import '../../../core/painters/snake_game_painter.dart';
import '../../../model/snake_skin_model.dart';
import '../../../provider/ads_provider.dart';
import '../../../provider/life_provider.dart';
import '../../../provider/snake_game_provider.dart';
import '../../../provider/user_provider.dart';
import 'game_over_widget.dart';

class SnakeIOGame extends StatefulWidget {
  const SnakeIOGame({super.key});

  @override
  _SnakeIOGameState createState() => _SnakeIOGameState();
}

class _SnakeIOGameState extends State<SnakeIOGame> {
  Timer? _pauseAdTimer;
  Offset? joystickPivot;

  // 🎯 GAME OVER ENGINE GUARD (Infinite loop se bachane ke liye)
  bool _hasProcessedGameOver = false;

  void _togglePauseWithAd(SnakeGameProvider game) {
    final adProv = Provider.of<AdProvider>(context, listen: false);

    if (!game.isPaused) {
      game.togglePause();

      _pauseAdTimer = Timer(const Duration(seconds: 3), () {
        if (game.isPaused && mounted) {
          adProv.showInterstitialAd();
        }
      });
    } else {
      _pauseAdTimer?.cancel();
      game.togglePause();
    }
  }

  @override
  void initState() {
    super.initState();
    _hasProcessedGameOver = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false);
      final adProv = Provider.of<AdProvider>(context, listen: false);

      adProv.loadInterstitialAd();
      adProv.loadRewardedAd();

      final skin = snakeSkins.firstWhere(
            (s) => s.id == user.currentSkinId,
        orElse: () => snakeSkins.first,
      );

      // 🚀 GAME START WITH LIVE REWARDS CALLBACK LINKED
      Provider.of<SnakeGameProvider>(context, listen: false).startGame(
        skin.bodyColors,
        onLiveTicketsRewarded: (tickets, message) {
          user.addFreeTickets(tickets);
          debugPrint("🎯 [LIVE REWARD]: $message");
        },
      );
    });
  }

  @override
  void dispose() {
    _pauseAdTimer?.cancel();
    super.dispose();
  }

  void _handleRewardedAdAction(VoidCallback onGrantReward) async {
    final adProvider = Provider.of<AdProvider>(context, listen: false);
    final game = Provider.of<SnakeGameProvider>(context, listen: false);

    game.isPaused = true;

    if (adProvider.rewardedAd == null) {
      game.isPaused = false;
      onGrantReward();
      return;
    }

    await adProvider.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        onGrantReward();
      },
    );
  }

  // ✅ FIXED: Exit game engine ko completely destroy karega taake background loop dead ho jaye
  void _exitGame() {
    final adProvider = Provider.of<AdProvider>(context, listen: false);
    final game = Provider.of<SnakeGameProvider>(context, listen: false);

    // 🎯 CHAWAL FIXED: Pehle loop timer cancel nahi ho raha tha, ab stop function call kiya hy
    game.stopGameEngine();

    adProvider.showInterstitialAd();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ✅ FIXED: Lose life logic bina kisi random glitch ke clean tareeqay se life minus karegi aur game reset karegi
  void _loseLife() {
    final game = Provider.of<SnakeGameProvider>(context, listen: false);
    final lifeProv = Provider.of<LifeProvider>(context, listen: false);

    if (lifeProv.lives > 0) {
      lifeProv.consumeLife();

      setState(() {
        _hasProcessedGameOver = false; // Reset guard for next life/try
      });

      // Fir se fresh screen active karne ke liye skin read karenge
      final user = Provider.of<UserProvider>(context, listen: false);
      final skin = snakeSkins.firstWhere(
            (s) => s.id == user.currentSkinId,
        orElse: () => snakeSkins.first,
      );

      // Game ko safely dobara initialize karenge naye life par
      game.startGame(skin.bodyColors, onLiveTicketsRewarded: (tickets, message) {
        user.addFreeTickets(tickets);
      });
    } else {
      // Agar life zero hain to seedha menu par tapkao
      _exitGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<SnakeGameProvider>(context);
    final user = Provider.of<UserProvider>(context);

    final skin = snakeSkins.firstWhere(
          (s) => s.id == user.currentSkinId,
      orElse: () => snakeSkins.first,
    );

    // 🎯 SECURE SINGLE-SHOT SCORE & TICKETS SUBMISSION
    if (game.isGameOver && !_hasProcessedGameOver) {
      _hasProcessedGameOver = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        print("🏁 [GAME OVER DETECTED] Submitting Data Securely...");

        user.updateHighScore(game.score);

        game.finalizeAndClaimRemainingTickets((remainingTickets) {
          user.addFreeTickets(remainingTickets);
          print("🎟️ [REWARDS SUBMITTED] +$remainingTickets Game-End Tickets Claimed!");
        });
      });
    }

    return Scaffold (
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // 1. GAMEPLAY LAYER
          RepaintBoundary(
            child: GestureDetector(
              onPanStart: (details) {
                joystickPivot = details.localPosition;
              },
              onPanUpdate: (details) {
                if (joystickPivot != null) {
                  Offset delta = details.localPosition - joystickPivot!;
                  if (delta.distance > 5) {
                    game.setTargetAngle(delta.direction);
                    if (delta.distance > 45) {
                      joystickPivot = details.localPosition - (delta / delta.distance) * 45;
                    }
                  }
                }
              },
              onPanEnd: (_) => joystickPivot = null,
              onPanCancel: () => joystickPivot = null,
              child: CustomPaint(
                painter: SnakeGamePainter(
                  game.playerPos, game.playerAngle, game.playerBody,
                  game.foods, game.npcs, game.worldSize, skin, game.isInvincible,
                  game.chunkedFoods, game.isBoosting, game.isLootBlinkingState,
                ),
                size: Size.infinite,
              ),
            ),
          ),

          // 2. PAUSE BUTTON
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: () => _togglePauseWithAd(game),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: game.isPaused ? Colors.cyanAccent : Colors.white24),
                ),
                child: Icon(
                  game.isPaused ? Icons.play_arrow : Icons.pause,
                  color: game.isPaused ? Colors.cyanAccent : Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),

          // 3. HUD LAYERS
          Positioned(
            top: 50,
            left: 20,
            child: RepaintBoundary(child: _Leaderboard(game: game)),
          ),
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    "LENGTH: ${game.currentLengthLimit}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  Text(
                    "SCORE: ${game.score}",
                    style: TextStyle(
                      color: Colors.cyanAccent.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: RepaintBoundary(child: _Minimap(game: game)),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            child: _BoostButton(game: game),
          ),

          // 4. PAUSE OVERLAY
          if (game.isPaused)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20)
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pause_circle_filled, color: Colors.cyanAccent, size: 80),
                          const SizedBox(height: 20),
                          const Text(
                            "GAME PAUSED",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "CURRENT SCORE: ${game.score}",
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 30),

                          // RESUME BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => _togglePauseWithAd(game),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text("RESUME", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // EXIT BUTTON
                          TextButton(
                            onPressed: _exitGame,
                            child: const Text("EXIT TO MENU", style: TextStyle(color: Colors.white38)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 5. GAME OVER OVERLAY
          if (game.isGameOver)
            GameOverOverlay(
              score: game.score,
              onLoseLife: _loseLife,       // Yeh tab chalay ga jab sach mein life kaat kar naya game chalana ho (e.g. ad na dekhne par auto-flow ya revival)
              onExitPressed: _exitGame,    // 🎯 FIX: Jab user "No Thanks, Exit" dbaaye ga, to direct _exitGame() chalay ga aur loop band ho kar screen pop ho jaye gi!
            ),
        ],
      ),
    );
  }
}

// --- Sub-Widgets remain unchanged ---
class _Leaderboard extends StatelessWidget {
  final SnakeGameProvider game;
  const _Leaderboard({required this.game});

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> all = [
      {'name': 'YOU', 'score': game.currentLengthLimit, 'isP': true}
    ];
    for (var n in game.npcs) {
      all.add({'name': n.name, 'score': n.length, 'isP': false});
    }
    all.sort((a, b) => b['score'].compareTo(a['score']));

    return Container(
      padding: const EdgeInsets.all(10),
      width: 150,
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("LEADERBOARD",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 5),
          ...all.take(10).map((p) {
            int rank = all.indexOf(p) + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "$rank. ${p['name']}",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p['isP'] ? Colors.cyanAccent : Colors.white,
                        fontSize: 11,
                        fontWeight: p['isP'] ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    "${p['score']}",
                    style: TextStyle(
                      color: p['isP'] ? Colors.cyanAccent : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _Minimap extends StatelessWidget {
  final SnakeGameProvider game;
  const _Minimap({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(color: Colors.black45, border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(8)),
      child: CustomPaint(painter: MinimapPainter(game.playerPos, game.npcs, game.worldSize)),
    );
  }
}

class _BoostButton extends StatelessWidget {
  final SnakeGameProvider game;
  const _BoostButton({required this.game});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (_) => game.setBoosting(true),
      onPanEnd: (_) => game.setBoosting(false),
      onPanCancel: () => game.setBoosting(false),
      child: Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          color: game.isBoosting ? Colors.orange.withOpacity(0.8) : Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.bolt, color: Colors.white, size: 35),
      ),
    );
  }
}