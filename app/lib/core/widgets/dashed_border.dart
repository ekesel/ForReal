import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';

/// A 1 px dashed rounded outline around [child]. Dashed means "not confirmed".
class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child, required this.color, required this.radius});

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(foregroundPainter: _DashedPainter(color, radius), child: child);
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = math.min(radius, size.shortestSide / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(r)));
    const dash = 4.0;
    const gap = 3.0;
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, math.min(distance + dash, metric.length)), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter oldDelegate) => oldDelegate.color != color || oldDelegate.radius != radius;
}
