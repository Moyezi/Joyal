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
            padding: const EdgeInsets.symmetric(horizontal: 18),
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
      alignment: Alignment.center,
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

@immutable
class FlowingLightTokenPlacement {
  final int row;
  final double rotationDegrees;
  final double horizontalJitter;
  final double verticalJitter;
  final double scale;
  final double gapAfter;
  final double rowShift;

  const FlowingLightTokenPlacement({
    required this.row,
    required this.rotationDegrees,
    required this.horizontalJitter,
    required this.verticalJitter,
    required this.scale,
    required this.gapAfter,
    required this.rowShift,
  });
}

/// Produces a stable, hand-scattered composition for one lyric line.
///
/// Common six-to-twelve token lines use three or four rows. Random-looking
/// values are derived from the lyric itself so rebuilds never make glyphs jump.
List<FlowingLightTokenPlacement> flowingLightPlacementsForTokens(
  List<String> tokenTexts,
) {
  if (tokenTexts.isEmpty) return const [];
  final rowCount = switch (tokenTexts.length) {
    <= 3 => 1,
    <= 5 => 2,
    <= 9 => 3,
    _ => 4,
  };
  final random = math.Random(_stableTokenSeed(tokenTexts));
  final rowSizes = List<int>.filled(rowCount, tokenTexts.length ~/ rowCount);
  final extraRows = List<int>.generate(rowCount, (index) => index)
    ..shuffle(random);
  for (var index = 0; index < tokenTexts.length % rowCount; index++) {
    rowSizes[extraRows[index]]++;
  }

  final placements = <FlowingLightTokenPlacement>[];
  for (var row = 0; row < rowCount; row++) {
    final rowShift = (_normalSample(random) * 0.34).clamp(-0.72, 0.72);
    for (var column = 0; column < rowSizes[row]; column++) {
      placements.add(
        FlowingLightTokenPlacement(
          row: row,
          rotationDegrees: (_normalSample(random) * 8.5).clamp(-25.0, 25.0),
          horizontalJitter: (_normalSample(random) * 0.11).clamp(-0.24, 0.24),
          verticalJitter: (_normalSample(random) * 0.10).clamp(-0.22, 0.22),
          scale: (1 + _normalSample(random) * 0.045).clamp(0.91, 1.09),
          gapAfter: (0.12 + random.nextDouble() * 0.22),
          rowShift: rowShift,
        ),
      );
    }
  }
  return placements;
}

int _stableTokenSeed(List<String> tokenTexts) {
  var hash = 0x811c9dc5;
  for (final codeUnit in tokenTexts.join('\u241f').codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

double _normalSample(math.Random random) {
  final first = math.max(random.nextDouble(), 0.000001);
  final second = random.nextDouble();
  return math.sqrt(-2 * math.log(first)) * math.cos(2 * math.pi * second);
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

Duration flowingLightHighlightEndForToken(
  List<FlowingLightToken> tokens,
  int index, {
  Duration? lineEnd,
}) {
  assert(index >= 0 && index < tokens.length);
  if (index + 1 < tokens.length) return tokens[index + 1].start;
  return lineEnd ?? tokens[index].end;
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
    final displayPieces = hasWordTiming
        ? tokens.map((token) => token.text).toList(growable: false)
        : _flowingLightDisplayPieces(line.text);
    final placements = flowingLightPlacementsForTokens(displayPieces);
    final ambientMotionEnabled =
        positionUpdatesEnabled && !MediaQuery.disableAnimationsOf(context);
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
          return _ScatteredFlowingLightLayout(
            placements: placements,
            fontSize: fontSize,
            ambientMotionEnabled: ambientMotionEnabled,
            children: [
              for (final piece in displayPieces) Text(piece, style: style),
            ],
          );
        }
        return _ScatteredFlowingLightLayout(
          placements: placements,
          fontSize: fontSize,
          ambientMotionEnabled: ambientMotionEnabled,
          children: [
            for (var index = 0; index < tokens.length; index++)
              _FlowingLightTokenView(
                token: tokens[index],
                highlightEnd: flowingLightHighlightEndForToken(
                  tokens,
                  index,
                  lineEnd: line.end,
                ),
                position: animatedPosition,
                style: style,
                color: activeColor,
                keepBreathing: index == tokens.length - 1,
                breathingEnabled: ambientMotionEnabled,
              ),
          ],
        );
      },
    );
  }
}

