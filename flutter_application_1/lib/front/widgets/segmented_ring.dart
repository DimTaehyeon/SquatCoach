import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 4조각으로 나뉜 둥근 링 (카운트다운, 세트 사이 휴식 화면).
/// [progress] 0~1 만큼 조각이 [color]로 채워지고 나머지는 [trackColor]입니다.
class SegmentedRing extends StatelessWidget {
  const SegmentedRing({
    super.key,
    required this.size,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 10,
    this.segments = 4,
  });

  final double size;
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final int segments;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RingPainter(progress, color, trackColor, strokeWidth, segments)),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.trackColor, this.strokeWidth, this.segments);

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const gap = 0.34; // 조각 사이 간격(라디안)
    final step = 2 * math.pi / segments;
    final sweep = step - gap;

    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * step + gap / 2;
      canvas.drawArc(rect, start, sweep, false, track);
      final f = (progress * segments - i).clamp(0.0, 1.0).toDouble();
      if (f > 0) {
        canvas.drawArc(rect, start, sweep * f, false, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.trackColor != trackColor;
}
