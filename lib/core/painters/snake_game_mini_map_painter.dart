import 'package:flutter/material.dart';
import '../../provider/snake_game_provider.dart';

class MinimapPainter extends CustomPainter {
  MinimapPainter({
    required Listenable repaint,
    required this.game,
  }) : super(repaint: repaint);

  final SnakeGameProvider game;

  final Paint _playerPaint = Paint()..color = Colors.cyanAccent;
  final Paint _npcPaint = Paint()..color = Colors.redAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / game.worldSize;
    canvas.drawCircle(game.playerPos * scale, 2, _playerPaint);
    for (final npc in game.npcs) {
      canvas.drawCircle(npc.pos * scale, 1.5, _npcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MinimapPainter oldDelegate) => false;
}