List<String> _flowingLightDisplayPieces(String text) {
  final pieces = <String>[];
  final glyphs = text.characters.toList(growable: false);
  var index = 0;
  while (index < glyphs.length) {
    if (_isWhitespace(glyphs[index])) {
      index++;
      continue;
    }
    final start = index;
    if (_isLatinWordGlyph(glyphs[index])) {
      while (index < glyphs.length && _isLatinWordGlyph(glyphs[index])) {
        index++;
      }
      pieces.add(glyphs.sublist(start, index).join());
    } else {
      pieces.add(glyphs[index]);
      index++;
    }
  }
  return pieces;
}

class _ScatteredFlowingLightLayout extends StatefulWidget {
  final List<FlowingLightTokenPlacement> placements;
  final List<Widget> children;
  final double fontSize;
  final bool ambientMotionEnabled;

  const _ScatteredFlowingLightLayout({
    required this.placements,
    required this.children,
    required this.fontSize,
    required this.ambientMotionEnabled,
  });

  @override
  State<_ScatteredFlowingLightLayout> createState() =>
      _ScatteredFlowingLightLayoutState();
}

class _ScatteredFlowingLightLayoutState
    extends State<_ScatteredFlowingLightLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _syncAmbientMotion();
  }

  @override
  void didUpdateWidget(covariant _ScatteredFlowingLightLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ambientMotionEnabled != widget.ambientMotionEnabled) {
      _syncAmbientMotion();
    }
  }

  void _syncAmbientMotion() {
    if (widget.ambientMotionEnabled) {
      _floatController.repeat();
    } else {
      _floatController.stop();
      _floatController.value = 0;
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    final rows = <List<int>>[];
    for (var index = 0; index < widget.placements.length; index++) {
      while (rows.length <= widget.placements[index].row) {
        rows.add(<int>[]);
      }
      rows[widget.placements[index].row].add(index);
    }
    final composition = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 22),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows.length; row++) ...[
              if (row > 0)
                SizedBox(
                  height: widget.fontSize * (0.06 + (row.isOdd ? 0.09 : 0.02)),
                ),
              Transform.translate(
                offset: Offset(
                  widget.placements[rows[row].first].rowShift * widget.fontSize,
                  0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final index in rows[row])
                      Padding(
                        padding: EdgeInsets.only(
                          right: index == rows[row].last
                              ? 0
                              : widget.placements[index].gapAfter *
                                    widget.fontSize,
                        ),
                        child: Transform.translate(
                          offset: Offset(
                            widget.placements[index].horizontalJitter *
                                widget.fontSize,
                            widget.placements[index].verticalJitter *
                                widget.fontSize,
                          ),
                          child: Transform.rotate(
                            angle:
                                widget.placements[index].rotationDegrees *
                                math.pi /
                                180,
                            child: Transform.scale(
                              scale: widget.placements[index].scale,
                              child: widget.children[index],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _floatController,
        child: composition,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            flowingLightFloatFactor(_floatController.value) * widget.fontSize,
          ),
          child: child,
        ),
      ),
    );
  }
}

double flowingLightEntranceScale(double progress) {
  final clamped = progress.clamp(0.0, 1.0).toDouble();
  return 1 + 0.16 * (1 - Curves.easeOutCubic.transform(clamped));
}

const flowingLightGlowFadeOutDuration = Duration(milliseconds: 520);

double flowingLightAdaptiveGlowIntensity({
  required Duration elapsed,
  required Duration holdUntilNext,
  Duration fadeOutDuration = flowingLightGlowFadeOutDuration,
}) {
  if (elapsed <= Duration.zero) return 0;
  final holdMicros = math.max(1, holdUntilNext.inMicroseconds);
  final attackMicros = math.min(
    const Duration(milliseconds: 140).inMicroseconds,
    math.max(1, holdMicros ~/ 3),
  );
  if (elapsed.inMicroseconds < attackMicros) {
    return Curves.easeOutCubic.transform(elapsed.inMicroseconds / attackMicros);
  }
  if (elapsed.inMicroseconds <= holdMicros) return 1;
  final fadeMicros = math.max(1, fadeOutDuration.inMicroseconds);
  final fadeProgress = ((elapsed.inMicroseconds - holdMicros) / fadeMicros)
      .clamp(0.0, 1.0)
      .toDouble();
  return 1 - Curves.easeInOutCubic.transform(fadeProgress);
}

