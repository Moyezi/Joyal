import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';

class DonutSegment {
  final Color color;
  final double value;

  const DonutSegment({required this.color, required this.value});
}

class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final String centerText;
  final String centerSubtext;
  final bool isLoading;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerText,
    required this.centerSubtext,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(190),
            painter: _DonutChartPainter(
              segments: segments,
              trackColor: AppTheme.surfaceLight,
            ),
          ),
          if (isLoading)
            const SizedBox.square(
              dimension: 34,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerText,
                  style: context.textTitleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  centerSubtext,
                  style: context.textCaption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final Color trackColor;

  const _DonutChartPainter({required this.segments, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    paint.color = trackColor;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 2,
      false,
      paint,
    );

    final total = segments.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * math.pi * 2;
      paint.color = segment.color;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        start,
        math.max(0.02, sweep - 0.035),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.trackColor != trackColor;
  }
}
