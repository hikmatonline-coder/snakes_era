import 'dart:math';
import 'package:flutter/material.dart';
import '../../model/snake_skin_model.dart';
import '../../provider/snake_game_provider.dart';
import '../widgets/snake_game_widget.dart';

class SnakeGamePainter extends CustomPainter {
  SnakeGamePainter({
    required Listenable repaint,
    required this.game,
    required this.skin,
  }) : super(repaint: repaint);

  final SnakeGameProvider game;
  final SnakeSkin skin;

  static const double _chunkSize = 500.0;

  final Paint _gridPaint = Paint()
    ..color = const Color(0x0DFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _borderPaint = Paint()
    ..color = const Color(0xFFFF0055)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8.0
    ..strokeCap = StrokeCap.square;

  final Paint _foodPaint = Paint()..style = PaintingStyle.fill;
  final Paint _foodHighlightPaint = Paint()..style = PaintingStyle.fill;
  final Paint _bodyPaint = Paint()..isAntiAlias = true;
  final Paint _shadowPaint = Paint()..color = const Color(0x42000000);
  final Paint _headPaint = Paint();
  final Paint _eyePaint = Paint();
  final Paint _shieldPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0x8000FFFF);
  final Paint _radarFillPaint = Paint()
    ..color = const Color(0xFF161616)
    ..style = PaintingStyle.fill;
  final Paint _radarStrokePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;
  final Paint _arrowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _crownPaint = Paint()..style = PaintingStyle.fill;
  final Paint _crownBasePaint = Paint()
    ..color = const Color(0x42000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final playerPos = game.playerPos;
    final playerBody = game.playerBody;
    final zoomFactor = 0.75;
    final boostZoom = game.isBoosting ? 0.9 : 1.0;
    final sizeZoom = (1.0 - (playerBody.length / 5000)).clamp(0.7, 1.0);
    final finalZoom = zoomFactor * boostZoom * sizeZoom;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(finalZoom);
    canvas.translate(-playerPos.dx, -playerPos.dy);

    _drawVisibleGrid(canvas, size, finalZoom, playerPos);
    _drawFoodViaChunks(canvas, size, finalZoom, playerPos);

    for (final npc in game.npcs) {
      if ((npc.pos - playerPos).distance < 1200 / finalZoom) {
        _drawSnake(
          canvas,
          npc.body,
          npc.angle,
          npc.colors,
          npcSize: npc.size,
        );
      }
    }

    _drawSnake(
      canvas,
      playerBody,
      game.playerAngle,
      skin.bodyColors,
      eyeColor: skin.eyeColor,
      showShield: game.isInvincible,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, game.worldSize, game.worldSize),
      _borderPaint,
    );

    canvas.restore();

