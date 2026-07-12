import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lyrics.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';

class FlowingLightLyricsStage extends StatelessWidget {
  final LyricsData data;
  final int activeIndex;
  final String title;
  final String artist;
  final Color activeColor;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool positionUpdatesEnabled;
  final VoidCallback onOpenSettings;
  final ValueChanged<Duration> onSeek;

  const FlowingLightLyricsStage({
    super.key,
    required this.data,
    required this.activeIndex,
    required this.title,
    required this.artist,
    required this.activeColor,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.positionUpdatesEnabled,
    required this.onOpenSettings,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIndex = activeIndex.clamp(0, data.lines.length - 1);
    final activeLine = data.lines[resolvedIndex];
    final previousLine = resolvedIndex > 0
        ? data.lines[resolvedIndex - 1]
        : null;
    final nextLine = resolvedIndex + 1 < data.lines.length
        ? data.lines[resolvedIndex + 1]
        : null;

    return _LyricsStageShell(
      title: title,
      artist: artist,
      foreground: activeColor,
      onOpenSettings: onOpenSettings,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 620),
        reverseDuration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.08, 0.045),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: _FlowingLightComposition(
          key: ValueKey(resolvedIndex),
          previousLine: previousLine,
          activeLine: activeLine,
          nextLine: nextLine,
          activeColor: activeColor,
          fontFamily: fontFamily,
          fontSize: fontSize,
          wordByWordEnabled: wordByWordEnabled,
          positionUpdatesEnabled: positionUpdatesEnabled,
          onSeek: onSeek,
        ),
      ),
    );
  }
}

class _LyricsStageShell extends StatefulWidget {
  final String title;
  final String artist;
  final Color foreground;
  final VoidCallback onOpenSettings;
  final Widget child;

  const _LyricsStageShell({
    required this.title,
    required this.artist,
    required this.foreground,
    required this.onOpenSettings,
    required this.child,
  });

  @override
  State<_LyricsStageShell> createState() => _LyricsStageShellState();
}

class _LyricsStageShellState extends State<_LyricsStageShell> {
  final Map<int, Offset> _pointers = {};
  double? _startDistance;
  bool _opened = false;

