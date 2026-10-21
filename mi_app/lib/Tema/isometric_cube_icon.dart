import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ícono de cubo isométrico simple en contorno (sin esquinas de escáner ni marcos).
class IsometricCubeIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const IsometricCubeIcon({
    super.key,
    this.size = 22,
    required this.color,
    this.strokeWidth = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _IsometricCubePainter(
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _IsometricCubePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _IsometricCubePainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - strokeWidth;
    final w = r * (math.sqrt(3) / 2);
    final h = r * 0.5;

    // Vértices del hexágono exterior
    final vTop = Offset(cx, cy - r);
    final vTopRight = Offset(cx + w, cy - h);
    final vBottomRight = Offset(cx + w, cy + h);
    final vBottom = Offset(cx, cy + r);
    final vBottomLeft = Offset(cx - w, cy + h);
    final vTopLeft = Offset(cx - w, cy - h);
    final center = Offset(cx, cy);

    // Contorno exterior
    final pathOuter = Path()
      ..moveTo(vTop.dx, vTop.dy)
      ..lineTo(vTopRight.dx, vTopRight.dy)
      ..lineTo(vBottomRight.dx, vBottomRight.dy)
      ..lineTo(vBottom.dx, vBottom.dy)
      ..lineTo(vBottomLeft.dx, vBottomLeft.dy)
      ..lineTo(vTopLeft.dx, vTopLeft.dy)
      ..close();

    canvas.drawPath(pathOuter, paint);

    // Aristas interiores (del centro a los tres vértices que forman la perspectiva isométrica)
    final pathInner = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(vTopLeft.dx, vTopLeft.dy)
      ..moveTo(center.dx, center.dy)
      ..lineTo(vTopRight.dx, vTopRight.dy)
      ..moveTo(center.dx, center.dy)
      ..lineTo(vBottom.dx, vBottom.dy);

    canvas.drawPath(pathInner, paint);
  }

  @override
  bool shouldRepaint(covariant _IsometricCubePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
