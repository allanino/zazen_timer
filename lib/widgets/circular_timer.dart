import 'package:flutter/material.dart';

import '../models.dart';

class CircularTimer extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final SessionStep step;

  const CircularTimer({
    super.key,
    required this.remaining,
    required this.total,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction =
        total.inMilliseconds == 0 ? 0.0 : remaining.inMilliseconds / total.inMilliseconds;
    final int minutes = remaining.inMinutes;
    final int seconds = remaining.inSeconds % 60;

    final String timeText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _RingPainter(fraction: fraction),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;

  _RingPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 10.0;
    final Rect rect = Offset.zero & size;
    final Offset center = rect.center;
    final double radius = (size.shortestSide - strokeWidth) / 2;

    final Paint bgPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint fgPaint = Paint()
      ..color = const Color(0xFFBCBCBC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    const double startAngle = -3.14159 / 2;
    final double sweepAngle = 2 * 3.14159 * fraction;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

