import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lyrics.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../providers/song_highlight_provider.dart';
import '../lyrics/lyric_print_effect.dart';
import '../lyrics/lyric_semantic_colors.dart';
import 'lyrics_stage_shell.dart';

class FlowingLightLyricsStage extends ConsumerStatefulWidget {
  final LyricsData data;
  final Song song;
  final int activeIndex;
  final String title;
  final String artist;
  final Color activeColor;
  final String? fontFamily;
  final double fontSize;
  final Color? effectColor;
  final Map<String, Color> aiKeywordColors;
  final bool wordByWordEnabled;
  final bool stageVisible;
  final bool positionUpdatesEnabled;
  final VoidCallback onOpenSettings;

  const FlowingLightLyricsStage({
    super.key,
    required this.data,
    required this.song,
    required this.activeIndex,
    required this.title,
    required this.artist,
    required this.activeColor,
    required this.fontFamily,
    required this.fontSize,
    required this.effectColor,
    this.aiKeywordColors = const {},
    required this.wordByWordEnabled,
    required this.stageVisible,
    required this.positionUpdatesEnabled,
    required this.onOpenSettings,
  });

  @override
  ConsumerState<FlowingLightLyricsStage> createState() =>
      _FlowingLightLyricsStageState();
}

class _FlowingLightLyricsStageState
    extends ConsumerState<FlowingLightLyricsStage> {
  late SongHighlightRequest _highlightRequest;

  @override
  void initState() {
    super.initState();
    _highlightRequest = SongHighlightRequest(
      song: widget.song,
      lyrics: widget.data,
    );
  }

  @override
  void didUpdateWidget(covariant FlowingLightLyricsStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.song, widget.song) ||
        !identical(oldWidget.data, widget.data)) {
      _highlightRequest = SongHighlightRequest(
        song: widget.song,
        lyrics: widget.data,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedIndex = widget.activeIndex.clamp(
      0,
      widget.data.lines.length - 1,
    );
    final activeLine = widget.data.lines[resolvedIndex];
    final highlightTimeline = ref
        .watch(songHighlightProvider(_highlightRequest))
        .when(
          data: (timeline) => timeline,
          error: (_, _) => null,
          loading: () => null,
        );
    final resolvedEffectColor = widget.effectColor ?? widget.activeColor;
    final composition = _FlowingLightComposition(
      key: ValueKey(resolvedIndex),
      activeLine: activeLine,
      activeColor: widget.activeColor,
      effectColor: resolvedEffectColor,
      stampColor: resolvedEffectColor,
      aiKeywordColors: widget.aiKeywordColors,
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      wordByWordEnabled: widget.wordByWordEnabled,
      positionUpdatesEnabled: widget.positionUpdatesEnabled,
      isHighlightAt: highlightTimeline?.contains,
    );
    final lineTransitionsEnabled =
        widget.positionUpdatesEnabled &&
        !MediaQuery.disableAnimationsOf(context);
    return LyricsStageShell(
      title: widget.title,
      artist: widget.artist,
      foreground: widget.activeColor,
      onOpenSettings: widget.onOpenSettings,
      headerVisibleDuration: widget.stageVisible
          ? const Duration(seconds: 5)
          : null,
      child: lineTransitionsEnabled
          ? _buildAnimatedLine(composition)
          : composition,
    );
  }

  Widget _buildAnimatedLine(Widget composition) {
    return AnimatedSwitcher(
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
          child: SlideTransition(
            position: slide,
            child: _FlowingLightTransitionTickerMode(
              animation: animation,
              child: child,
            ),
          ),
        );
      },
      child: composition,
    );
  }
}

/// Keeps the outgoing line visually retained while its switch transition
/// continues, without leaving a second lyric animation clock running.
class _FlowingLightTransitionTickerMode extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;

  const _FlowingLightTransitionTickerMode({
    required this.animation,
    required this.child,
  });

  @override
  State<_FlowingLightTransitionTickerMode> createState() =>
      _FlowingLightTransitionTickerModeState();
}

class _FlowingLightTransitionTickerModeState
    extends State<_FlowingLightTransitionTickerMode> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.animation.status != AnimationStatus.reverse;
    widget.animation.addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(covariant _FlowingLightTransitionTickerMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    oldWidget.animation.removeStatusListener(_handleStatus);
    _enabled = widget.animation.status != AnimationStatus.reverse;
    widget.animation.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    final enabled = status != AnimationStatus.reverse;
    if (_enabled == enabled || !mounted) return;
    setState(() => _enabled = enabled);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: _enabled, child: widget.child);
  }
}

