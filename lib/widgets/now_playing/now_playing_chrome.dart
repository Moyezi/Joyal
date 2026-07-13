import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme.dart';

double lyricsSurfaceVisibilityForProgress(double progress) {
  final normalized = progress.clamp(0.0, 1.0).toDouble();
  return 1 - Curves.easeOut.transform(normalized);
}

class NowPlayingEntrance extends StatelessWidget {
  final Widget child;

  const NowPlayingEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) return child;

    return AnimatedBuilder(
      animation: routeAnimation,
      builder: (context, _) {
        final rawProgress = routeAnimation.value.clamp(0.0, 1.0);
        final revealProgress = Curves.easeOutCubic.transform(rawProgress);
        final dimProgress = Curves.easeInCubic.transform(rawProgress);
        final dimAlpha = routeAnimation.status == AnimationStatus.reverse
            ? 0.0
            : 0.34 * (1 - dimProgress);

        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final revealHeight = height * revealProgress.clamp(0.001, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: revealHeight,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: height,
                        child: child,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: dimAlpha),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class NowPlayingControlsEntrance extends StatelessWidget {
  final Widget child;

  const NowPlayingControlsEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) return child;

    return AnimatedBuilder(
      animation: routeAnimation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutQuart.transform(
          routeAnimation.value.clamp(0.0, 1.0),
        );
        final height = MediaQuery.sizeOf(context).height;
        return Transform.translate(
          offset: Offset(0, height * 0.16 * (1 - progress)),
          child: child,
        );
      },
    );
  }
}

class LyricsContentFade extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const LyricsContentFade({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: lyricsSurfaceVisibilityForProgress(animation.value),
        child: child,
      ),
    );
  }
}

class HeroCoverShapeFrame extends StatelessWidget {
  final double circleProgress;
  final double shadowOpacity;
  final Widget child;

  const HeroCoverShapeFrame({
    super.key,
    required this.circleProgress,
    required this.shadowOpacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final circleRadius = width.isFinite && height.isFinite
            ? math.min(width, height) / 2
            : AppTheme.radiusLarge;
        final radius = _lerp(
          AppTheme.radiusLarge,
          circleRadius,
          Curves.easeInOutCubic.transform(circleProgress.clamp(0.0, 1.0)),
        );

        final borderRadius = BorderRadius.circular(radius);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: _diffuseShadowWithOpacity(shadowOpacity),
          ),
          child: ClipRRect(borderRadius: borderRadius, child: child),
        );
      },
    );
  }

  List<BoxShadow> _diffuseShadowWithOpacity(double opacity) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    if (clampedOpacity == 0) return const [];
    return AppTheme.diffuseShadow
        .map(
          (shadow) => shadow.copyWith(
            color: shadow.color.withValues(
              alpha: shadow.color.a * clampedOpacity,
            ),
          ),
        )
        .toList();
  }

  double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
}

/// The immersive Now Playing detail screen.
///
/// Features:
/// - Large album cover with diffuse shadow
/// - Waveform progress bar (simulated)
/// - Full playback controls (shuffle, prev, play/pause, next, loop)
/// - Favorite and more options
