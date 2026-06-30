import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';

/// An interactive progress bar with ripple breathing columns.
///
/// When playing, a zone of bars around the current position breathes with a
/// traveling-wave ripple. When dragging, the ripple follows the finger and
/// nearby bars are magnetically amplified. Bars outside the active zone stay
/// at a uniform resting height.
class WaveformProgress extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final String trackKey;
  final bool isPlaying;
  final Future<void> Function(Duration position) onSeek;
  final int barCount;
  final double barFillRatio;
  final Color playedColor;
  final Color unplayedColor;

  const WaveformProgress({
    super.key,
    required this.position,
    required this.duration,
    required this.trackKey,
    required this.isPlaying,
    required this.onSeek,
    this.barCount = 72,
    this.barFillRatio = 0.48,
    this.playedColor = AppTheme.waveformPlayed,
    this.unplayedColor = AppTheme.waveformUnplayed,
  });

  /// Dark-mode static defaults for use without a per-song palette.
  static const Color darkPlayedDefault = Color(0xFFDEDEDE);
  static const Color darkUnplayedDefault = Color(0xFF2C2C2C);

  @override
  State<WaveformProgress> createState() => _WaveformProgressState();
}

class _WaveformProgressState extends State<WaveformProgress>
    with TickerProviderStateMixin {
  late final AnimationController _ripplePhaseController;
  late final AnimationController _rippleFadeController;
  late final AnimationController _dragMorphController;
  late final Animation<double> _dragMorph;
  double? _dragFraction;
  double? _settlingDragFraction;
  int _lastHapticStep = -1;
  bool _isSeeking = false;

  double get _streamFraction => widget.duration.inMilliseconds > 0
      ? (widget.position.inMilliseconds / widget.duration.inMilliseconds).clamp(
          0.0,
          1.0,
        )
      : 0;

  double get _displayFraction => _dragFraction ?? _streamFraction;

  @override
  void initState() {
    super.initState();
    _ripplePhaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _rippleFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _dragMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 340),
    );
    _dragMorph = CurvedAnimation(
      parent: _dragMorphController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    );
    _syncRipple();
  }

  @override
  void didUpdateWidget(covariant WaveformProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackKey != oldWidget.trackKey) {
      _dragFraction = null;
      _settlingDragFraction = null;
    }
    if (widget.isPlaying != oldWidget.isPlaying) _syncRipple();
  }

  void _syncRipple() {
    if (widget.isPlaying) {
      _ripplePhaseController.repeat();
      _rippleFadeController.forward();
    } else {
      _ripplePhaseController.stop();
    }
  }

  double _fractionFor(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  void _updateDrag(double fraction) {
    final hapticStep = (fraction * 20).floor();
    if (hapticStep != _lastHapticStep) {
      _lastHapticStep = hapticStep;
      HapticFeedback.selectionClick();
    }
    _dragMorphController.forward();
    setState(() => _dragFraction = fraction);
  }

  void _releaseDragMorph() {
    _dragMorphController.reverse().whenComplete(() {
      if (mounted && _dragMorphController.value <= 0) {
        setState(() => _settlingDragFraction = null);
      }
    });
  }

  Future<void> _commitSeek(double fraction) async {
    if (widget.duration <= Duration.zero || _isSeeking) return;
    setState(() {
      _dragFraction = fraction;
      _isSeeking = true;
    });
    HapticFeedback.lightImpact();
    try {
      await widget.onSeek(widget.duration * fraction);
    } finally {
      if (mounted) {
        setState(() {
          _settlingDragFraction = _dragFraction ?? fraction;
          _dragFraction = null;
          _isSeeking = false;
          _lastHapticStep = -1;
        });
        _releaseDragMorph();
      }
    }
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final canSeek = widget.duration > Duration.zero;
    return Semantics(
      label: '播放进度',
      value: _formatDuration(widget.duration * _displayFraction),
      slider: true,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: canSeek
              ? (details) => _commitSeek(
                  _fractionFor(details.localPosition.dx, constraints.maxWidth),
                )
              : null,
          onHorizontalDragStart: canSeek
              ? (details) => _updateDrag(
                  _fractionFor(details.localPosition.dx, constraints.maxWidth),
                )
              : null,
          onHorizontalDragUpdate: canSeek
              ? (details) => _updateDrag(
                  _fractionFor(details.localPosition.dx, constraints.maxWidth),
                )
              : null,
          onHorizontalDragEnd: canSeek
              ? (_) => _commitSeek(_dragFraction ?? _streamFraction)
              : null,
          onHorizontalDragCancel: () {
            setState(() {
              _settlingDragFraction = _dragFraction;
              _dragFraction = null;
            });
            _releaseDragMorph();
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _ripplePhaseController,
              _rippleFadeController,
              _dragMorphController,
            ]),
            builder: (context, _) {
              final dragIntensity = _dragMorph.value.clamp(0.0, 1.0);
              final effectiveDragFraction =
                  WaveformGeometry.effectiveDragFraction(
                    dragFraction: _dragFraction,
                    settlingDragFraction: _settlingDragFraction,
                    dragIntensity: dragIntensity,
                  );
              return SizedBox(
                height: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          barCount: widget.barCount,
                          centerFraction: _displayFraction,
                          barFillRatio: widget.barFillRatio,
                          ripplePhase:
                              _ripplePhaseController.value * 2 * 3.14159,
                          rippleAlpha: _rippleFadeController.value.clamp(
                            0.0,
                            1.0,
                          ),
                          activeHalfWidth: WaveformGeometry.activeHalfWidth(
                            widget.barCount,
                          ),
                          activeColor: widget.playedColor,
                          inactiveColor: widget.unplayedColor,
                          dragFraction: effectiveDragFraction,
                          dragIntensity: dragIntensity,
                        ),
                      ),
                    ),
                    if (_dragFraction != null)
                      Positioned(
                        left: (_displayFraction * constraints.maxWidth - 28)
                            .clamp(0.0, max(0.0, constraints.maxWidth - 56)),
                        top: 0,
                        child: Container(
                          width: 56,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: context.surfaceHighlightColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _formatDuration(widget.duration * _displayFraction),
                            textAlign: TextAlign.center,
                            style: context.textCaption.copyWith(
                              color: context.primaryColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ripplePhaseController.dispose();
    _rippleFadeController.dispose();
    _dragMorphController.dispose();
    super.dispose();
  }
}

class WaveformGeometry {
  WaveformGeometry._();

  /// Active zone half-width in bar-fraction space.
  ///
  /// Returns a fixed ~7% of the total bar range, which translates to ~5 bars
  /// for the default [barCount] of 72.
  static double activeHalfWidth(int barCount) {
    // Use a fixed fraction so the visual zone is proportional.
    return 1.0 / barCount * (barCount * 0.07);
  }

  /// Height of a bar at [barFraction] within the ripple active zone.
  ///
  /// [centerFraction] is the playback or drag position (0–1).
  /// [phase] drives the traveling wave; incrementing phase moves peaks outward.
  /// [activeHalfWidth] defines the zone radius.
  /// [staticHeight] is the at-rest height.
  ///
  /// Returns a height between [staticHeight] and ~2× [staticHeight].
  static double rippleHeight({
    required double barFraction,
    required double centerFraction,
    required double phase,
    required double activeHalfWidth,
    required double staticHeight,
  }) {
    final distance = (barFraction - centerFraction).abs();
    if (distance > activeHalfWidth) return staticHeight;

    final normalizedDist = distance / activeHalfWidth; // 0→1
    final envelope = cos(normalizedDist * pi / 2); // 1 at center, 0 at edge
    final ripple = sin(normalizedDist * 2 * pi - phase); // traveling wave
    // Amplitude: 16.2px baseline lift + 5.4px ripple swing → [22.8, 33.6] at center
    return (staticHeight + envelope * (16.2 + ripple * 5.4)).clamp(3.0, 48.0);
  }

  static double morphedHeight({
    required double baseEnergy,
    required double barFraction,
    required double? dragFraction,
    required double dragIntensity,
    required double maxHeight,
    double pulseScale = 1,
  }) {
    final safeDragIntensity = dragIntensity.clamp(0.0, 1.0);
    final normalHeight = baseEnergy * maxHeight * pulseScale;
    if (dragFraction == null || safeDragIntensity <= 0) {
      return normalHeight.clamp(3.0, maxHeight);
    }

    final distance = (barFraction - dragFraction).abs();
    final localInfluence = (1 - distance / 0.18).clamp(0.0, 1.0);
    final easedInfluence = Curves.easeOutCubic.transform(localInfluence);
    final flattenedHeight = maxHeight * (0.18 + baseEnergy * 0.1);
    final magneticHeight = normalHeight * (1 + easedInfluence * 0.22);
    final dragHeight =
        flattenedHeight + (magneticHeight - flattenedHeight) * easedInfluence;
    return (normalHeight + (dragHeight - normalHeight) * safeDragIntensity)
        .clamp(3.0, maxHeight);
  }

  static double? effectiveDragFraction({
    required double? dragFraction,
    required double? settlingDragFraction,
    required double dragIntensity,
  }) {
    if (dragFraction != null) return dragFraction;
    return dragIntensity.clamp(0.0, 1.0) > 0 ? settlingDragFraction : null;
  }

  static Color barColor({
    required double barFraction,
    required double centerFraction,
    required Color activeColor,
    required Color inactiveColor,
    required double colorBlend,
  }) {
    final hasPlayed = barFraction <= centerFraction;
    final baseColor = hasPlayed ? activeColor : inactiveColor;
    return Color.lerp(baseColor, activeColor, colorBlend.clamp(0.0, 1.0))!;
  }
}

class _WaveformPainter extends CustomPainter {
  final int barCount;
  final double centerFraction;
  final double barFillRatio;
  final double ripplePhase;
  final double rippleAlpha;
  final double activeHalfWidth;
  final Color activeColor;
  final Color inactiveColor;
  final double? dragFraction;
  final double dragIntensity;

  _WaveformPainter({
    required this.barCount,
    required this.centerFraction,
    required this.barFillRatio,
    required this.ripplePhase,
    required this.rippleAlpha,
    required this.activeHalfWidth,
    required this.activeColor,
    required this.inactiveColor,
    required this.dragFraction,
    required this.dragIntensity,
  });

  static const double _staticHeight = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0) return;
    final barWidth = size.width / barCount;
    final drawWidth = max(2.0, barWidth * barFillRatio);
    final midY = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final barFraction = barCount == 1 ? 0.0 : i / (barCount - 1);

      // 1. Ripple height (only when rippleAlpha > 0)
      double height = _staticHeight;
      double colorBlend = 0.0;
      if (rippleAlpha > 0) {
        final distance = (barFraction - centerFraction).abs();
        if (distance < activeHalfWidth) {
          final rippleH = WaveformGeometry.rippleHeight(
            barFraction: barFraction,
            centerFraction: centerFraction,
            phase: ripplePhase,
            activeHalfWidth: activeHalfWidth,
            staticHeight: _staticHeight,
          );
          height = _staticHeight + (rippleH - _staticHeight) * rippleAlpha;
          // Smooth envelope for color blending — no hard on/off at boundary
          final envelope = cos(distance / activeHalfWidth * pi / 2);
          colorBlend = envelope * rippleAlpha;
        }
      }

      // 2. Magnetic drag morph overlay
      if (dragIntensity > 0 && dragFraction != null) {
        final baseEnergy = height / size.height;
        final magneticH = WaveformGeometry.morphedHeight(
          baseEnergy: baseEnergy,
          barFraction: barFraction,
          dragFraction: dragFraction,
          dragIntensity: dragIntensity,
          maxHeight: size.height,
        );
        height = height + (magneticH - height) * dragIntensity;
      }

      height = height.clamp(3.0, size.height);

      // 3. Coloring: smooth blend from inactiveColor → activeColor
      final color = WaveformGeometry.barColor(
        barFraction: barFraction,
        centerFraction: centerFraction,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        colorBlend: colorBlend,
      );

      final paint = Paint()..color = color;
      final x = i * barWidth + (barWidth - drawWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + drawWidth / 2, midY),
            width: drawWidth,
            height: height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.centerFraction != centerFraction ||
      oldDelegate.ripplePhase != ripplePhase ||
      oldDelegate.rippleAlpha != rippleAlpha ||
      oldDelegate.dragFraction != dragFraction ||
      oldDelegate.dragIntensity != dragIntensity ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.barCount != barCount;
}
