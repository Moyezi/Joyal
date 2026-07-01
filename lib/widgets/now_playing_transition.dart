import 'package:flutter/material.dart';

const String nowPlayingCoverHeroTag = 'joyal-now-playing-cover';

class NowPlayingCoverRectTween extends RectTween {
  NowPlayingCoverRectTween({required super.begin, required super.end});

  static final Animatable<double> _motion = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1.045,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 78,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.045,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 22,
    ),
  ]);

  @override
  Rect lerp(double t) {
    return Rect.lerp(begin, end, _motion.transform(t.clamp(0.0, 1.0)))!;
  }
}
