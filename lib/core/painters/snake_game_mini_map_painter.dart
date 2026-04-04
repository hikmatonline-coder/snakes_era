import 'package:flutter/material.dart';
import '../widgets/snake_game_widget.dart';

class MinimapPainter extends CustomPainter {
  final Offset playerPos;
  final List<NPCSnake> npcs;
  final double worldSize;

  MinimapPainter(this.playerPos, this.npcs, this.worldSize);

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / worldSize;
    canvas.drawCircle(playerPos * scale, 2, Paint()..color = Colors.cyanAccent);
    for (var npc in npcs) canvas.drawCircle(npc.pos * scale, 1.5, Paint()..color = Colors.redAccent);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}