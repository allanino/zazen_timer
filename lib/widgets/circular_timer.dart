import 'dart:math' as math;

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
    const double strokeWidth = 12.0;
    const double radiusPadding = 8.0;
    const Color baseColor = Color.fromARGB(255, 99, 104, 108);
    const Color brighterColor = Color(0xFF989DA3);


    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide / 2) - radiusPadding;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final double clampedFraction = fraction.clamp(0.0, 1.0);
    final double sweepAngle = 2 * math.pi * clampedFraction;
    final double epsilon = strokeWidth / radius;
    const double startAngle = -math.pi / 2;

    // Base ring: translucent ring (fluid background, anchored in #BCBCBC).
    final Paint basePaint = Paint()
      ..color = baseColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    if (clampedFraction <= 0) {
      // No progress yet: show a full, continuous base ring.
      canvas.drawArc(rect, 0, 2 * math.pi, false, basePaint);
      return;
    }
    // With progress: still draw a full continuous base ring so the track
    // feels unbroken underneath the brighter progress segment.
    canvas.drawArc(rect, 0, 2 * math.pi, false, basePaint);

    // Blend the bright core towards baseColor as the arc shrinks,
    // so the gradient fades out naturally instead of switching abruptly.
    final double t = clampedFraction.clamp(0.0, 1.0);
    final Color coreColor = Color.lerp(baseColor, brighterColor.withOpacity(0.95), t)!;
    final Color trailColor = Color.lerp(baseColor, baseColor.withOpacity(0.1), t)!;

    {
      const double capStop = 0.02;
      final double effectiveCapStop = math.min(capStop, clampedFraction);
      final double midStop = (effectiveCapStop + clampedFraction) * 0.5;
      final SweepGradient progressGradient = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: <Color>[
          baseColor,
          baseColor,
          coreColor,
          trailColor,
          trailColor,
        ],
        stops: <double>[
          0.0,
          capStop,
          midStop,
          clampedFraction,
          1.0,
        ],
        transform: const GradientRotation(startAngle),
      );

      // Glow layer
      final double glowStart = startAngle + epsilon;
      final double glowSweep = math.max(0.0, sweepAngle - epsilon);
      if (glowSweep > 0) {
        final Paint glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true
          ..shader = progressGradient.createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

        canvas.drawArc(rect, glowStart, glowSweep, false, glowPaint);
      }

      // Main progress arc — same gradient, no blur (crispy edge)
      final Paint progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..shader = progressGradient.createShader(rect);

      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }

    // Round cap painted on top at 12h so when the ring is full
    // (or nearly full) there's no straight seam — just a clean dome.
    final Offset topPoint = Offset(center.dx, center.dy - radius);
    final Paint capPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(topPoint, strokeWidth / 2, capPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

