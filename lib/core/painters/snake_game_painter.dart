import 'dart:math';
import 'package:flutter/material.dart';
import '../../model/snake_skin_model.dart';
import '../widgets/snake_game_widget.dart';

class SnakeGamePainter extends CustomPainter {
  final Offset playerPos;
  final double playerAngle;
  final List<Offset> playerBody;
  final List<Food> foods;
  final List<NPCSnake> npcs;
  final double worldSize;
  final SnakeSkin activeSkin;
  final bool isInvincible;
  final Map<String, List<Food>> chunkedFoods;
  final double chunkSize = 500.0;
  bool isBoosting;

  SnakeGamePainter(this.playerPos, this.playerAngle, this.playerBody, this.foods, this.npcs, this.worldSize, this.activeSkin, this.isInvincible, this.chunkedFoods, this.isBoosting);

  @override
  void paint(Canvas canvas, Size size) {
    double zoomFactor = 0.75;
    double boostZoom = isBoosting ? 0.9 : 1.0;
    double sizeZoom = (1.0 - (playerBody.length / 5000)).clamp(0.7, 1.0);
    double finalZoom = zoomFactor * boostZoom * sizeZoom;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(finalZoom);
    canvas.translate(-playerPos.dx, -playerPos.dy);

    // 1. Draw Grid (Optimized to only visible area)
    _drawVisibleGrid(canvas, size, finalZoom);

    // 2. Draw Food using Chunk System ONLY
    _drawFoodViaChunks(canvas, size, finalZoom);

    // 3. Draw NPCs
    for (var npc in npcs) {
      if ((npc.pos - playerPos).distance < 1200 / finalZoom) {
        _drawSnake(canvas, npc.body, npc.angle, npc.colors, name: npc.name, npcSize: npc.size);
      }
    }

    // 4. Draw Player
    _drawSnake(
      canvas, playerBody, playerAngle, activeSkin.bodyColors,
      name: "YOU", eyeColor: activeSkin.eyeColor, showShield: isInvincible,
    );

    canvas.restore();
  }

  void _drawFoodViaChunks(Canvas canvas, Size size, double zoom) {
    double screenW = size.width / zoom;
    double screenH = size.height / zoom;

    // Determine which chunks are visible on screen
    int startX = ((playerPos.dx - screenW / 2) / chunkSize).floor();
    int endX = ((playerPos.dx + screenW / 2) / chunkSize).floor();
    int startY = ((playerPos.dy - screenH / 2) / chunkSize).floor();
    int endY = ((playerPos.dy + screenH / 2) / chunkSize).floor();

    final paint = Paint()..style = PaintingStyle.fill;

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        List<Food>? chunk = chunkedFoods["$x,$y"];
        if (chunk != null) {
          for (var f in chunk) {
            // FIXED: Ensure radius uses the 'type' field from your model
            // 0 = small, 1 = medium, loot = large
            double radius = f.isLoot ? 10.0 : (f.type == 0 ? 3.5 : 6.0);

            // Draw Glow for Loot (Dead snakes or Boost trails)
            if (f.isLoot) {
              canvas.drawCircle(
                  f.pos,
                  radius * 1.8,
                  Paint()..color = f.color.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
              );
            }

            paint.color = f.color;
            canvas.drawCircle(f.pos, radius, paint);

            // Small Shine detail (makes it look like a bubble/pearl)
            canvas.drawCircle(
                f.pos - Offset(radius * 0.3, radius * 0.3),
                radius * 0.25,
                Paint()..color = Colors.white.withOpacity(0.6)
            );
          }
        }
      }
    }
  }

  void _drawVisibleGrid(Canvas canvas, Size size, double zoom) {
    Paint gridPaint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    double screenW = size.width / zoom;
    double screenH = size.height / zoom;

    double left = (playerPos.dx - screenW / 2).clamp(0, worldSize);
    double right = (playerPos.dx + screenW / 2).clamp(0, worldSize);
    double top = (playerPos.dy - screenH / 2).clamp(0, worldSize);
    double bottom = (playerPos.dy + screenH / 2).clamp(0, worldSize);

    for (double i = (left / 100).floor() * 100.0; i <= right; i += 100.0) {
      canvas.drawLine(Offset(i, top), Offset(i, bottom), gridPaint);
    }
    for (double i = (top / 100).floor() * 100.0; i <= bottom; i += 100.0) {
      canvas.drawLine(Offset(left, i), Offset(right, i), gridPaint);
    }

    // World Border
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize), Paint()..color = Colors.red.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 20);
  }

  void _drawSnake(Canvas canvas, List<Offset> body, double angle, List<Color> colors, {String? name, Color eyeColor = Colors.white, bool showShield = false, NPCSize? npcSize}) {
    if (body.isEmpty) return;

    Offset headPos = body.first;
    double bodyRadius = 10.0 + (body.length / 80).clamp(0, 15);
    if (npcSize != null) {
      bodyRadius *= (npcSize == NPCSize.small ? 0.8 : npcSize == NPCSize.xlarge ? 1.3 : 1.0);
    }

    // Draw Shadows (Very sparse for performance)
    Paint shadowPaint = Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (int i = body.length - 1; i >= 0; i -= 15) {
      canvas.drawCircle(body[i] + const Offset(4, 4), bodyRadius, shadowPaint);
    }

    // Draw Body
    final bodyPaint = Paint()..isAntiAlias = true;
    for (int i = body.length - 1; i >= 0; i--) {
      bodyPaint.color = colors[(i ~/ 4) % colors.length];
      canvas.drawCircle(body[i], bodyRadius, bodyPaint);
    }

    // Draw Head
    _drawHead(canvas, headPos, angle, bodyRadius, colors[1], eyeColor);

    if (showShield) _drawShield(canvas, headPos, bodyRadius);
  }

  void _drawHead(Canvas canvas, Offset pos, double angle, double radius, Color color, Color eyeColor) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + pi / 2);

    double s = (radius * 1.25) / 48.0;
    final path = Path()
      ..moveTo(-42*s, 0)
      ..quadraticBezierTo(-45*s, -45*s, 0, -50*s)
      ..quadraticBezierTo(45*s, -45*s, 42*s, 0)
      ..quadraticBezierTo(0, 25*s, -42*s, 0)..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(Offset(-18*s, -12*s), 8*s, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(18*s, -12*s), 8*s, Paint()..color = eyeColor);
    canvas.restore();
  }

  void _drawShield(Canvas canvas, Offset pos, double radius) {
    canvas.drawCircle(pos, radius * 2.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.cyanAccent.withOpacity(0.5));
  }

  @override
  bool shouldRepaint(covariant SnakeGamePainter old) => true;
}