double _flowingLightRingIntensity(double revealProgress) {
  final normalized = (revealProgress / 0.82).clamp(0.0, 1.0).toDouble();
  return math.sin(math.pi * normalized);
}

double flowingLightBreathingGlowIntensity(double phase) {
  final normalized = phase - phase.floorToDouble();
  final wave = 0.5 - 0.5 * math.cos(2 * math.pi * normalized);
  return 0.36 + 0.28 * wave;
}

double flowingLightFloatFactor(double phase) {
  final normalized = phase.clamp(0.0, 1.0).toDouble();
  return -0.05 * (1 - math.cos(2 * math.pi * normalized));
}

class _FlowingLightTokenView extends StatelessWidget {
  static const _popDuration = Duration(milliseconds: 520);
  static const _breathingDuration = Duration(milliseconds: 2200);

  final FlowingLightToken token;
  final Duration highlightEnd;
  final Duration position;
  final TextStyle style;
  final Color color;
  final bool keepBreathing;
  final bool breathingEnabled;

  const _FlowingLightTokenView({
    required this.token,
    required this.highlightEnd,
    required this.position,
    required this.style,
    required this.color,
    required this.keepBreathing,
    required this.breathingEnabled,
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
    final scale = flowingLightEntranceScale(reveal);
    final highlightDurationMicros = math.max(
      1,
      (highlightEnd - token.start).inMicroseconds,
    );
    final adaptiveGlowIntensity = flowingLightAdaptiveGlowIntensity(
      elapsed: Duration(microseconds: elapsedMicros),
      holdUntilNext: Duration(microseconds: highlightDurationMicros),
    );
    final entranceRingIntensity = _flowingLightRingIntensity(reveal);
    final breathingRamp = ((reveal - 0.68) / 0.32).clamp(0.0, 1.0).toDouble();
    final breathingPhase = elapsedMicros / _breathingDuration.inMicroseconds;
    final breathingGlowIntensity = keepBreathing
        ? breathingRamp *
              (breathingEnabled
                  ? flowingLightBreathingGlowIntensity(breathingPhase)
                  : 0.36)
        : 0.0;
    final glowIntensity = math.max(
      adaptiveGlowIntensity,
      breathingGlowIntensity,
    );
    final lift = 7 * (1 - Curves.easeOutCubic.transform(reveal));
    final highlightColor = Color.lerp(color, Colors.white, 0.46)!;
    final highlightedText = Text(
      token.text,
      style: style.copyWith(
        shadows: [
          ...?style.shadows,
          if (glowIntensity > 0)
            Shadow(
              color: highlightColor.withValues(alpha: 0.82 * glowIntensity),
              blurRadius: 12 + 16 * glowIntensity,
            ),
          if (glowIntensity > 0)
            Shadow(
              color: color.withValues(alpha: 0.58 * glowIntensity),
              blurRadius: 28 + 18 * glowIntensity,
            ),
        ],
      ),
    );
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
              if (glowIntensity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TokenGlowPainter(
                        color: color,
                        highlightColor: highlightColor,
                        progress: reveal,
                        intensity: glowIntensity,
                        ringIntensity: entranceRingIntensity,
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: (reveal * 4).clamp(0.0, 1.0).toDouble(),
                child: highlightedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenGlowPainter extends CustomPainter {
  final Color color;
  final Color highlightColor;
  final double progress;
  final double intensity;
  final double ringIntensity;

  const _TokenGlowPainter({
    required this.color,
    required this.highlightColor,
    required this.progress,
    required this.intensity,
    required this.ringIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final eased = Curves.easeOutCubic.transform(progress);
    final radius = math.max(size.width, size.height) * (0.42 + eased * 1.05);
    final center = Offset(size.width / 2, size.height / 2);
    final haloPaint = Paint()
      ..color = highlightColor.withValues(alpha: 0.3 * intensity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        8 + math.max(size.width, size.height) * 0.16,
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * (1.12 + intensity * 0.34),
        height: size.height * (1.08 + intensity * 0.28),
      ),
      haloPaint,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * (1 - progress) + 0.7
      ..color = color.withValues(alpha: 0.48 * ringIntensity);
    if (ringIntensity > 0) {
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TokenGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.ringIntensity != ringIntensity ||
        oldDelegate.color != color ||
        oldDelegate.highlightColor != highlightColor;
  }
}
