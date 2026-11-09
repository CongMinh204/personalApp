import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vòng tròn tiến độ lớn với nội dung ở giữa. [fraction] là phần vòng được tô
/// (1 = đầy vòng), bắt đầu từ đỉnh và chạy theo chiều kim đồng hồ.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.child,
    this.size = 264,
    this.strokeWidth = 12,
  });

  final double fraction;
  final Widget child;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              fraction: fraction.clamp(0.0, 1.0),
              track: scheme.surfaceContainerHighest,
              color: scheme.primary,
              strokeWidth: strokeWidth,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.track,
    required this.color,
    required this.strokeWidth,
  });

  final double fraction;
  final Color track;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, 2 * math.pi, false, base..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
