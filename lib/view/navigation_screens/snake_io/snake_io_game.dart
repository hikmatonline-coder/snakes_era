import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  State<SnakeIOGame> createState() => _SnakeIOGameState();
}

class _SnakeIOGameState extends State<SnakeIOGame> {
  Timer? _pauseAdTimer;
  Offset? joystickPivot;
  late SnakeSkin _activeSkin;
  SnakeGamePainter? _gamePainter;
  MinimapPainter? _minimapPainter;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final user = context.read<UserProvider>();
      final adProv = context.read<AdProvider>();

      adProv.loadInterstitialAd();
      adProv.loadRewardedAd();

      _activeSkin = snakeSkins.firstWhere(
        (s) => s.id == user.currentSkinId,
        orElse: () => snakeSkins.first,
      );

      final game = context.read<SnakeGameProvider>();
      _gamePainter = SnakeGamePainter(
        repaint: game.frameNotifier,
        game: game,
        skin: _activeSkin,
      );
      _minimapPainter = MinimapPainter(
        repaint: game.frameNotifier,
        game: game,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pauseAdTimer?.cancel();
    super.dispose();
  }

  void _togglePauseWithAd(SnakeGameProvider game) {
    final adProv = context.read<AdProvider>();

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

  void _exitGame() {
    final adProvider = context.read<AdProvider>();
    final game = context.read<SnakeGameProvider>();

    game.stopGameEngine();
    adProvider.showInterstitialAd();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _loseLife() {
    final game = context.read<SnakeGameProvider>();
    final lifeProv = context.read<LifeProvider>();

    if (lifeProv.lives > 0) {
      lifeProv.consumeLife();

      final user = context.read<UserProvider>();
      final skin = snakeSkins.firstWhere(
        (s) => s.id == user.currentSkinId,
        orElse: () => snakeSkins.first,
      );

      _activeSkin = skin;
      game.startGame(
        skin.bodyColors,
        onLiveTicketsRewarded: (tickets, message) {
          user.addFreeTickets(tickets);
        },
      );

      _gamePainter = SnakeGamePainter(
        repaint: game.frameNotifier,
        game: game,
        skin: skin,
      );
      _minimapPainter = MinimapPainter(
        repaint: game.frameNotifier,
        game: game,
      );
      setState(() {});
    } else {
      _exitGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GameLoop(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Stack(
          children: [
            _GameCanvas(
              joystickPivot: joystickPivot,
              painter: _gamePainter,
              onPanStart: (position) => joystickPivot = position,
              onPanUpdate: (position) {
                if (joystickPivot == null) return;
                final delta = position - joystickPivot!;
                if (delta.distance > 5) {
                  context.read<SnakeGameProvider>().setTargetAngle(delta.direction);
                  if (delta.distance > 45) {
                    joystickPivot =
                        position - (delta / delta.distance) * 45;
                  }
                }
                setState(() {});
              },
              onPanEnd: () => setState(() => joystickPivot = null),
              onPanCancel: () => setState(() => joystickPivot = null),
            ),
            const _PauseButton(),
            const _ScoreHud(),
            const _LeaderboardPanel(),
            _Minimap(painter: _minimapPainter),
            const _BoostButton(),
            const _PauseOverlay(),
            Selector<SnakeGameProvider, bool>(
              selector: (_, game) => game.isGameOver,
              builder: (context, isGameOver, _) {
                if (!isGameOver) return const SizedBox.shrink();

                final game = context.read<SnakeGameProvider>();
                return GameOverOverlay(
                  score: game.score,
                  onLoseLife: _loseLife,
                  onExitPressed: _exitGame,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GameLoop extends StatefulWidget {
  final Widget child;

  const _GameLoop({required this.child});

  @override
  State<_GameLoop> createState() => _GameLoopState();
}

class _GameLoopState extends State<_GameLoop>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration? _lastElapsed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final game = context.read<SnakeGameProvider>();
    if (game.isGameOver || game.isPaused) {
      _lastElapsed = elapsed;
      return;
    }

    final dt = _lastElapsed == null
        ? 0.016
        : (elapsed - _lastElapsed!).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    game.tick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _GameCanvas extends StatelessWidget {
  final Offset? joystickPivot;
  final SnakeGamePainter? painter;
  final ValueChanged<Offset> onPanStart;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback onPanCancel;

  const _GameCanvas({
    required this.joystickPivot,
    required this.painter,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (painter == null) {
      return const ColoredBox(color: Color(0xFF0F0F0F));
    }

    return RepaintBoundary(
      child: GestureDetector(
        onPanStart: (details) => onPanStart(details.localPosition),
        onPanUpdate: (details) => onPanUpdate(details.localPosition),
        onPanEnd: (_) => onPanEnd(),
        onPanCancel: onPanCancel,
        child: CustomPaint(
          painter: painter,
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton();

  @override
  Widget build(BuildContext context) {
    return Selector<SnakeGameProvider, bool>(
      selector: (_, game) => game.isPaused,
      builder: (context, isPaused, _) {
        final game = context.read<SnakeGameProvider>();
        return Positioned(
          top: 50,
          right: 20,
          child: GestureDetector(
            onTap: () {
              final state = context.findAncestorStateOfType<_SnakeIOGameState>();
              state?._togglePauseWithAd(game);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPaused ? Colors.cyanAccent : Colors.white24,
                ),
              ),
              child: Icon(
                isPaused ? Icons.play_arrow : Icons.pause,
                color: isPaused ? Colors.cyanAccent : Colors.white,
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreHud extends StatelessWidget {
  const _ScoreHud();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Selector<SnakeGameProvider, (int, int)>(
        selector: (_, game) => (game.currentLengthLimit, game.score),
        builder: (context, values, _) {
          return Center(
            child: Column(
              children: [
                Text(
                  'LENGTH: ${values.$1}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black),
                    ],
                  ),
                ),
                Text(
                  'SCORE: ${values.$2}',
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      left: 20,
      child: RepaintBoundary(
        child: Selector<SnakeGameProvider, List<LeaderboardEntry>>(
          selector: (_, game) => game.leaderboardEntries,
          builder: (context, entries, _) {
            return Container(
              padding: const EdgeInsets.all(10),
              width: 150,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LEADERBOARD',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  for (int i = 0; i < entries.length && i < 10; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${i + 1}. ${entries[i].name}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: entries[i].isPlayer
                                    ? Colors.cyanAccent
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: entries[i].isPlayer
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            '${entries[i].score}',
                            style: TextStyle(
                              color: entries[i].isPlayer
                                  ? Colors.cyanAccent
                                  : Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Minimap extends StatelessWidget {
  final MinimapPainter? painter;

  const _Minimap({required this.painter});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: RepaintBoundary(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black45,
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: painter == null
              ? const SizedBox.shrink()
              : CustomPaint(painter: painter),
        ),
      ),
    );
  }
}

class _BoostButton extends StatelessWidget {
  const _BoostButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 40,
      child: Selector<SnakeGameProvider, bool>(
        selector: (_, game) => game.isBoosting,
        builder: (context, isBoosting, _) {
          final game = context.read<SnakeGameProvider>();
          return GestureDetector(
            onPanDown: (_) => game.setBoosting(true),
            onPanEnd: (_) => game.setBoosting(false),
            onPanCancel: () => game.setBoosting(false),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isBoosting
                    ? Colors.orange.withOpacity(0.8)
                    : Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 35),
            ),
          );
        },
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay();

  @override
  Widget build(BuildContext context) {
    return Selector<SnakeGameProvider, bool>(
      selector: (_, game) => game.isPaused,
      builder: (context, isPaused, _) {
        if (!isPaused) return const SizedBox.shrink();

        final game = context.read<SnakeGameProvider>();
        final state = context.findAncestorStateOfType<_SnakeIOGameState>();

        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.72),
            child: Center(
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pause_circle_filled,
                      color: Colors.cyanAccent,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'GAME PAUSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'CURRENT SCORE: ${game.score}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => state?._togglePauseWithAd(game),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'RESUME',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: state?._exitGame,
                      child: const Text(
                        'EXIT TO MENU',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
