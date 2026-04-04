import 'dart:math';
import 'package:flutter/material.dart';
import '../constants.dart';

class SpinWheelPainter extends CustomPainter {
  final List<String> labels;
  SpinWheelPainter(this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double angle = 2 * pi / labels.length;

    for (int i = 0; i < labels.length; i++) {
      // 1. Draw Slice with Gradient
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            i % 2 == 0 ? AppConstants.deepPurpleColor.withOpacity(0.8) : AppConstants.cardBg,
            i % 2 == 0 ? AppConstants.deepPurpleColor.withOpacity(0.6) : Colors.black,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromLTWH(0, 0, size.width, size.height),
        i * angle,
        angle,
        true,
        paint,
      );

      // 2. Draw Text Labels
      canvas.save();
      canvas.translate(radius, radius);
      canvas.rotate(i * angle + angle / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Position text near the outer edge
      textPainter.paint(canvas, Offset(radius * 0.4, -textPainter.height / 2));
      canvas.restore();

      // 3. Draw Border Lines
      final linePaint = Paint()
        ..color = AppConstants.primaryColor.withOpacity(0.2)
        ..strokeWidth = 1;
      canvas.drawLine(center,
          Offset(center.dx + radius * cos(i * angle), center.dy + radius * sin(i * angle)),
          linePaint);
    }

    // 4. Outer Neon Ring
    final ringPaint = Paint()
      ..color = AppConstants.deepPurpleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}