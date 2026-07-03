import 'package:flutter/material.dart';

const String nowPlayingCoverHeroTag = 'joyal-now-playing-cover';
const String nowPlayingPlayButtonHeroTag = 'joyal-now-playing-play-button';

class NowPlayingSharedHero extends StatelessWidget {
  final String tag;
  final Widget child;
  final bool useDestinationOnPop;
  final bool crossFadeOnPop;

  const NowPlayingSharedHero({
    super.key,
    required this.tag,
    required this.child,
    this.useDestinationOnPop = false,
    this.crossFadeOnPop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      createRectTween: (begin, end) =>
          NowPlayingElementRectTween(begin: begin, end: end),
      flightShuttleBuilder: (context, animation, direction, from, to) {
        final isPop = direction == HeroFlightDirection.pop;
        final flightChild = isPop && !useDestinationOnPop
            ? from.widget
            : to.widget;
        return AnimatedBuilder(
          animation: animation,
          child: flightChild,
          builder: (context, child) {
            final progress = animation.value.clamp(0.0, 1.0);
            final scale = 0.96 + 0.04 * Curves.easeOutCubic.transform(progress);
            final content = isPop && crossFadeOnPop
                ? _PopCrossFadeHeroFlight(
                    progress: progress,
                    from: from.widget,
                    to: to.widget,
                  )
                : child;
            return Transform.scale(
              scale: isPop ? 1.0 : scale,
              child: Material(type: MaterialType.transparency, child: content),
            );
          },
        );
      },
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _PopCrossFadeHeroFlight extends StatelessWidget {
  final double progress;
  final Widget from;
  final Widget to;

  const _PopCrossFadeHeroFlight({
    required this.progress,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final destinationOpacity = Curves.easeInOutCubic.transform(
      (1 - progress).clamp(0.0, 1.0),
    );
    final sourceOpacity = (1 - destinationOpacity).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: sourceOpacity, child: from),
        Opacity(opacity: destinationOpacity, child: to),
      ],
    );
  }
}

/// Keeps the current cover rotation phase stable across Hero flights and
/// widget rebuilds.
class RotatingNowPlayingCover extends StatefulWidget {
  final String trackId;
  final bool isPlaying;
  final Widget child;

  const RotatingNowPlayingCover({
    super.key,
    required this.trackId,
    required this.isPlaying,
    required this.child,
  });

  static double turnsFor(String trackId) =>
      _RotatingNowPlayingCoverState.rotationValueFor(trackId);

  @override
  State<RotatingNowPlayingCover> createState() =>
      _RotatingNowPlayingCoverState();
}

class _RotatingNowPlayingCoverState extends State<RotatingNowPlayingCover>
    with SingleTickerProviderStateMixin {
  static const Duration _rotationDuration = Duration(seconds: 12);
  static final Map<String, _CoverRotationSnapshot> _snapshots = {};

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _rotationDuration);
    _controller.value = rotationValueFor(widget.trackId);
    if (widget.isPlaying) {
      _controller.repeat();
      _storeSnapshot(widget.trackId, isPlaying: true);
    }
  }

  @override
  void didUpdateWidget(covariant RotatingNowPlayingCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackId != oldWidget.trackId) {
      _storeSnapshot(oldWidget.trackId, isPlaying: oldWidget.isPlaying);
      _controller.value = 0;
      _storeSnapshot(widget.trackId, isPlaying: widget.isPlaying);
    }
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.value = rotationValueFor(widget.trackId);
      _controller.repeat();
      _storeSnapshot(widget.trackId, isPlaying: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _storeSnapshot(widget.trackId, isPlaying: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }

  static double rotationValueFor(String trackId) {
    final snapshot = _snapshots[trackId];
    if (snapshot == null) return 0;

    var value = snapshot.value;
    if (snapshot.isPlaying) {
      final elapsed = DateTime.now().difference(snapshot.updatedAt);
      value += elapsed.inMicroseconds / _rotationDuration.inMicroseconds;
    }
    return value % 1;
  }

  void _storeSnapshot(String trackId, {required bool isPlaying}) {
    _snapshots[trackId] = _CoverRotationSnapshot(
      value: _controller.value % 1,
      updatedAt: DateTime.now(),
      isPlaying: isPlaying,
    );
  }

  @override
  void dispose() {
    _storeSnapshot(widget.trackId, isPlaying: widget.isPlaying);
    _controller.dispose();
    super.dispose();
  }
}

class _CoverRotationSnapshot {
  final double value;
  final DateTime updatedAt;
  final bool isPlaying;

  const _CoverRotationSnapshot({
    required this.value,
    required this.updatedAt,
    required this.isPlaying,
  });
}

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

class NowPlayingElementRectTween extends RectTween {
  NowPlayingElementRectTween({required super.begin, required super.end});

  static final Animatable<double> _motion = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1.02,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 82,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.02,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 18,
    ),
  ]);

  @override
  Rect lerp(double t) {
    return Rect.lerp(begin, end, _motion.transform(t.clamp(0.0, 1.0)))!;
  }
}
