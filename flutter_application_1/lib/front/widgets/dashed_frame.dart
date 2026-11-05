import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 점선 둥근 사각형 테두리 (자세 분석 화면의 노란 가이드 프레임)
class DashedRRect extends StatelessWidget {
  const DashedRRect({
    super.key,
    required this.child,
    this.color = const Color(0xFFF2C230),
    this.radius = 24,
    this.strokeWidth = 2,
    this.dash = 8,
    this.gap = 6,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(color, radius, strokeWidth, dash, gap),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.radius, this.strokeWidth, this.dash, this.gap);

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}
