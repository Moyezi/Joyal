import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lyrics.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIndex = activeIndex.clamp(0, data.lines.length - 1);
    final activeLine = data.lines[resolvedIndex];

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
          activeLine: activeLine,
          activeColor: activeColor,
          fontFamily: fontFamily,
          fontSize: fontSize,
          wordByWordEnabled: wordByWordEnabled,
          positionUpdatesEnabled: positionUpdatesEnabled,
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
  final LyricLine activeLine;
  final Color activeColor;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool positionUpdatesEnabled;

  const _FlowingLightComposition({
    super.key,
    required this.activeLine,
    required this.activeColor,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.positionUpdatesEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.08),
      child: RepaintBoundary(
        child: _FlowingLightActiveLine(
          line: activeLine,
          activeColor: activeColor,
          fontFamily: fontFamily,
          fontSize: math.max(fontSize, 36),
          wordByWordEnabled: wordByWordEnabled,
          positionUpdatesEnabled: positionUpdatesEnabled,
        ),
      ),
    );
  }
}

@immutable
class FlowingLightToken {
  final String text;
  final Duration start;
  final Duration end;
  final bool isLatinWord;

  const FlowingLightToken({
    required this.text,
    required this.start,
    required this.end,
    required this.isLatinWord,
  });
}

List<FlowingLightToken> flowingLightTokensForLine(LyricLine line) {
  final tokens = <FlowingLightToken>[];
  for (var wordIndex = 0; wordIndex < line.words.length; wordIndex++) {
    final word = line.words[wordIndex];
    final glyphs = word.text.characters.toList(growable: false);
    if (glyphs.isEmpty) continue;
    final start = word.start ?? line.start;
    if (start == null) continue;
    final nextStart = wordIndex + 1 < line.words.length
        ? line.words[wordIndex + 1].start
        : null;
    final end = word.end ?? nextStart ?? line.end ?? start;
    final totalMicros = math.max(0, (end - start).inMicroseconds);
    final pieces = <({String text, bool latin, int weight})>[];
    var index = 0;
    while (index < glyphs.length) {
      if (_isWhitespace(glyphs[index])) {
        index++;
        continue;
      }
      final tokenStartIndex = index;
      final latin = _isLatinWordGlyph(glyphs[index]);
      if (latin) {
        while (index < glyphs.length && _isLatinWordGlyph(glyphs[index])) {
          index++;
        }
      } else {
        index++;
      }
      final tokenEndIndex = index;
      pieces.add((
        text: glyphs.sublist(tokenStartIndex, tokenEndIndex).join(),
        latin: latin,
        weight: tokenEndIndex - tokenStartIndex,
      ));
    }
    final totalWeight = pieces.fold<int>(0, (sum, piece) => sum + piece.weight);
    var elapsedWeight = 0;
    for (final piece in pieces) {
      final tokenStart =
          start +
          Duration(
            microseconds: totalWeight == 0
                ? 0
                : totalMicros * elapsedWeight ~/ totalWeight,
          );
      elapsedWeight += piece.weight;
      final tokenEnd =
          start +
          Duration(
            microseconds: totalWeight == 0
                ? 0
                : totalMicros * elapsedWeight ~/ totalWeight,
          );
      tokens.add(
        FlowingLightToken(
          text: piece.text,
          start: tokenStart,
          end: tokenEnd,
          isLatinWord: piece.latin,
        ),
      );
    }
  }
  return tokens;
}

bool _isWhitespace(String glyph) => glyph.trim().isEmpty;

bool _isLatinWordGlyph(String glyph) {
  return RegExp(r"^[A-Za-z0-9À-ÖØ-öø-ÿ'’_-]$").hasMatch(glyph);
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
    final tokens = flowingLightTokensForLine(line);
    final hasWordTiming = tokens.isNotEmpty;
    final shouldTrack =
        positionUpdatesEnabled && wordByWordEnabled && hasWordTiming;
    final position = shouldTrack
        ? ref.watch(playerProvider.select((state) => state.position))
        : ref.read(playerProvider).position;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: position.inMicroseconds.toDouble()),
      duration: const Duration(milliseconds: 180),
      curve: Curves.linear,
      builder: (context, microseconds, _) {
        final animatedPosition = Duration(microseconds: microseconds.round());
        final style = Theme.of(context).textTheme.headlineLarge!.copyWith(
          fontSize: fontSize,
          height: 1.12,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          color: activeColor,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        );
        if (!wordByWordEnabled || !hasWordTiming) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 30),
            child: Text(line.text, textAlign: TextAlign.center, style: style),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 38),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 1,
            runSpacing: 7,
            children: [
              for (final token in tokens)
                _FlowingLightTokenView(
                  token: token,
                  position: animatedPosition,
                  style: style,
                  color: activeColor,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FlowingLightTokenView extends StatelessWidget {
  static const _popDuration = Duration(milliseconds: 520);

  final FlowingLightToken token;
  final Duration position;
  final TextStyle style;
  final Color color;

  const _FlowingLightTokenView({
    required this.token,
    required this.position,
    required this.style,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final elapsedMicros = (position - token.start).inMicroseconds;
    final reveal = (elapsedMicros / _popDuration.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final visible = elapsedMicros >= 0;
    final horizontalPadding = token.isLatinWord ? 4.0 : 0.5;
    final text = Text(token.text, style: style);
    if (!visible) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Opacity(opacity: 0, child: text),
      );
    }
    final scale = 0.18 + 0.82 * Curves.elasticOut.transform(reveal);
    final lift = 12 * (1 - Curves.easeOutCubic.transform(reveal));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (reveal < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TokenRingPainter(
                        color: color,
                        progress: reveal,
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: (reveal * 4).clamp(0.0, 1.0).toDouble(),
                child: text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _TokenRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final eased = Curves.easeOutCubic.transform(progress);
    final radius = math.max(size.width, size.height) * (0.42 + eased * 1.05);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * (1 - progress) + 0.7
      ..color = color.withValues(alpha: 0.5 * (1 - progress));
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _TokenRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
