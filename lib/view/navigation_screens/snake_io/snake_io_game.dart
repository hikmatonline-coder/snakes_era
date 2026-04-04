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
  @override
  _SnakeIOGameState createState() => _SnakeIOGameState();
}

class _SnakeIOGameState extends State<SnakeIOGame> {

  Future<void> _showAd() async {
    // final adProvider = Provider.of<AdProvider>(context, listen: false);
    final gameProvider = Provider.of<SnakeGameProvider>(context, listen: false);

    // if (adProvider.interstitialAd == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text("Ad is still loading...")),
    //   );
    //   adProvider.loadInterstitialAd();
    //   return;
    // }
    //
    // // 1. Show the Ad and wait for it to be dismissed
    // await adProvider.showInterstitialAd();

    if (!mounted) return;

    // 2. REMOVE the Navigator.pop() call from here.
    // The overlay is part of the Stack, not a separate Route.

    // 3. This triggers isGameOver = false, which removes the overlay from the Stack
    gameProvider.revivePlayer();

    // 4. Force UI refresh
    setState(() {});
  }

  // NEW: Dedicated function to go back to home screen
  void _exitGame() {
    // final adProvider = Provider.of<AdProvider>(context, listen: false);
    final game = Provider.of<SnakeGameProvider>(context, listen: false);

    // Show an ad before leaving if one is ready
    // adProvider.showInterstitialAd();

    game.gameTimer?.cancel();
    game.isGameOver = false;
    Navigator.of(context).pop();
  }

  void _loseLife() {
    final game = Provider.of<SnakeGameProvider>(context, listen: false);
    final lifeProv = Provider.of<LifeProvider>(context, listen: false);

    if (lifeProv.lives > 0) {
      lifeProv.consumeLife();
      game.resetGame(); // This restarts the loop
    } else {
      _exitGame(); // No lives left, must exit
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false);
      // final adProv = Provider.of<AdProvider>(context, listen: false);

      // PRE-LOAD THE AD HERE
      // adProv.loadInterstitialAd();

      final skin = snakeSkins.firstWhere(
            (s) => s.id == user.currentSkinId,
        orElse: () => snakeSkins.first,
      );
      Provider.of<SnakeGameProvider>(context, listen: false).startGame(skin.bodyColors);
    });
  }

  @override
  void dispose() {
    // Ensure timer stops when user leaves the screen
    Provider.of<SnakeGameProvider>(context, listen: false).gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final game = Provider.of<SnakeGameProvider>(context);
    final user = Provider.of<UserProvider>(context);

    // FIX: Add orElse to prevent "No element" error
    final skin = snakeSkins.firstWhere(
          (s) => s.id == user.currentSkinId,
      orElse: () => snakeSkins.first, // Fallback to the first skin in your list
    );

    if (game.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final userProv = Provider.of<UserProvider>(context, listen: false);
        userProv.updateHighScore(game.score);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // 1. Gameplay Layer
          RepaintBoundary(
            child: GestureDetector(
              onPanUpdate: (d) {
                final center = MediaQuery.of(context).size.center(Offset.zero);
                game.setTargetAngle((d.localPosition - center).direction);
              },
              child: CustomPaint(
                painter: SnakeGamePainter(
                  game.playerPos, game.playerAngle, game.playerBody,
                  game.foods, game.npcs, game.worldSize, skin, game.isInvincible,
                  game.isBoosting
                ),
                size: Size.infinite,
              ),
            ),
          ),
          // Pause Button
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: () => game.togglePause(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                  game.isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          // 2. HUD Layers
          Positioned(
              top: 50,
              left: 20,
              child: RepaintBoundary(child: _Leaderboard(game: game))
          ),
          Positioned(
              bottom: 20,
              right: 20,
              child: RepaintBoundary(child: _Minimap(game: game))
          ),

          // 3. Boost Button
          Positioned(
            bottom: 40, left: 40,
            child: _BoostButton(game: game),
          ),

          // Also inside the Stack
          if (game.isPaused)
            Positioned.fill(
              child: Container(
                color: Colors.black38, // Dim the background
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "PAUSED",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => game.togglePause(),
                        child: const Text("RESUME"),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          game.isGameOver
              ? GameOverOverlay(
            key: const ValueKey('game_over_active'), // Forces fresh state
            score: game.score,
            onWatchAd:  _showAd,
            onLoseLife: _exitGame,
          )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// --- Sub-Widgets for Cleanliness ---

class _Leaderboard extends StatelessWidget {
  final SnakeGameProvider game;
  const _Leaderboard({required this.game});

  @override
  Widget build(BuildContext context) {
    // We use currentLengthLimit to rank players by size
    List<Map<String, dynamic>> all = [
      {'name': 'YOU', 'score': game.currentLengthLimit, 'isP': true}
    ];

    for (var n in game.npcs) {
      all.add({'name': n.name, 'score': n.length, 'isP': false});
    }

    // Sort by Size/Length
    all.sort((a, b) => b['score'].compareTo(a['score']));

    return Container(
      // ... your decoration ...
      child: Column(
        children: [
          const Text("RANKINGS", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white10),
          ...all.take(10).map((p) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${all.indexOf(p) + 1}. ", style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text("${p['name']}: ${p['score']}",
                  style: TextStyle(
                      color: p['isP'] ? Colors.cyanAccent : Colors.white,
                      fontSize: 12,
                      fontWeight: p['isP'] ? FontWeight.bold : FontWeight.normal
                  )),
            ],
          )).toList(),
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
      child: Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          color: game.isBoosting ? Colors.orange : Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.bolt, color: Colors.white, size: 35),
      ),
    );
  }
}