class _FlowingLightComposition extends StatelessWidget {
  final LyricLine activeLine;
  final Color activeColor;
  final Color effectColor;
  final Color stampColor;
  final Map<String, Color> aiKeywordColors;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool positionUpdatesEnabled;
  final bool Function(Duration position)? isHighlightAt;

  const _FlowingLightComposition({
    super.key,
    required this.activeLine,
    required this.activeColor,
    required this.effectColor,
    required this.stampColor,
    required this.aiKeywordColors,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.positionUpdatesEnabled,
    required this.isHighlightAt,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: RepaintBoundary(
        child: _FlowingLightActiveLine(
          line: activeLine,
          activeColor: activeColor,
          effectColor: effectColor,
          stampColor: stampColor,
          aiKeywordColors: aiKeywordColors,
          fontFamily: fontFamily,
          fontSize: math.max(fontSize, 36),
          wordByWordEnabled: wordByWordEnabled,
          positionUpdatesEnabled: positionUpdatesEnabled,
          isHighlightAt: isHighlightAt,
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
          rotationDegrees: (_normalSample(random) * 8.5).clamp(
            -flowingLightMaximumRotationDegrees,
            flowingLightMaximumRotationDegrees,
          ),
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

final RegExp _latinWordGlyphPattern = RegExp(r"^[A-Za-z0-9À-ÖØ-öø-ÿ'’_-]$");

bool _isLatinWordGlyph(String glyph) => _latinWordGlyphPattern.hasMatch(glyph);

class _FlowingLightActiveLine extends ConsumerStatefulWidget {
  final LyricLine line;
  final Color activeColor;
  final Color effectColor;
  final Color stampColor;
  final Map<String, Color> aiKeywordColors;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool positionUpdatesEnabled;
  final bool Function(Duration position)? isHighlightAt;

  const _FlowingLightActiveLine({
    required this.line,
    required this.activeColor,
    required this.effectColor,
    required this.stampColor,
    required this.aiKeywordColors,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.positionUpdatesEnabled,
    required this.isHighlightAt,
  });

  @override
  ConsumerState<_FlowingLightActiveLine> createState() =>
      _FlowingLightActiveLineState();
}

class _FlowingLightActiveLineState
    extends ConsumerState<_FlowingLightActiveLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final ValueNotifier<Duration> _fallbackPosition;
  bool _ambientMotionRunning = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: flowingLightRotationCycleDuration,
    );
    _fallbackPosition = ValueNotifier(ref.read(playerProvider).position);
  }

  @override
  void didUpdateWidget(covariant _FlowingLightActiveLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.positionUpdatesEnabled && widget.positionUpdatesEnabled) {
      _fallbackPosition.value = ref.read(playerProvider).position;
    }
  }

  void _syncAmbientMotion(bool enabled) {
    if (_ambientMotionRunning == enabled) return;
    _ambientMotionRunning = enabled;
    if (enabled) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
      _rotationController.value = 0;
    }
  }

  @override
  void dispose() {
    _fallbackPosition.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = flowingLightTokensForLine(widget.line);
    final hasWordTiming = tokens.isNotEmpty;
    final displayPieces = hasWordTiming
        ? tokens.map((token) => token.text).toList(growable: false)
        : _flowingLightDisplayPieces(widget.line.text);
    final placements = flowingLightPlacementsForTokens(displayPieces);
    final semanticColors = lyricSemanticColorsForUnits(
      displayPieces,
      widget.aiKeywordColors,
      sourceText: widget.line.text,
    );
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final ambientMotionEnabled =
        widget.positionUpdatesEnabled && !animationsDisabled;
    final shouldTrack =
        ambientMotionEnabled && widget.wordByWordEnabled && hasWordTiming;
    final audioService = shouldTrack
        ? ref.watch(audioPlayerServiceProvider)
        : null;
    if (shouldTrack && audioService == null) {
      ref.listen(
        playerProvider.select((state) => state.position),
        (_, next) => _fallbackPosition.value = next,
      );
    }
    _syncAmbientMotion(ambientMotionEnabled && displayPieces.isNotEmpty);

    final frozenPosition = ref.read(playerProvider).position;
    double? sampledRotationValue;
    Duration? sampledPosition;
    Duration readPosition() {
      if (!shouldTrack) return frozenPosition;
      final rotationValue = _rotationController.value;
      if (sampledPosition == null || sampledRotationValue != rotationValue) {
        sampledRotationValue = rotationValue;
        sampledPosition = audioService?.position ?? _fallbackPosition.value;
      }
      return sampledPosition!;
    }

    final Listenable? frameListenable = ambientMotionEnabled
        ? _rotationController
        : null;
    final style = Theme.of(context).textTheme.headlineLarge!.copyWith(
      fontSize: widget.fontSize,
      height: 1.12,
      fontFamily: widget.fontFamily,
      fontWeight: FontWeight.w800,
      color: widget.activeColor,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.18),
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
    );

