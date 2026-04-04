import 'package:flutter/material.dart';
import '../constants.dart';

class AppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppConstants.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = AppConstants.primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    double w = size.width;
    double h = size.height;

    // Drawing a stylized futuristic "X" Controller shape
    // Left handle
    path.moveTo(w * 0.2, h * 0.4);
    path.quadraticBezierTo(w * 0.05, h * 0.4, w * 0.1, h * 0.8);
    path.quadraticBezierTo(w * 0.15, h * 0.95, w * 0.3, h * 0.85);

    // Middle section (The "X" bridge)
    path.lineTo(w * 0.7, h * 0.3);

    // Right handle
    path.moveTo(w * 0.8, h * 0.4);
    path.quadraticBezierTo(w * 0.95, h * 0.4, w * 0.9, h * 0.8);
    path.quadraticBezierTo(w * 0.85, h * 0.95, w * 0.7, h * 0.85);
    path.lineTo(w * 0.3, h * 0.3);

    // Draw glow first, then the sharp line
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Draw "Buttons" as neon circles
    canvas.drawCircle(Offset(w * 0.75, h * 0.5), 5, paint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.55), 5, paint);
    canvas.drawCircle(Offset(w * 0.2, h * 0.55), 6, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}