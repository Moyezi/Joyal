import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Returns the vertical offset for a glyph's print bounce.
///
/// A fractional glyph progress of 0.5 reaches the peak: 10% of the font size
/// above the baseline. Integer progress means the glyph has settled.
double lyricPrintGlyphBounceOffset(double progress, double fontSize) {
  if (progress <= 0 || fontSize <= 0) return 0;
  final phase = progress - progress.floor();
  if (phase <= 0) return 0;
  return -fontSize * 0.10 * math.sin(math.pi * phase);
}

/// Short decay used by the blurred print stamp at the reveal frontier.
double lyricPrintStampPulse(double progress) {
  if (progress <= 0) return 0;
  final phase = progress - progress.floor();
  if (phase <= 0) return 0;
  return 1 - Curves.easeOutCubic.transform(phase.clamp(0.0, 1.0));
}

/// Keeps the current glyph/token in its AI color, then fades it back to the
/// renderer's default color after the next glyph/token starts.
double lyricAiColorIntensity({
  required Duration position,
  required Duration start,
  Duration? nextStart,
  Duration transition = const Duration(milliseconds: 280),
}) {
  if (position < start) return 0;
  if (nextStart == null || position <= nextStart) return 1;
  if (transition <= Duration.zero) return 0;
  final elapsed = position - nextStart;
  if (elapsed >= transition) return 0;
  final progress = elapsed.inMicroseconds / transition.inMicroseconds;
  return 1 - Curves.easeInOutSine.transform(progress.clamp(0.0, 1.0));
}
