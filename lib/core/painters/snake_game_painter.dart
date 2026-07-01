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
  final bool isLootBlinkingState;

  SnakeGamePainter(this.playerPos, this.playerAngle, this.playerBody, this.foods, this.npcs, this.worldSize, this.activeSkin, this.isInvincible, this.chunkedFoods, this.isBoosting, this.isLootBlinkingState);

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

    // 🎯 FIX: 120px Solid Glowing Border Matrix (Saanp ko bachaane aur boundary highlight karne ke liye)
    final borderPaint = Paint()
      ..color = const Color(0xFFFF0055) // 🔥 Ultra-Solid Neon Red/Pink (Ek dum khatarnak aur saaf nazar aane wala color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 120.0
      ..strokeCap = StrokeCap.square; // Grid corners ko perfect corner banane ke liye square cap

    // 🌍 WORLD SIZE KA RECTANGLE (Border Draw karne ke liye)
    final Rect worldBounds = Rect.fromLTWH(0, 0, worldSize, worldSize);

    // 🖌️ CANVAS PAR MAIN SOLID BORDER DRAW KAREIN
    canvas.drawRect(worldBounds, borderPaint);

    // -----------------------------------------------------------------
    // 👑 RE-INJECTED: TOP 3 CROWNS & OFF-SCREEN RADAR ENGINE (SCREEN SPACE)
    // -----------------------------------------------------------------
    canvas.restore();

    // 1. Saare snakes ki current length aur positions ki list banayein
    List<Map<String, dynamic>> leaderList = [
      {
        'pos': playerPos,
        'length': playerBody.length,
        'isPlayer': true,
        'npcSize': null
      }
    ];

    for (var npc in npcs) {
      leaderList.add({
        'pos': npc.pos,
        'length': npc.body.length,
        'isPlayer': false,
        'npcSize': npc.size
      });
    }

    // Length ke mutabiq sort karein (Highest first)
    leaderList.sort((a, b) => b['length'].compareTo(a['length']));

    Offset screenCenter = Offset(size.width / 2, size.height / 2);
    double padding = 40.0; // Screen ke edges se safe distance

    // Top 3 positions par loop chalayein
    for (int rank = 0; rank < 3 && rank < leaderList.length; rank++) {
      var targetSnake = leaderList[rank];
      Offset targetWorldPos = targetSnake['pos'];

      // 🔄 Math Transformation: World Coordinate ko Screen Coordinate mein convert karein
      Offset canvasPos = screenCenter + (targetWorldPos - playerPos) * finalZoom;

      // Check karein kya target screen ke andar dikh raha hy?
      bool isOnScreen = canvasPos.dx >= padding &&
          canvasPos.dx <= size.width - padding &&
          canvasPos.dy >= padding &&
          canvasPos.dy <= size.height - padding;

      // Rank wise Colors: 1st Gold, 2nd Silver, 3rd Bronze
      Color crownColor = rank == 0
          ? Colors.amber
          : (rank == 1 ? const Color(0xFFDCE2E6) : const Color(0xFFCD7F32));

      // Saanp ke size ke mutabiq dynamic radius nikalna taake crown head ke perfect upar baithe
      double bodyRadius = 10.0 + (targetSnake['length'] / 80).clamp(0, 15);
      if (targetSnake['npcSize'] != null) {
        NPCSize nSize = targetSnake['npcSize'];
        bodyRadius *= (nSize == NPCSize.small ? 0.8 : nSize == NPCSize.xlarge ? 1.3 : 1.0);
      }
      double scaledRadius = bodyRadius * finalZoom;

      if (isOnScreen) {
        // 🎯 CASE A: Saanp samne hy -> Head ke upar crown draw karein
        _paintCrownOnly(canvas, canvasPos + Offset(0, -scaledRadius - 12), crownColor);
      } else {
        // 📡 CASE B: Saanp door hy -> Screen ke border par arrow indicator aur crown banao
        if (targetSnake['isPlayer']) continue; // Player kabhi off-screen nahi ho sakta

        Offset dir = targetWorldPos - playerPos;
        if (dir.distance > 0) {
          dir = dir / dir.distance; // Direction normalize karein
        }

        // Ray-Box Intersection taake border corners par radar crash na ho
        double xMax = size.width / 2 - padding;
        double yMax = size.height / 2 - padding;
        double factorX = dir.dx != 0 ? (xMax / dir.dx.abs()) : double.infinity;
        double factorY = dir.dy != 0 ? (yMax / dir.dy.abs()) : double.infinity;
        double factor = factorX < factorY ? factorX : factorY;

        Offset edgePos = screenCenter + dir * factor;

        // Border Pointer Render karein
        _paintEdgeRadar(canvas, edgePos, dir.direction, crownColor);
      }
    }
  }

  // --- HELPER PATH: RENDER CROWN SHAPE ---
  void _paintCrownOnly(Canvas canvas, Offset center, Color color) {
    final path = Path();
    double w = 20.0; // Crown Width
    double h = 12.0; // Crown Height

    path.moveTo(center.dx - w / 2, center.dy + h / 2);
    path.lineTo(center.dx - w / 2, center.dy - h / 4);
    path.lineTo(center.dx - w / 3, center.dy - h / 2); // Left peak
    path.lineTo(center.dx, center.dy);                // Valley
    path.lineTo(center.dx + w / 3, center.dy - h / 2); // Right peak
    path.lineTo(center.dx + w / 2, center.dy - h / 4);
    path.lineTo(center.dx + w / 2, center.dy + h / 2);
    path.close();

    final shadowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final basePaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(center.dx - w / 2, center.dy + h / 2 - 1.5),
      Offset(center.dx + w / 2, center.dy + h / 2 - 1.5),
      basePaint,
    );
  }

  // --- HELPER PATH: RENDER BORDER ARROW + MINI CROWN ---
  void _paintEdgeRadar(Canvas canvas, Offset edgePos, double angle, Color color) {
    canvas.drawCircle(edgePos, 16, Paint()..color = const Color(0xFF161616)..style = PaintingStyle.fill);
    canvas.drawCircle(edgePos, 16, Paint()..color = color.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    canvas.save();
    canvas.translate(edgePos.dx, edgePos.dy);
    canvas.rotate(angle);

    final arrowPath = Path()
      ..moveTo(10, 0)
      ..lineTo(3, -4)
      ..lineTo(5, 0)
      ..lineTo(3, 4)
      ..close();

    canvas.drawPath(arrowPath, Paint()..color = color..style = PaintingStyle.fill);
    canvas.restore();

    _paintCrownOnly(canvas, edgePos + const Offset(0, -1), color);
  }

  void _drawFoodViaChunks(Canvas canvas, Size size, double zoom) {
    double screenW = size.width / zoom;
    double screenH = size.height / zoom;

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
            double radius = f.isLoot ? 10.0 : (f.type == 0 ? 3.5 : 6.0);

            Color calculatedColor = f.color;
            if (f.isLoot && isLootBlinkingState) {
              calculatedColor = f.color.withOpacity(0.15);
            }

            if (f.isLoot) {
              canvas.drawCircle(
                  f.pos,
                  radius * 1.2,
                  Paint()
                    ..color = calculatedColor.withOpacity(1.0) // 🌟 Glow Opacity halki kar di
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5) // 🌟 Blur radius set kar diya
              );
            }

            paint.color = calculatedColor;
            canvas.drawCircle(f.pos, radius, paint);

            canvas.drawCircle(
                f.pos - Offset(radius * 0.3, radius * 0.3),
                radius * 0.25,
                Paint()..color = Colors.white.withOpacity(f.isLoot && isLootBlinkingState ? 0.15 : 0.6)
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

    // 🎯 CHAWAL FIXED: Pehle yahan nichay purana extra 20px black/red line draw ho raha tha jo map limits kharab kar raha tha, ab hum ne use saaf kar diya hy kyun ke upar perfect 120px solid boundary render ho rahi hy.
  }

  void _drawSnake(Canvas canvas, List<Offset> body, double angle, List<Color> colors, {String? name, Color eyeColor = Colors.white, bool showShield = false, NPCSize? npcSize}) {
    if (body.isEmpty) return;

    Offset headPos = body.first;
    double bodyRadius = 10.0 + (body.length / 80).clamp(0, 15);
    if (npcSize != null) {
      bodyRadius *= (npcSize == NPCSize.small ? 0.8 : npcSize == NPCSize.xlarge ? 1.3 : 1.0);
    }

    Paint shadowPaint = Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (int i = body.length - 1; i >= 0; i -= 15) {
      canvas.drawCircle(body[i] + const Offset(4, 4), bodyRadius, shadowPaint);
    }

    final bodyPaint = Paint()..isAntiAlias = true;
    for (int i = body.length - 1; i >= 0; i--) {
      bodyPaint.color = colors[(i ~/ 4) % colors.length];
      canvas.drawCircle(body[i], bodyRadius, bodyPaint);
    }

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