    if (!widget.wordByWordEnabled || !hasWordTiming || animationsDisabled) {
      return _ScatteredFlowingLightLayout(
        placements: placements,
        fontSize: widget.fontSize,
        children: [
          for (var index = 0; index < displayPieces.length; index++)
            _FlowingLightRockingRotation(
              animation: _rotationController,
              baseRotationDegrees: placements[index].rotationDegrees,
              tokenIndex: index,
              revealProgress: 1,
              enabled: ambientMotionEnabled,
              child:
                  animationsDisabled &&
                      widget.wordByWordEnabled &&
                      hasWordTiming &&
                      index == tokens.length - 1
                  ? KeyedSubtree(
                      key: flowingLightStaticHighlightKey,
                      child: _buildStaticHighlightedToken(
                        index: index,
                        tokens: tokens,
                        semanticColors: semanticColors,
                        style: style,
                      ),
                    )
                  : RepaintBoundary(
                      child: Text(
                        displayPieces[index],
                        style: style.copyWith(
                          color: semanticColors[index] ?? widget.activeColor,
                        ),
                      ),
                    ),
            ),
        ],
      );
    }

    return _ScatteredFlowingLightLayout(
      placements: placements,
      fontSize: widget.fontSize,
      children: [
        for (var index = 0; index < tokens.length; index++)
          _buildAnimatedToken(
            index: index,
            tokens: tokens,
            placements: placements,
            semanticColors: semanticColors,
            style: style,
            frameListenable: frameListenable,
            readPosition: readPosition,
            ambientMotionEnabled: ambientMotionEnabled,
          ),
      ],
    );
  }

  Widget _buildStaticHighlightedToken({
    required int index,
    required List<FlowingLightToken> tokens,
    required List<Color?> semanticColors,
    required TextStyle style,
  }) {
    final token = tokens[index];
    final semanticColor = semanticColors[index];
    final highlightEnd = flowingLightHighlightEndForToken(
      tokens,
      index,
      lineEnd: widget.line.end,
    );
    return _FlowingLightTokenView(
      token: token,
      highlightEnd: highlightEnd,
      position: highlightEnd + flowingLightGlowFadeOutDuration,
      reveal: 1,
      style: style,
      defaultColor: widget.activeColor,
      effectColor: widget.effectColor,
      semanticColor: semanticColor,
      nextStart: null,
      ringColor: flowingLightEntranceRingColor(
        fallbackColor: widget.stampColor,
        semanticColor: semanticColor,
      ),
      keepBreathing: true,
      breathingEnabled: false,
      isClimax: widget.isHighlightAt?.call(token.start) ?? false,
    );
  }

  Widget _buildAnimatedToken({
    required int index,
    required List<FlowingLightToken> tokens,
    required List<FlowingLightTokenPlacement> placements,
    required List<Color?> semanticColors,
    required TextStyle style,
    required Listenable? frameListenable,
    required Duration Function() readPosition,
    required bool ambientMotionEnabled,
  }) {
    final token = tokens[index];
    final semanticColor = semanticColors[index];
    final nextStart = index + 1 < tokens.length
        ? tokens[index + 1].start
        : null;
    final highlightEnd = flowingLightHighlightEndForToken(
      tokens,
      index,
      lineEnd: widget.line.end,
    );
    final isClimax = widget.isHighlightAt?.call(token.start) ?? false;
    final horizontalPadding = token.isLatinWord ? 4.0 : 0.5;
    final pendingChild = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Opacity(opacity: 0, child: Text(token.text, style: style)),
    );
    final settledColor = semanticColor ?? widget.activeColor;
    final settledScale =
        flowingLightClimaxKeywordTextScale(
          isClimax: isClimax,
          isKeyword: semanticColor != null,
        ) *
        flowingLightTimelineTokenScale(token);
    final settledChild = RepaintBoundary(
      key: flowingLightSettledTokenLayerKey(index),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Transform.scale(
          scale: settledScale,
          child: Text(token.text, style: style.copyWith(color: settledColor)),
        ),
      ),
    );
    final holdingChild = RepaintBoundary(
      key: flowingLightHoldingTokenLayerKey(index),
      child: _FlowingLightTokenView(
        token: token,
        highlightEnd: highlightEnd,
        position: token.start + flowingLightTokenEntranceDuration,
        reveal: 1,
        style: style,
        defaultColor: widget.activeColor,
        effectColor: widget.effectColor,
        semanticColor: semanticColor,
        nextStart: nextStart,
        ringColor: flowingLightEntranceRingColor(
          fallbackColor: widget.stampColor,
          semanticColor: semanticColor,
        ),
        keepBreathing: index == tokens.length - 1,
        breathingEnabled: ambientMotionEnabled,
        isClimax: isClimax,
      ),
    );
    return _FlowingLightAnimatedToken(
      frameListenable: frameListenable,
      rotationAnimation: _rotationController,
      readPosition: readPosition,
      token: token,
      tokenIndex: index,
      baseRotationDegrees: placements[index].rotationDegrees,
      highlightEnd: highlightEnd,
      style: style,
      defaultColor: widget.activeColor,
      effectColor: widget.effectColor,
      semanticColor: semanticColor,
      nextStart: nextStart,
      ringColor: flowingLightEntranceRingColor(
        fallbackColor: widget.stampColor,
        semanticColor: semanticColor,
      ),
      keepBreathing: index == tokens.length - 1,
      breathingEnabled: ambientMotionEnabled,
      rockingEnabled: ambientMotionEnabled,
      isClimax: isClimax,
      pendingChild: pendingChild,
      holdingChild: holdingChild,
      settledChild: settledChild,
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

class _ScatteredFlowingLightLayout extends StatelessWidget {
  final List<FlowingLightTokenPlacement> placements;
  final List<Widget> children;
  final double fontSize;

  const _ScatteredFlowingLightLayout({
    required this.placements,
    required this.children,
    required this.fontSize,
  }) : assert(placements.length == children.length);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final rows = <List<int>>[];
    for (var index = 0; index < placements.length; index++) {
      while (rows.length <= placements[index].row) {
        rows.add(<int>[]);
      }
      rows[placements[index].row].add(index);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 22),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows.length; row++) ...[
              if (row > 0)
                SizedBox(height: fontSize * (0.06 + (row.isOdd ? 0.09 : 0.02))),
              Transform.translate(
                offset: Offset(
                  placements[rows[row].first].rowShift * fontSize,
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
                              : placements[index].gapAfter * fontSize,
                        ),
                        child: Transform.translate(
                          offset: Offset(
                            placements[index].horizontalJitter * fontSize,
                            placements[index].verticalJitter * fontSize,
                          ),
                          child: Transform.scale(
                            scale: placements[index].scale,
                            child: children[index],
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
  }
}

class _FlowingLightRockingRotation extends StatelessWidget {
  final Animation<double> animation;
  final double baseRotationDegrees;
  final int tokenIndex;
  final double revealProgress;
  final bool enabled;
  final Widget child;

  const _FlowingLightRockingRotation({
    required this.animation,
    required this.baseRotationDegrees,
    required this.tokenIndex,
    required this.revealProgress,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Transform.rotate(
        angle: baseRotationDegrees * math.pi / 180,
        child: child,
      );
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final swayDegrees = enabled
            ? flowingLightTokenSwayDegrees(
                phase: animation.value,
                tokenIndex: tokenIndex,
                revealProgress: revealProgress,
              )
            : 0.0;
        final rotationDegrees = (baseRotationDegrees + swayDegrees)
            .clamp(
              -flowingLightMaximumRotationDegrees,
              flowingLightMaximumRotationDegrees,
            )
            .toDouble();
        return Transform.rotate(
          angle: rotationDegrees * math.pi / 180,
          child: child,
        );
      },
    );
  }
}

enum FlowingLightTokenVisualPhase { pending, animating, holding, settled }

@visibleForTesting
const Key flowingLightStaticHighlightKey = ValueKey<String>(
  'flowing-light-static-highlight',
);

@visibleForTesting
Key flowingLightSettledTokenLayerKey(int index) =>
    ValueKey<String>('flowing-light-settled-token-$index');

@visibleForTesting
Key flowingLightHoldingTokenLayerKey(int index) =>
    ValueKey<String>('flowing-light-holding-token-$index');

/// Separates reusable token layers from the short reveal/glow window.
@visibleForTesting
FlowingLightTokenVisualPhase flowingLightTokenVisualPhase({
  required FlowingLightToken token,
  required Duration highlightEnd,
  required Duration position,
  required Duration? nextStart,
  required bool hasSemanticColor,
  required bool keepBreathing,
}) {
  if (position < token.start) return FlowingLightTokenVisualPhase.pending;
  final entranceEnd = token.start + flowingLightTokenEntranceDuration;
  if (position >= entranceEnd && position <= highlightEnd) {
    return FlowingLightTokenVisualPhase.holding;
  }
  if (keepBreathing) return FlowingLightTokenVisualPhase.animating;

  var settledAt = entranceEnd;
  final glowSettledAt = highlightEnd + flowingLightGlowFadeOutDuration;
  if (glowSettledAt > settledAt) settledAt = glowSettledAt;
  if (!hasSemanticColor && nextStart != null) {
    final colorSettledAt = nextStart + flowingLightEffectColorFadeDuration;
    if (colorSettledAt > settledAt) settledAt = colorSettledAt;
  }
  return position >= settledAt
      ? FlowingLightTokenVisualPhase.settled
      : FlowingLightTokenVisualPhase.animating;
}

class _FlowingLightAnimatedToken extends StatelessWidget {
  final Listenable? frameListenable;
  final Animation<double> rotationAnimation;
  final Duration Function() readPosition;
  final FlowingLightToken token;
  final int tokenIndex;
  final double baseRotationDegrees;
  final Duration highlightEnd;
  final TextStyle style;
  final Color defaultColor;
  final Color effectColor;
  final Color? semanticColor;
  final Duration? nextStart;
  final Color ringColor;
  final bool keepBreathing;
  final bool breathingEnabled;
  final bool rockingEnabled;
  final bool isClimax;
  final Widget pendingChild;
  final Widget holdingChild;
  final Widget settledChild;

  const _FlowingLightAnimatedToken({
    required this.frameListenable,
    required this.rotationAnimation,
    required this.readPosition,
    required this.token,
    required this.tokenIndex,
    required this.baseRotationDegrees,
    required this.highlightEnd,
    required this.style,
    required this.defaultColor,
    required this.effectColor,
    required this.semanticColor,
    required this.nextStart,
    required this.ringColor,
    required this.keepBreathing,
    required this.breathingEnabled,
    required this.rockingEnabled,
    required this.isClimax,
    required this.pendingChild,
    required this.holdingChild,
    required this.settledChild,
  });

  Widget _buildFrame() {
    final position = readPosition();
    final reveal = flowingLightTokenRevealProgress(token, position);
    final visualPhase = flowingLightTokenVisualPhase(
      token: token,
      highlightEnd: highlightEnd,
      position: position,
      nextStart: nextStart,
      hasSemanticColor: semanticColor != null,
      keepBreathing: keepBreathing,
    );
    final visual = switch (visualPhase) {
      FlowingLightTokenVisualPhase.pending => pendingChild,
      FlowingLightTokenVisualPhase.holding => holdingChild,
      FlowingLightTokenVisualPhase.settled => settledChild,
      FlowingLightTokenVisualPhase.animating => _FlowingLightTokenView(
        token: token,
        highlightEnd: highlightEnd,
        position: position,
        reveal: reveal,
        style: style,
        defaultColor: defaultColor,
        effectColor: effectColor,
        semanticColor: semanticColor,
        nextStart: nextStart,
        ringColor: ringColor,
        keepBreathing: keepBreathing,
        breathingEnabled: breathingEnabled,
        isClimax: isClimax,
      ),
    };
    final swayDegrees = rockingEnabled
        ? flowingLightTokenSwayDegrees(
            phase: rotationAnimation.value,
            tokenIndex: tokenIndex,
            revealProgress: reveal,
          )
        : 0.0;
    final rotationDegrees = (baseRotationDegrees + swayDegrees)
        .clamp(
          -flowingLightMaximumRotationDegrees,
          flowingLightMaximumRotationDegrees,
        )
        .toDouble();
    return Transform.rotate(
      angle: rotationDegrees * math.pi / 180,
      child: visual,
    );
  }

  @override
  Widget build(BuildContext context) {
    final frame = frameListenable;
    if (frame == null) return _buildFrame();
    return AnimatedBuilder(animation: frame, builder: (_, _) => _buildFrame());
  }
}

double flowingLightTokenSwayDegrees({
  required double phase,
  required int tokenIndex,
  required double revealProgress,
}) {
  final normalizedPhase = phase - phase.floorToDouble();
  final normalizedReveal = revealProgress.clamp(0.0, 1.0).toDouble();
  if (normalizedReveal <= 0) return 0;
  final direction = tokenIndex.isEven ? 1.0 : -1.0;
  final amplitude = 1.8 + (tokenIndex % 3) * 0.3;
  final revealRamp = Curves.easeOutCubic.transform(normalizedReveal);
  return math.sin(2 * math.pi * normalizedPhase) *
      amplitude *
      direction *
      revealRamp;
}

const flowingLightRotationCycleDuration = Duration(milliseconds: 7200);
const flowingLightMaximumRotationDegrees = 20.0;

double flowingLightEntranceScale(double progress) {
  final clamped = progress.clamp(0.0, 1.0).toDouble();
  return 1 + 0.16 * (1 - Curves.easeOutCubic.transform(clamped));
}

const flowingLightGlowFadeOutDuration = Duration(milliseconds: 520);
const flowingLightEffectColorFadeDuration = Duration(milliseconds: 280);

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

class _FlowingLightTokenView extends StatelessWidget {
  static const _breathingDuration = Duration(milliseconds: 2200);

  final FlowingLightToken token;
  final Duration highlightEnd;
  final Duration position;
  final double reveal;
  final TextStyle style;
  final Color defaultColor;
  final Color effectColor;
  final Color? semanticColor;
  final Duration? nextStart;
  final Color ringColor;
  final bool keepBreathing;
  final bool breathingEnabled;
  final bool isClimax;

  const _FlowingLightTokenView({
    required this.token,
    required this.highlightEnd,
    required this.position,
    required this.reveal,
    required this.style,
    required this.defaultColor,
    required this.effectColor,
    required this.semanticColor,
    required this.nextStart,
    required this.ringColor,
    required this.keepBreathing,
    required this.breathingEnabled,
    required this.isClimax,
  });

  @override
  Widget build(BuildContext context) {
    final elapsedMicros = (position - token.start).inMicroseconds;
    final horizontalPadding = token.isLatinWord ? 4.0 : 0.5;
    final scale = flowingLightEntranceScale(reveal);
    final highlightDurationMicros = math.max(
      1,
      (highlightEnd - token.start).inMicroseconds,
    );
    final adaptiveGlowIntensity = flowingLightAdaptiveGlowIntensity(
      elapsed: Duration(microseconds: elapsedMicros),
      holdUntilNext: Duration(microseconds: highlightDurationMicros),
    );
    final showEntranceRing = flowingLightShouldShowEntranceRing(
      isClimax: isClimax,
      isKeyword: semanticColor != null,
    );
    final entranceRingIntensity = showEntranceRing
        ? _flowingLightRingIntensity(reveal)
        : 0.0;
    final climaxKeywordTextScale = flowingLightClimaxKeywordTextScale(
      isClimax: isClimax,
      isKeyword: semanticColor != null,
    );
    final climaxKeywordHaloScale = flowingLightClimaxKeywordHaloScale(
      isClimax: isClimax,
      isKeyword: semanticColor != null,
    );
    final timelineTokenScale = flowingLightTimelineTokenScale(token);
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
    final resolvedEffectColor = semanticColor ?? effectColor;
    final effectIntensity = flowingLightTokenEffectColorIntensity(
      token,
      position,
      nextStart: nextStart,
      persist: semanticColor != null,
    );
    final color = Color.lerp(
      defaultColor,
      resolvedEffectColor,
      effectIntensity,
    )!;
    final highlightColor = color;
    final highlightedText = Text(
      token.text,
      style: style.copyWith(
        color: color,
        shadows: [
          ...?style.shadows,
          if (glowIntensity > 0)
            Shadow(
              color: highlightColor.withValues(alpha: 0.82 * glowIntensity),
              blurRadius: (12 + 16 * glowIntensity) * climaxKeywordHaloScale,
            ),
          if (glowIntensity > 0)
            Shadow(
              color: color.withValues(alpha: 0.58 * glowIntensity),
              blurRadius: (28 + 18 * glowIntensity) * climaxKeywordHaloScale,
            ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.scale(
          scale: scale * climaxKeywordTextScale * timelineTokenScale,
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
                        ringColor: ringColor,
                        progress: reveal,
                        intensity: glowIntensity,
                        ringIntensity: entranceRingIntensity,
                        haloScale: climaxKeywordHaloScale,
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

const flowingLightTokenEntranceDuration = Duration(milliseconds: 520);

double flowingLightTokenRevealProgress(
  FlowingLightToken token,
  Duration position,
) {
  return ((position - token.start).inMicroseconds /
          flowingLightTokenEntranceDuration.inMicroseconds)
      .clamp(0.0, 1.0)
      .toDouble();
}

double flowingLightTokenEffectColorIntensity(
  FlowingLightToken token,
  Duration position, {
  Duration? nextStart,
  bool persist = false,
}) {
  return lyricEffectColorIntensity(
    position: position,
    start: token.start,
    nextStart: nextStart,
    persist: persist,
    transition: flowingLightEffectColorFadeDuration,
  );
}

/// Scales non-Latin token text and halos by their word-timing duration.
///
/// Latin words already get wider halos from their measured text width, so they
/// deliberately keep a neutral scale here. The square-root curve makes longer
/// held glyphs visibly broader without letting unusually long timestamps
/// dominate the scattered composition.
@visibleForTesting
double flowingLightTimelineTokenScale(FlowingLightToken token) {
  if (token.isLatinWord) return 1.0;
  final durationMicros = math.max(0, (token.end - token.start).inMicroseconds);
  final durationRatio =
      durationMicros / flowingLightTokenEntranceDuration.inMicroseconds;
  return math.sqrt(durationRatio).clamp(0.82, 1.42).toDouble();
}

@visibleForTesting
double flowingLightClimaxKeywordTextScale({
  required bool isClimax,
  required bool isKeyword,
}) {
  return isClimax && isKeyword ? 1.18 : 1.0;
}

@visibleForTesting
double flowingLightClimaxKeywordHaloScale({
  required bool isClimax,
  required bool isKeyword,
}) {
  return isClimax && isKeyword ? 1.42 : 1.0;
}

@visibleForTesting
bool flowingLightShouldShowEntranceRing({
  required bool isClimax,
  required bool isKeyword,
}) {
  return isClimax || isKeyword;
}

@visibleForTesting
Color flowingLightEntranceRingColor({
  required Color fallbackColor,
  Color? semanticColor,
}) {
  return semanticColor ?? fallbackColor;
}

class _TokenGlowPainter extends CustomPainter {
  final Color color;
  final Color highlightColor;
  final Color ringColor;
  final double progress;
  final double intensity;
  final double ringIntensity;
  final double haloScale;

  const _TokenGlowPainter({
    required this.color,
    required this.highlightColor,
    required this.ringColor,
    required this.progress,
    required this.intensity,
    required this.ringIntensity,
    required this.haloScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final eased = Curves.easeOutCubic.transform(progress);
    final radius =
        math.max(size.width, size.height) * (0.42 + eased * 1.05) * haloScale;
    final center = Offset(size.width / 2, size.height / 2);
    final haloPaint = Paint()
      ..color = highlightColor.withValues(alpha: 0.3 * intensity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        (8 + math.max(size.width, size.height) * 0.16) * haloScale,
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * (1.12 + intensity * 0.34) * haloScale,
        height: size.height * (1.08 + intensity * 0.28) * haloScale,
      ),
      haloPaint,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * (1 - progress) + 0.7
      ..color = ringColor.withValues(alpha: 0.48 * ringIntensity);
    if (ringIntensity > 0) {
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TokenGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.ringIntensity != ringIntensity ||
        oldDelegate.haloScale != haloScale ||
        oldDelegate.color != color ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.ringColor != ringColor;
  }
}
