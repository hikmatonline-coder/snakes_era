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
  bool isBoosting;
  double targetAngle = 0.0;

  SnakeGamePainter(this.playerPos, this.playerAngle, this.playerBody, this.foods, this.npcs, this.worldSize, this.activeSkin, this.isInvincible, this.isBoosting);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. BASE ZOOM (The camera distance)
    double zoomFactor = 0.75;

    // DYNAMIC ZOOM: Zooms out further if boosting or if the snake is long
    double boostZoom = isBoosting ? 0.9 : 1.0;
    double sizeZoom = (1.0 - (playerBody.length / 5000)).clamp(0.7, 1.0);
    double finalZoom = zoomFactor * boostZoom * sizeZoom;

    canvas.save(); // --- SAVE 1 ---

    // 2. CENTER THE VIEWPORT
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(finalZoom);

    // 3. ATTACH CAMERA TO PLAYER
    // This keeps the player in the middle of the screen
    canvas.translate(-playerPos.dx, -playerPos.dy);

    // 4. DRAW WORLD BOUNDARIES & GRID
    _drawWorldLimits(canvas);

    // 5. DRAW FOOD
    final foodPainter = Paint()..style = PaintingStyle.fill;
    for (var f in foods) {
      // Only draw food if it's near the player (performance fix)
      if ((f.pos - playerPos).distance < 1200 / finalZoom) {
        double radius = (f.size == 0) ? 3.5 : (f.size == 1 ? 6.0 : 10.0);
        if (f.isLoot) {
          canvas.drawCircle(f.pos, radius * 2.5, Paint()
            ..color = f.color.withOpacity(0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        }
        foodPainter.color = f.color;
        canvas.drawCircle(f.pos, radius, foodPainter);
      }
    }

    // 6. DRAW NPCs
    for (var npc in npcs) {
      if ((npc.pos - playerPos).distance < 1500 / finalZoom) {
        _drawSnake(canvas, npc.body, npc.angle, npc.colors, name: npc.name, npcSize: npc.size);
      }
    }

    // 7. DRAW PLAYER
    _drawSnake(
      canvas,
      playerBody,
      playerAngle,
      activeSkin.bodyColors,
      name: "YOU",
      eyeColor: activeSkin.eyeColor,
      showShield: isInvincible,
    );

    canvas.restore(); // --- RESTORE 1 ---
  }

  // Helper to draw the grid and red borders
  void _drawWorldLimits(Canvas canvas) {
    Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double step = 100.0;
    for (double i = 0; i <= worldSize; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, worldSize), gridPaint);
      canvas.drawLine(Offset(0, i), Offset(worldSize, i), gridPaint);
    }

    // Red Danger Border
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize),
        Paint()..color = Colors.red.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 100);
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize),
        Paint()..color = Colors.redAccent..style = PaintingStyle.stroke..strokeWidth = 20);
  }

  void _drawSnake(
      Canvas canvas,
      List<Offset> body,
      double angle,
      List<Color> snakeColors, {
        String? name,
        Color eyeColor = Colors.white,
        bool showShield = false,
        NPCSize? npcSize,
      }) {
    if (body.isEmpty) return;

    // A reusable paint object for food to save memory
    final foodPainter = Paint()..style = PaintingStyle.fill;

    for (var f in foods) {
      double dist = (f.pos - playerPos).distance;
      if (dist < 900) {
        // 1. Precise Sizing
        double radius = f.isLoot ? (3.0 + f.size * 2.0) : 3.0;
        if (f.isLoot) {
          // Clean, thin glow (not a cloud)
          canvas.drawCircle(
              f.pos,
              radius + 2.5,
              Paint()..color = f.color.withOpacity(0.3)
          );
        }
        // 2. Crisp Core
        canvas.drawCircle(f.pos, radius, Paint()..color = f.color);
        // 3. The "Shine" (This makes it look like a bead/orb)
        canvas.drawCircle(
            f.pos - Offset(radius * 0.3, radius * 0.3),
            radius * 0.25,
            Paint()..color = Colors.white.withOpacity(0.9)
        );
      }
    }

    Offset headPos = body.first;
    // Base body radius driven by length
    double bodyRadius = 10.0 + (body.length / 80).clamp(0, 15);

    // Apply NPC size scaling
    if (npcSize != null) {
      final sizeScale = switch (npcSize) {
        NPCSize.small => 0.8,
        NPCSize.medium => 1.0,
        NPCSize.large => 1.1,
        NPCSize.xlarge => 1.3,
      };
      bodyRadius *= sizeScale;
    }

    const double headScale = 1.25;
    const double tailScale = 0.85;
    double headRadius = bodyRadius * headScale;

    int tailCount = body.length > 1 ? (body.length >= 4 ? 3 : body.length - 1) : 0;

    // --- OPTIMIZED SHADOWS ---
    Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Only draw shadow every 6 segments to save FPS
    for (int i = body.length - 1; i >= 0; i -= 12) {
      canvas.drawCircle(body[i] + const Offset(5, 5), bodyRadius, shadowPaint);
    }

    // --- DRAW BODY SEGMENTS ---
    // This is the correct loop for the body
    final bodyPaint = Paint()..isAntiAlias = true;

    for (int i = body.length - 1; i >= 0; i--) {
      int colorIndex = (i ~/ 4) % snakeColors.length;
      double currentRadius = (tailCount > 0 && i >= body.length - tailCount)
          ? bodyRadius * tailScale
          : bodyRadius;

      currentRadius += 0.2; // Slight overlap for smoothness
      bodyPaint.color = snakeColors[colorIndex];
      canvas.drawCircle(body[i], currentRadius, bodyPaint);
    }

    // --- HEAD ---
    canvas.save();
    canvas.translate(headPos.dx, headPos.dy);

    // Rotate to face the direction of movement
    canvas.rotate(angle + pi / 2);

    double hScale = headRadius / 48.0;
    final headPath = Path();

    // Start at the left "cheek"
    headPath.moveTo(-42 * hScale, 0);

    // FRONT SIDE: Keeps your original sleek look
    headPath.quadraticBezierTo(-45 * hScale, -45 * hScale, 0, -50 * hScale);
    headPath.quadraticBezierTo(45 * hScale, -45 * hScale, 42 * hScale, 0);

    // BODY SIDE (BACK): Changed to be more circular/rounded
    // We use a smaller Y value (15-20) to keep it tucked against the body segments
    headPath.quadraticBezierTo(40 * hScale, 25 * hScale, 0, 25 * hScale);
    headPath.quadraticBezierTo(-40 * hScale, 25 * hScale, -42 * hScale, 0);

    headPath.close();

    // Draw the head with the primary skin color
    canvas.drawPath(headPath, Paint()..color = snakeColors[1]..isAntiAlias = true);

    // Eyes
    canvas.drawCircle(Offset(-18 * hScale, -12 * hScale), 8 * hScale, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(18 * hScale, -12 * hScale), 8 * hScale, Paint()..color = eyeColor);

    // Pupils
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromCenter(center: Offset(-18 * hScale, -12 * hScale), width: 2.5 * hScale, height: 10 * hScale), pupilPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(18 * hScale, -12 * hScale), width: 2.5 * hScale, height: 10 * hScale), pupilPaint);

    canvas.restore();

    // Shield effect
    // --- SHIELD EFFECT (UPGRADED) ---
    if (showShield) {
      // 1. Outer Glow
      final Paint shieldGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12)
        ..color = Colors.cyanAccent.withOpacity(0.6);

      // 2. Inner Energy Field
      final Paint shieldField = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            Colors.cyanAccent.withOpacity(0.0), // Clear in the middle
            Colors.cyanAccent.withOpacity(0.2), // Faint blue near the edge
          ],
        ).createShader(Rect.fromCircle(center: headPos, radius: headRadius * 2.5));

      // Draw the glow ring
      canvas.drawCircle(headPos, headRadius * 2.2, shieldGlow);

      // Draw the semi-transparent field
      canvas.drawCircle(headPos, headRadius * 2.2, shieldField);
    }

    if (isBoosting) {
      // Draw a "flare" behind the head
      canvas.drawCircle(
          headPos - Offset(cos(angle) * 15, sin(angle) * 15),
          headRadius * 0.8,
          Paint()
            ..color = Colors.orangeAccent.withOpacity(0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      );
    }

    if (name != null) {
      final tp = TextPainter(
        text: TextSpan(text: name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, headPos + Offset(-tp.width / 2, -headRadius - 35));
    }
  }


  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}