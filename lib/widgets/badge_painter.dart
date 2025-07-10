import 'package:flutter/material.dart';

class BadgePainter extends CustomPainter {
  final List<Color> rimColors;
  final Color surfaceColor;
  final bool isUnlocked;

  BadgePainter({
    required this.rimColors,
    required this.surfaceColor,
    required this.isUnlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Classic Shield Shape
    path.moveTo(0, 0);
    path.lineTo(w, 0); // Top flat
    path.lineTo(w, h * 0.6); // Right side down

    // Bottom curve to point
    path.quadraticBezierTo(w, h * 0.9, w * 0.5, h);
    path.quadraticBezierTo(0, h * 0.9, 0, h * 0.6);

    path.close();

    // 1. Draw Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.4), 8.0, true);

    // 2. Draw Inner Surface (Fill)
    final fillPaint = Paint()..style = PaintingStyle.fill;

    if (isUnlocked) {
      fillPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [surfaceColor.withOpacity(0.9), surfaceColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    } else {
      fillPaint.color = surfaceColor;
    }
    canvas.drawPath(path, fillPaint);

    // 3. Draw Rim (Stroke)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          w *
          0.08 // 8% of size as border
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: rimColors,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Clip to path to ensure stroke doesn't spill out?
    // Actually, normally badges have borders ON the edge.
    // Standard stroke assumes center.
    // If we want "Inner Border" look (clean outer edge), we can clip.
    // If we want "Thick Frame", centering is fine.
    // Let's stick to standard stroke for now, it's robust.
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant BadgePainter oldDelegate) {
    return oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.isUnlocked != isUnlocked;
  }
}