  double? get _distance {
    if (_pointers.length < 2) return null;
    final points = _pointers.values.take(2).toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _startDistance = _distance;
      _opened = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length < 2 || _opened) return;
    final start = _startDistance;
    final current = _distance;
    if (start == null || current == null || start < 24) return;
    if ((current - start).abs() < 28 && (current / start - 1).abs() < 0.12) {
      return;
    }
    _opened = true;
    widget.onOpenSettings();
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _startDistance = null;
      _opened = false;
    } else {
      _startDistance = _distance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, topInset + 86, 18, 24),
            child: widget.child,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: widget.foreground.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.foreground.withValues(alpha: 0.66),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowingLightComposition extends StatelessWidget {
  final LyricLine? previousLine;
  final LyricLine activeLine;
  final LyricLine? nextLine;
  final Color activeColor;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool positionUpdatesEnabled;
  final ValueChanged<Duration> onSeek;

  const _FlowingLightComposition({
    super.key,
    required this.previousLine,
    required this.activeLine,
    required this.nextLine,
    required this.activeColor,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.positionUpdatesEnabled,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final quietStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: activeColor.withValues(alpha: 0.26),
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (previousLine case final line?)
          Align(
            alignment: const Alignment(-0.82, -0.72),
            child: _SeekableStageLine(
              line: line,
              onSeek: onSeek,
              child: Transform.rotate(
                angle: -0.018,
                child: Text(
                  line.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: quietStyle,
                ),
              ),
            ),
          ),
        Align(
          alignment: const Alignment(0, -0.02),
          child: RepaintBoundary(
            child: _FlowingLightActiveLine(
              line: activeLine,
              activeColor: activeColor,
              fontFamily: fontFamily,
              fontSize: math.max(fontSize, 32),
              wordByWordEnabled: wordByWordEnabled,
              positionUpdatesEnabled: positionUpdatesEnabled,
            ),
          ),
        ),
        if (nextLine case final line?)
          Align(
            alignment: const Alignment(0.78, 0.72),
            child: _SeekableStageLine(
              line: line,
              onSeek: onSeek,
              child: Transform.rotate(
                angle: 0.014,
                child: Text(
                  line.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: quietStyle?.copyWith(
                    color: activeColor.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeekableStageLine extends StatelessWidget {
  final LyricLine line;
  final ValueChanged<Duration> onSeek;
  final Widget child;

  const _SeekableStageLine({
    required this.line,
    required this.onSeek,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: line.start == null ? null : () => onSeek(line.start!),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.68,
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

class _FlowingLightActiveLine extends ConsumerWidget {
  final LyricLine line;
  final Color activeColor;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool positionUpdatesEnabled;

  const _FlowingLightActiveLine({
    required this.line,
    required this.activeColor,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.positionUpdatesEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasWordTiming = line.words.any((word) => word.start != null);
    final hasLineTiming = line.start != null && line.end != null;
    final shouldTrack =
        positionUpdatesEnabled &&
        (hasLineTiming || (wordByWordEnabled && hasWordTiming));
    final position = shouldTrack
        ? ref.watch(playerProvider.select((state) => state.position))
        : line.start ?? Duration.zero;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: position.inMicroseconds.toDouble()),
      duration: const Duration(milliseconds: 180),
      curve: Curves.linear,
      builder: (context, microseconds, _) {
        final animatedPosition = Duration(microseconds: microseconds.round());
        final progress = _lineProgress(line, animatedPosition);
        final style = Theme.of(context).textTheme.headlineLarge!.copyWith(
          fontSize: fontSize,
          height: 1.18,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          color: activeColor,
          shadows: [
            Shadow(color: activeColor.withValues(alpha: 0.28), blurRadius: 22),
            Shadow(
              color: Colors.black.withValues(alpha: 0.2),
              offset: const Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        );
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FlowingLightPainter(
                    color: activeColor,
                    progress: progress,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 30),
              child: wordByWordEnabled && hasWordTiming
                  ? Text.rich(
                      TextSpan(
                        children: _timedGlyphs(
                          line,
                          animatedPosition,
                          style,
                          activeColor,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    )
                  : Text(line.text, textAlign: TextAlign.center, style: style),
            ),
          ],
        );
      },
    );
  }
}

List<InlineSpan> _timedGlyphs(
  LyricLine line,
  Duration position,
  TextStyle style,
  Color activeColor,
) {
  final spans = <InlineSpan>[];
  for (final word in line.words) {
    final glyphs = word.text.characters.toList(growable: false);
    for (var glyphIndex = 0; glyphIndex < glyphs.length; glyphIndex++) {
      final raw = lyricGlyphProgress(
        word,
        position,
        glyphIndex: glyphIndex,
        glyphCount: glyphs.length,
      );
      final progress = Curves.easeOutCubic.transform(raw);
      final frontier = (1 - (raw * 2 - 1).abs()).clamp(0.0, 1.0);
      spans.add(
        TextSpan(
          text: glyphs[glyphIndex],
          style: style.copyWith(
            color: Color.lerp(
              activeColor.withValues(alpha: 0.16),
              activeColor,
              progress,
            ),
            shadows: [
              ...?style.shadows,
              if (frontier > 0.02)
                Shadow(
                  color: Colors.white.withValues(alpha: 0.5 * frontier),
                  blurRadius: 16 * frontier,
                ),
            ],
          ),
        ),
      );
    }
  }
  return spans;
}

double _lineProgress(LyricLine line, Duration position) {
  final start = line.start;
  final end = line.end;
  if (start == null || end == null || end <= start) return 0.5;
  return ((position - start).inMicroseconds / (end - start).inMicroseconds)
      .clamp(0.0, 1.0)
      .toDouble();
}

class _FlowingLightPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _FlowingLightPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(
      size.width * (0.08 + progress * 0.84),
      size.height / 2,
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.055),
          Colors.transparent,
        ],
        stops: const [0, 0.42, 1],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.3));
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.62,
        height: math.min(108, size.height * 0.8),
      ),
      glowPaint,
    );

    final streakPaint = Paint()
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 1));
    final y = size.height * (0.42 + progress * 0.16);
    canvas.drawLine(
      Offset(size.width * 0.12, y),
      Offset(size.width * 0.88, y),
      streakPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FlowingLightPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