    _drawCrownsAndRadar(canvas, size, playerPos, finalZoom);
  }

  void _drawCrownsAndRadar(
    Canvas canvas,
    Size size,
    Offset playerPos,
    double finalZoom,
  ) {
    final screenCenter = Offset(size.width / 2, size.height / 2);
    const padding = 40.0;

    for (int rank = 0; rank < game.crownTargets.length; rank++) {
      final targetSnake = game.crownTargets[rank];
      final targetWorldPos = targetSnake.pos;
      final canvasPos = screenCenter + (targetWorldPos - playerPos) * finalZoom;

      final isOnScreen = canvasPos.dx >= padding &&
          canvasPos.dx <= size.width - padding &&
          canvasPos.dy >= padding &&
          canvasPos.dy <= size.height - padding;

      final crownColor = rank == 0
          ? Colors.amber
          : (rank == 1 ? const Color(0xFFDCE2E6) : const Color(0xFFCD7F32));

      var bodyRadius = 10.0 + (targetSnake.length / 80).clamp(0, 15);
      if (targetSnake.npcSize != null) {
        final nSize = targetSnake.npcSize!;
        bodyRadius *= nSize == NPCSize.small
            ? 0.8
            : nSize == NPCSize.xlarge
                ? 1.3
                : 1.0;
      }
      final scaledRadius = bodyRadius * finalZoom;

      if (isOnScreen) {
        _paintCrownOnly(
          canvas,
          canvasPos + Offset(0, -scaledRadius - 12),
          crownColor,
        );
      } else {
        if (targetSnake.isPlayer) continue;

        var dir = targetWorldPos - playerPos;
        if (dir.distance > 0) {
          dir = dir / dir.distance;
        }

        final xMax = size.width / 2 - padding;
        final yMax = size.height / 2 - padding;
        final factorX =
            dir.dx != 0 ? (xMax / dir.dx.abs()) : double.infinity;
        final factorY =
            dir.dy != 0 ? (yMax / dir.dy.abs()) : double.infinity;
        final factor = factorX < factorY ? factorX : factorY;

        _paintEdgeRadar(
          canvas,
          screenCenter + dir * factor,
          dir.direction,
          crownColor,
        );
      }
    }
  }

  void _paintCrownOnly(Canvas canvas, Offset center, Color color) {
    final path = Path();
    const w = 20.0;
    const h = 12.0;

    path
      ..moveTo(center.dx - w / 2, center.dy + h / 2)
      ..lineTo(center.dx - w / 2, center.dy - h / 4)
      ..lineTo(center.dx - w / 3, center.dy - h / 2)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + w / 3, center.dy - h / 2)
      ..lineTo(center.dx + w / 2, center.dy - h / 4)
      ..lineTo(center.dx + w / 2, center.dy + h / 2)
      ..close();

    _crownPaint.color = color;
    canvas.drawPath(path, _crownPaint);
    canvas.drawLine(
      Offset(center.dx - w / 2, center.dy + h / 2 - 1.5),
      Offset(center.dx + w / 2, center.dy + h / 2 - 1.5),
      _crownBasePaint,
    );
  }

  void _paintEdgeRadar(
    Canvas canvas,
    Offset edgePos,
    double angle,
    Color color,
  ) {
    canvas.drawCircle(edgePos, 16, _radarFillPaint);
    _radarStrokePaint.color = color.withOpacity(0.7);
    canvas.drawCircle(edgePos, 16, _radarStrokePaint);

    canvas.save();
    canvas.translate(edgePos.dx, edgePos.dy);
    canvas.rotate(angle);

    final arrowPath = Path()
      ..moveTo(10, 0)
      ..lineTo(3, -4)
      ..lineTo(5, 0)
      ..lineTo(3, 4)
      ..close();

    _arrowPaint.color = color;
    canvas.drawPath(arrowPath, _arrowPaint);
    canvas.restore();

    _paintCrownOnly(canvas, edgePos + const Offset(0, -1), color);
  }

  void _drawFoodViaChunks(
    Canvas canvas,
    Size size,
    double zoom,
    Offset playerPos,
  ) {
    final screenW = size.width / zoom;
    final screenH = size.height / zoom;

    final startX = ((playerPos.dx - screenW / 2) / _chunkSize).floor();
    final endX = ((playerPos.dx + screenW / 2) / _chunkSize).floor();
    final startY = ((playerPos.dy - screenH / 2) / _chunkSize).floor();
    final endY = ((playerPos.dy + screenH / 2) / _chunkSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        final chunk = game.chunkedFoods['$x,$y'];
        if (chunk == null) continue;

        for (final f in chunk) {
          final radius = f.isLoot ? 10.0 : (f.type == 0 ? 3.5 : 6.0);
          var calculatedColor = f.color;
          if (f.isLoot && game.isLootBlinkingState) {
            calculatedColor = f.color.withOpacity(0.15);
          }

          _foodPaint.color = calculatedColor;
          canvas.drawCircle(f.pos, radius, _foodPaint);

          if (radius >= 6.0) {
            _foodHighlightPaint.color = Colors.white.withOpacity(
              f.isLoot && game.isLootBlinkingState ? 0.15 : 0.45,
            );
            canvas.drawCircle(
              f.pos - Offset(radius * 0.3, radius * 0.3),
              radius * 0.25,
              _foodHighlightPaint,
            );
          }
        }
      }
    }
  }

  void _drawVisibleGrid(
    Canvas canvas,
    Size size,
    double zoom,
    Offset playerPos,
  ) {
    final screenW = size.width / zoom;
    final screenH = size.height / zoom;

    final left = (playerPos.dx - screenW / 2).clamp(0.0, game.worldSize);
    final right = (playerPos.dx + screenW / 2).clamp(0.0, game.worldSize);
    final top = (playerPos.dy - screenH / 2).clamp(0.0, game.worldSize);
    final bottom = (playerPos.dy + screenH / 2).clamp(0.0, game.worldSize);

    for (double i = (left / 100).floor() * 100.0; i <= right; i += 100.0) {
      canvas.drawLine(Offset(i, top), Offset(i, bottom), _gridPaint);
    }
    for (double i = (top / 100).floor() * 100.0; i <= bottom; i += 100.0) {
      canvas.drawLine(Offset(left, i), Offset(right, i), _gridPaint);
    }
  }

  void _drawSnake(
    Canvas canvas,
    List<Offset> body,
    double angle,
    List<Color> colors, {
    Color eyeColor = Colors.white,
    bool showShield = false,
    NPCSize? npcSize,
  }) {
    if (body.isEmpty) return;

    final headPos = body.first;
    var bodyRadius = 10.0 + (body.length / 80).clamp(0, 15);
    if (npcSize != null) {
      bodyRadius *= npcSize == NPCSize.small
          ? 0.8
          : npcSize == NPCSize.xlarge
              ? 1.3
              : 1.0;
    }

    final drawStep = body.length > 120 ? 2 : 1;

    for (int i = body.length - 1; i >= 0; i -= 15) {
      canvas.drawCircle(
        body[i] + const Offset(2, 2),
        bodyRadius,
        _shadowPaint,
      );
    }

    for (int i = body.length - 1; i >= 0; i -= drawStep) {
      _bodyPaint.color = colors[(i ~/ 4) % colors.length];
      canvas.drawCircle(body[i], bodyRadius, _bodyPaint);
    }

    _drawHead(canvas, headPos, angle, bodyRadius, colors[1], eyeColor);

    if (showShield) {
      canvas.drawCircle(headPos, bodyRadius * 2.5, _shieldPaint);
    }
  }

  void _drawHead(
    Canvas canvas,
    Offset pos,
    double angle,
    double radius,
    Color color,
    Color eyeColor,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + pi / 2);

    final s = (radius * 1.25) / 48.0;
    final path = Path()
      ..moveTo(-42 * s, 0)
      ..quadraticBezierTo(-45 * s, -45 * s, 0, -50 * s)
      ..quadraticBezierTo(45 * s, -45 * s, 42 * s, 0)
      ..quadraticBezierTo(0, 25 * s, -42 * s, 0)
      ..close();

    _headPaint.color = color;
    canvas.drawPath(path, _headPaint);
    _eyePaint.color = eyeColor;
    canvas.drawCircle(Offset(-18 * s, -12 * s), 8 * s, _eyePaint);
    canvas.drawCircle(Offset(18 * s, -12 * s), 8 * s, _eyePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SnakeGamePainter oldDelegate) => false;
}
