import 'dart:math';
import 'package:flutter/material.dart';

class SimpleSnakePainter extends CustomPainter {
  final List<Color> bodyColors;
  final Color eyeColor;
  final Color tongueColor;

  SimpleSnakePainter({
    required this.bodyColors,
    required this.eyeColor,
    required this.tongueColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bodyColors.isEmpty) return;

    // Use the smallest dimension to ensure the snake scales to fit the box
    final double scaleFactor = size.width / 300;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    // Move the origin to center so math is easier
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleFactor);

    final paint = Paint()..style = PaintingStyle.fill;

    // --- 1. THE BODY ---
    int totalSegments = 55;
    for (int i = totalSegments; i > 0; i--) {
      double t = i / totalSegments;
      // Math remains the same, but now relative to 0,0
      double x = sin(t * 3 * pi) * (30 + t * 60);
      double y = -10 + (t * 180);
      double radius = 35.0 * (1 - t * 0.8);

      // Cycle colors properly
      paint.color = bodyColors[i % bodyColors.length];
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // --- 2. THE HEAD ---
    final headPos = const Offset(0, -10);
    final headPath = Path();
    final headColor = bodyColors[0];

    headPath.moveTo(headPos.dx - 42, headPos.dy + 7);
    headPath.quadraticBezierTo(headPos.dx - 48, headPos.dy - 35, headPos.dx, headPos.dy - 48);
    headPath.quadraticBezierTo(headPos.dx + 48, headPos.dy - 35, headPos.dx + 42, headPos.dy + 7);
    headPath.quadraticBezierTo(headPos.dx, headPos.dy + 35, headPos.dx - 42, headPos.dy + 7);
    headPath.close();

    canvas.drawShadow(headPath, Colors.black, 8, false);
    canvas.drawPath(headPath, Paint()..color = headColor);

    // --- 3. MOUTH & EYES ---
    canvas.drawArc(
        Rect.fromCenter(center: Offset(headPos.dx, headPos.dy + 7), width: 45, height: 20),
        0, pi, false, Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 3
    );

    final eyePaint = Paint()..color = eyeColor;
    canvas.drawCircle(Offset(headPos.dx - 18, headPos.dy - 12), 8.5, eyePaint);
    canvas.drawCircle(Offset(headPos.dx + 18, headPos.dy - 12), 8.5, eyePaint);

    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromCenter(center: Offset(headPos.dx - 18, headPos.dy - 12), width: 3, height: 11), pupilPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(headPos.dx + 18, headPos.dy - 12), width: 3, height: 11), pupilPaint);

    // --- 4. TONGUE ---
    final tonguePaint = Paint()
      ..color = tongueColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tonguePath = Path();
    double startY = headPos.dy + 18;
    tonguePath.moveTo(0, startY);
    tonguePath.quadraticBezierTo(-5, startY + 5, 0, startY + 11);
    tonguePath.quadraticBezierTo(5, startY + 16, 0, startY + 22);

    // Forks
    tonguePath.moveTo(0, startY + 22);
    tonguePath.lineTo(-5, startY + 30);
    tonguePath.moveTo(0, startY + 22);
    tonguePath.lineTo(5, startY + 30);

    canvas.drawPath(tonguePath, tonguePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SimpleSnakePainter oldDelegate) {
    // Better comparison: checks length and first color to detect changes
    return oldDelegate.bodyColors.length != bodyColors.length ||
        oldDelegate.bodyColors.first != bodyColors.first ||
        oldDelegate.eyeColor != eyeColor;
  }
}