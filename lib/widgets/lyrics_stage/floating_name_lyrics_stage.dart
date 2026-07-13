import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lyrics.dart';
import '../../models/song.dart';
import '../../models/song_highlight.dart';
import '../../providers/player_provider.dart';
import '../../providers/song_highlight_provider.dart';
import '../../services/audio_player_service.dart';
import 'lyrics_stage_shell.dart';

/// Folia-inspired "浮名" stage, implemented independently for Joyal.
///
/// The whole song is typeset into a deterministic article in world space. The
/// camera travels between lyric blocks while the active line is printed along
/// its word timeline. Passed lines remain as quiet ink traces instead of being
/// removed immediately.
class FloatingNameLyricsStage extends ConsumerWidget {
  final LyricsData data;
  final Song song;
  final int activeIndex;
  final String title;
  final String artist;
  final Color activeColor;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool stageVisible;
  final bool positionUpdatesEnabled;
  final VoidCallback onOpenSettings;

  const FloatingNameLyricsStage({
    super.key,
    required this.data,
    required this.song,
    required this.activeIndex,
    required this.title,
    required this.artist,
    required this.activeColor,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.stageVisible,
    required this.positionUpdatesEnabled,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightTimeline = ref
        .watch(
          songHighlightProvider(SongHighlightRequest(song: song, lyrics: data)),
        )
        .when(
          data: (timeline) => timeline,
          error: (_, _) => null,
          loading: () => null,
        );
    return LyricsStageShell(
      title: title,
      artist: artist,
      foreground: activeColor,
      onOpenSettings: onOpenSettings,
      headerVisibleDuration: stageVisible ? const Duration(seconds: 5) : null,
      contentPadding: EdgeInsets.zero,
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _FloatingNameArticle(
              data: data,
              activeIndex: activeIndex.clamp(0, data.lines.length - 1),
              activeColor: activeColor,
              fontFamily: fontFamily,
              fontSize: fontSize,
              wordByWordEnabled: wordByWordEnabled,
              positionUpdatesEnabled: positionUpdatesEnabled,
              highlightSignature: highlightTimeline?.segments
                  .map(
                    (segment) =>
                        '${segment.start.inMilliseconds}-${segment.end.inMilliseconds}',
                  )
                  .join(','),
              highlightSegments: highlightTimeline?.segments ?? const [],
              viewport: constraints.biggest,
            );
          },
        ),
      ),
    );
  }
}

class _FloatingNameArticle extends ConsumerStatefulWidget {
  final LyricsData data;
  final int activeIndex;
  final Color activeColor;
  final String? fontFamily;
  final double fontSize;
  final bool wordByWordEnabled;
  final bool positionUpdatesEnabled;
  final String? highlightSignature;
  final List<SongHighlightSegment> highlightSegments;
  final Size viewport;

  const _FloatingNameArticle({
    required this.data,
    required this.activeIndex,
    required this.activeColor,
    required this.fontFamily,
    required this.fontSize,
    required this.wordByWordEnabled,
    required this.positionUpdatesEnabled,
    required this.highlightSignature,
    required this.highlightSegments,
    required this.viewport,
  });

  @override
  ConsumerState<_FloatingNameArticle> createState() =>
      _FloatingNameArticleState();
}

class _FloatingNameArticleState extends ConsumerState<_FloatingNameArticle>
    with TickerProviderStateMixin {
  late final AnimationController _cameraController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );
  late final AnimationController _frameController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  _FloatingArticleLayout? _layout;
  Object? _layoutKey;
  int _cameraFromIndex = 0;
  late final ValueNotifier<Duration> _fallbackPosition;

  @override
  void initState() {
    super.initState();
    _fallbackPosition = ValueNotifier(ref.read(playerProvider).position);
  }

  @override
  void didUpdateWidget(covariant _FloatingNameArticle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      _cameraFromIndex = oldWidget.activeIndex.clamp(
        0,
        math.max(widget.data.lines.length - 1, 0),
      );
      if (_motionEnabled) {
        _cameraController.forward(from: 0);
      } else {
        _cameraController.value = 1;
      }
    }
    if (!_motionEnabled) {
      _cameraController.stop();
      _cameraController.value = 1;
    }
  }

  bool get _motionEnabled =>
      widget.positionUpdatesEnabled && !MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _fallbackPosition.dispose();
    _frameController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    final isPlaying = ref.watch(
      playerProvider.select((state) => state.isPlaying),
    );
    ref.listen(
      playerProvider.select((state) => state.position),
      (_, next) => _fallbackPosition.value = next,
    );
    final frameTicking = _motionEnabled && isPlaying;
    if (frameTicking && !_frameController.isAnimating) {
      _frameController.repeat();
    } else if (!frameTicking && _frameController.isAnimating) {
      _frameController.stop();
    }
    final key = Object.hash(
      identityHashCode(widget.data),
      widget.viewport.width.round(),
      widget.viewport.height.round(),
      widget.fontFamily,
      widget.fontSize,
      widget.highlightSignature,
    );
    if (_layout == null || _layoutKey != key) {
      _layoutKey = key;
      _layout = _FloatingArticleLayout.build(
        widget.data,
        widget.viewport,
        fontFamily: widget.fontFamily,
        fontSize: widget.fontSize,
        highlightSegments: widget.highlightSegments,
      );
    }

    final layout = _layout!;
    return CustomPaint(
      size: widget.viewport,
      painter: _FloatingNamePainter(
        layout: layout,
        activeIndex: widget.activeIndex,
        cameraFromIndex: _cameraFromIndex,
        audioService: audioService,
        fallbackPosition: _fallbackPosition,
        isPlaying: isPlaying,
        activeColor: widget.activeColor,
        wordByWordEnabled: widget.wordByWordEnabled,
        motionEnabled: _motionEnabled,
        cameraAnimation: _cameraController,
        frameAnimation: _frameController,
      ),
    );
  }
}

enum FloatingNameBlockVariant { body, hero }

FloatingNameBlockVariant floatingNameBlockVariantFor(
  int index,
  String text,
  int total,
) {
  final glyphCount = text.characters
      .where((glyph) => glyph.trim().isNotEmpty)
      .length;
  if (glyphCount == 0) return FloatingNameBlockVariant.body;
  final shortEnough = glyphCount >= 4 && glyphCount <= 22;
  final middleDistance = (index - total / 2).abs() / math.max(total, 1);
  final hash = _stableHash('$text:$index:hero');
  return shortEnough &&
          middleDistance < 0.74 &&
          ((index + 1) % 6 == 0 || hash % 31 == 0)
      ? FloatingNameBlockVariant.hero
      : FloatingNameBlockVariant.body;
}

/// Continuous printed prefix, where the fractional part is the active glyph's
/// progress. Word timing wins; line timing is the graceful fallback.
double floatingNamePrintedGraphemeProgress(
  LyricLine line,
  Duration position, {
  bool wordByWordEnabled = true,
}) {
  final glyphs = line.text.characters.toList(growable: false);
  if (glyphs.isEmpty) return 0;
  if (!wordByWordEnabled) {
    final start = line.start ?? Duration.zero;
    return position >= start ? glyphs.length.toDouble() : 0;
  }
  final timings = _timingsForLine(line, glyphs);
  final micros = position.inMicroseconds;
  var completed = 0.0;
  for (var index = 0; index < timings.length; index++) {
    final timing = timings[index];
    final start = timing.start.inMicroseconds;
    final end = math.max(timing.end.inMicroseconds, start + 1);
    if (micros < start) return completed;
    if (micros < end) {
      return index + ((micros - start) / (end - start)).clamp(0.0, 1.0);
    }
    completed = index + 1.0;
  }
  return completed.clamp(0.0, glyphs.length.toDouble());
}

/// Number of complete graphemes already struck by the virtual typewriter.
///
/// The continuous progress remains available to the camera, but the ink itself
/// appears one complete Chinese grapheme or Latin letter at a time.
int floatingNameTypedGraphemeCount(double progress, int glyphCount) {
  if (progress <= 0 || glyphCount <= 0) return 0;
  return progress.ceil().clamp(0, glyphCount);
}

/// A three-column snake keeps the article moving sideways as well as down.
/// Adjacent lyric lines travel across a row before the camera turns into the
/// next row, so the composition is not limited to one vertical strip.
Offset floatingNameArticleCellForIndex(
  int index, {
  required double columnSpacing,
  required double rowOffset,
}) {
  const columnCount = 3;
  final row = index ~/ columnCount;
  final positionInRow = index % columnCount;
  final column = row.isEven ? positionInRow : columnCount - 1 - positionInRow;
  return Offset((column - 1) * columnSpacing, rowOffset);
}

class _GlyphTiming {
  final Duration start;
  final Duration end;

  const _GlyphTiming(this.start, this.end);
}

List<_GlyphTiming> _timingsForLine(LyricLine line, List<String> glyphs) {
  final lineStart =
      line.start ?? line.words.firstOrNull?.start ?? Duration.zero;
  final wordEnd = line.words.lastOrNull?.end;
  final lineEnd = line.end ?? wordEnd ?? lineStart + const Duration(seconds: 3);
  final durationMicros = math.max(1, (lineEnd - lineStart).inMicroseconds);
  final timings = List<_GlyphTiming>.generate(glyphs.length, (index) {
    final start =
        lineStart +
        Duration(
          microseconds: (durationMicros * index / glyphs.length).round(),
        );
    final end =
        lineStart +
        Duration(
          microseconds: (durationMicros * (index + 1) / glyphs.length).round(),
        );
    return _GlyphTiming(start, end);
  });
  if (line.words.isEmpty) return timings;

  final glyphOffsets = <int>[0];
  var utf16Offset = 0;
  for (final glyph in glyphs) {
    utf16Offset += glyph.length;
    glyphOffsets.add(utf16Offset);
  }
  var searchOffset = 0;
  for (final word in line.words) {
    final startTime = word.start;
    final endTime = word.end;
    if (startTime == null || endTime == null || word.text.isEmpty) continue;
    var wordOffset = line.text.indexOf(word.text, searchOffset);
    if (wordOffset < 0) wordOffset = searchOffset.clamp(0, line.text.length);
    var wordEndOffset = (wordOffset + word.text.length).clamp(
      0,
      line.text.length,
    );
    while (wordEndOffset < line.text.length &&
        line.text.substring(wordEndOffset, wordEndOffset + 1).trim().isEmpty) {
      wordEndOffset++;
    }
    final firstGlyph = _glyphIndexAtUtf16Offset(glyphOffsets, wordOffset);
    var lastGlyph = _glyphIndexAtUtf16Offset(glyphOffsets, wordEndOffset);
    if (lastGlyph <= firstGlyph) {
      lastGlyph = math.min(firstGlyph + 1, glyphs.length);
    }
    final count = math.max(lastGlyph - firstGlyph, 1);
    final wordMicros = math.max(1, (endTime - startTime).inMicroseconds);
    for (
      var local = 0;
      local < count && firstGlyph + local < timings.length;
      local++
    ) {
      timings[firstGlyph + local] = _GlyphTiming(
        startTime +
            Duration(microseconds: (wordMicros * local / count).round()),
        startTime +
            Duration(microseconds: (wordMicros * (local + 1) / count).round()),
      );
    }
    searchOffset = wordEndOffset;
  }
  return timings;
}

int _glyphIndexAtUtf16Offset(List<int> offsets, int target) {
  for (var index = 1; index < offsets.length; index++) {
    if (offsets[index] == target) return index;
    if (offsets[index] > target) return index - 1;
  }
  return math.max(offsets.length - 1, 0);
}

class _FloatingArticleLayout {
  final List<_FloatingBlock> blocks;

  const _FloatingArticleLayout({required this.blocks});

  factory _FloatingArticleLayout.build(
    LyricsData data,
    Size viewport, {
    required String? fontFamily,
    required double fontSize,
    required List<SongHighlightSegment> highlightSegments,
  }) {
    final blocks = <_FloatingBlock>[];
    var rowTop = 0.0;
    var rowBottom = 0.0;
    final columnSpacing = math.max(viewport.width * 0.94, 290.0);
    for (var index = 0; index < data.lines.length; index++) {
      final line = data.lines[index];
      final variant = floatingNameBlockVariantFor(
        index,
        line.text,
        data.lines.length,
      );
      final hero = variant == FloatingNameBlockVariant.hero;
      final highlight = floatingNameLineIsHighlighted(line, highlightSegments);
      final maxWidth = viewport.width * (hero ? 0.86 : 0.68);
      final resolvedFontSize =
          fontSize * (hero ? 1.28 : 0.76) * (highlight ? 1.16 : 1);
      final style = TextStyle(
        color: Colors.white,
        fontFamily: fontFamily,
        fontSize: resolvedFontSize,
        height: hero ? 1.03 : 1.12,
        fontWeight: hero ? FontWeight.w800 : FontWeight.w700,
        letterSpacing: hero ? -1.1 : -0.25,
      );
      final painter = TextPainter(
        text: TextSpan(text: line.text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: hero ? 2 : 3,
      )..layout(maxWidth: maxWidth);
      final positionInRow = index % 3;
      final cell = floatingNameArticleCellForIndex(
        index,
        columnSpacing: columnSpacing,
        rowOffset: rowTop,
      );
      final verticalJitter = positionInRow == 1
          ? math.min(fontSize * 0.42, 24.0)
          : positionInRow == 2
          ? math.min(fontSize * 0.18, 12.0)
          : 0.0;
      final x = cell.dx - painter.width / 2;
      final y = cell.dy + verticalJitter;
      final glyphs = line.text.characters.toList(growable: false);
      final utf16Offsets = <int>[0];
      var offset = 0;
      for (final glyph in glyphs) {
        offset += glyph.length;
        utf16Offsets.add(offset);
      }
      final glyphBoxes = <Rect>[];
      for (var glyphIndex = 0; glyphIndex < glyphs.length; glyphIndex++) {
        final boxes = painter.getBoxesForSelection(
          TextSelection(
            baseOffset: utf16Offsets[glyphIndex],
            extentOffset: utf16Offsets[glyphIndex + 1],
          ),
        );
        glyphBoxes.add(boxes.isEmpty ? Rect.zero : boxes.first.toRect());
      }
      blocks.add(
        _FloatingBlock(
          index: index,
          line: line,
          variant: variant,
          origin: Offset(x, y),
          textPainter: painter,
          style: style,
          glyphs: glyphs,
          utf16Offsets: utf16Offsets,
          glyphBoxes: glyphBoxes,
          maxWidth: maxWidth,
        ),
      );
      final jitter = (_stableHash('${line.text}:$index:gap') % 29).toDouble();
      rowBottom = math.max(rowBottom, y + painter.height);
      final rowFinished = positionInRow == 2 || index == data.lines.length - 1;
      if (rowFinished) {
        rowTop = rowBottom + (hero ? 112 : 78) + jitter;
        rowBottom = rowTop;
      }
    }
    return _FloatingArticleLayout(blocks: blocks);
  }
}

class _FloatingBlock {
  final int index;
  final LyricLine line;
  final FloatingNameBlockVariant variant;
  final Offset origin;
  final TextPainter textPainter;
  final TextStyle style;
  final List<String> glyphs;
  final List<int> utf16Offsets;
  final List<Rect> glyphBoxes;
  final double maxWidth;
  final Map<int, TextPainter> _coloredPainters = {};
  TextPainter? _typedPainter;
  int? _typedPainterKey;

  _FloatingBlock({
    required this.index,
    required this.line,
    required this.variant,
    required this.origin,
    required this.textPainter,
    required this.style,
    required this.glyphs,
    required this.utf16Offsets,
    required this.glyphBoxes,
    required this.maxWidth,
  });

  Rect get bounds => origin & textPainter.size;
  Offset get center => bounds.center;

  TextPainter painterFor(Color color) {
    return _coloredPainters.putIfAbsent(color.toARGB32(), () {
      return TextPainter(
        text: TextSpan(
          text: line.text,
          style: style.copyWith(color: color),
        ),
        textDirection: TextDirection.ltr,
        maxLines: textPainter.maxLines,
      )..layout(maxWidth: maxWidth);
    });
  }

  TextPainter painterForTypedPrefix({
    required int typedCount,
    required Color revealedColor,
    required Color pendingColor,
  }) {
    final resolvedCount = typedCount.clamp(0, glyphs.length);
    final key = Object.hash(
      resolvedCount,
      revealedColor.toARGB32(),
      pendingColor.toARGB32(),
    );
    if (_typedPainterKey == key && _typedPainter != null) {
      return _typedPainter!;
    }
    _typedPainterKey = key;
    return _typedPainter = TextPainter(
      text: floatingNameRevealSpan(
        glyphs: glyphs,
        style: style,
        typedCount: resolvedCount,
        revealedColor: revealedColor,
        pendingColor: pendingColor,
      ),
      textDirection: TextDirection.ltr,
      maxLines: textPainter.maxLines,
    )..layout(maxWidth: maxWidth);
  }
}

@visibleForTesting
TextSpan floatingNameRevealSpan({
  required List<String> glyphs,
  required TextStyle style,
  required int typedCount,
  required Color revealedColor,
  required Color pendingColor,
}) {
  final resolvedCount = typedCount.clamp(0, glyphs.length);
  return TextSpan(
    style: style,
    children: [
      for (var index = 0; index < glyphs.length; index++)
        TextSpan(
          text: glyphs[index],
          style: TextStyle(
            color: index < resolvedCount ? revealedColor : pendingColor,
          ),
        ),
    ],
  );
}

class _FloatingNamePainter extends CustomPainter {
  final _FloatingArticleLayout layout;
  final int activeIndex;
  final int cameraFromIndex;
  final AudioPlayerService? audioService;
  final ValueListenable<Duration> fallbackPosition;
  final bool isPlaying;
  final Color activeColor;
  final bool wordByWordEnabled;
  final bool motionEnabled;
  final Animation<double> cameraAnimation;
  final Animation<double> frameAnimation;

  _FloatingNamePainter({
    required this.layout,
    required this.activeIndex,
    required this.cameraFromIndex,
    required this.audioService,
    required this.fallbackPosition,
    required this.isPlaying,
    required this.activeColor,
    required this.wordByWordEnabled,
    required this.motionEnabled,
    required this.cameraAnimation,
    required this.frameAnimation,
  }) : super(
         repaint: motionEnabled && isPlaying
             ? Listenable.merge([cameraAnimation, frameAnimation])
             : motionEnabled
             ? Listenable.merge([cameraAnimation, fallbackPosition])
             : cameraAnimation,
       );

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.blocks.isEmpty || size.isEmpty) return;
    final current =
        layout.blocks[activeIndex.clamp(0, layout.blocks.length - 1)];
    final from =
        layout.blocks[cameraFromIndex.clamp(0, layout.blocks.length - 1)];
    final printProgress = floatingNamePrintedGraphemeProgress(
      current.line,
      audioService?.position ?? fallbackPosition.value,
      wordByWordEnabled: wordByWordEnabled,
    );
    final currentFocus = _focusForBlock(current, printProgress);
    final fromFocus = _focusForBlock(from, from.glyphs.length.toDouble());
    final transition = Curves.easeInOutCubic.transform(cameraAnimation.value);
    final camera = Offset.lerp(fromFocus, currentFocus, transition)!;
    final fromScale = _cameraScale(from, size);
    final toScale = _cameraScale(current, size);
    final scale = ui.lerpDouble(fromScale, toScale, transition)!;

    // The paper tint is screen-space and edge-to-edge. It never has a world-
    // space rectangle for the travelling camera to expose at the song edges.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = activeColor.withValues(alpha: 0.026),
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-camera.dx, -camera.dy);

    final visibleWorld = Rect.fromCenter(
      center: camera,
      width: size.width / scale * 1.55,
      height: size.height / scale * 1.45,
    );
    _paintArticleMarker(canvas, current);
    for (final block in layout.blocks) {
      if (!block.bounds.inflate(110).overlaps(visibleWorld)) continue;
      if (block.index == activeIndex) {
        _paintActiveBlock(canvas, block, printProgress);
      } else {
        _paintInactiveBlock(canvas, block);
      }
    }
    canvas.restore();
  }

  Offset _focusForBlock(_FloatingBlock block, double progress) {
    if (block.glyphBoxes.isEmpty) return block.center;
    final localFrontier = floatingNameInterpolatedGlyphCenter(
      block.glyphBoxes,
      progress,
    );
    final frontier = localFrontier == null
        ? block.center
        : block.origin + localFrontier;
    return Offset(
      ui.lerpDouble(block.center.dx, frontier.dx, 0.22)!,
      ui.lerpDouble(block.center.dy, frontier.dy, 0.18)!,
    );
  }

  double _cameraScale(_FloatingBlock block, Size viewport) {
    final hero = block.variant == FloatingNameBlockVariant.hero;
    final targetHeight =
        math.min(viewport.width, viewport.height) * (hero ? 0.095 : 0.075);
    return (targetHeight / math.max(block.style.fontSize ?? 28, 1)).clamp(
      0.86,
      1.34,
    );
  }

  void _paintArticleMarker(Canvas canvas, _FloatingBlock current) {
    final rulePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.075)
      ..strokeWidth = 1;
    final markerX = current.bounds.left - 22;
    canvas.drawLine(
      Offset(markerX, current.bounds.top - 10),
      Offset(markerX, current.bounds.bottom + 10),
      rulePaint,
    );
    final markPaint = Paint()..color = activeColor.withValues(alpha: 0.16);
    canvas.drawCircle(Offset(markerX, current.center.dy), 3.2, markPaint);
  }

  void _paintInactiveBlock(Canvas canvas, _FloatingBlock block) {
    final distance = block.index - activeIndex;
    final passed = distance < 0;
    final opacity = passed
        ? (0.46 - math.min(distance.abs(), 8) * 0.035).clamp(0.13, 0.46)
        : distance <= 2
        ? 0.072
        : 0.035;
    _paintBlockText(canvas, block, activeColor.withValues(alpha: opacity));
  }

  void _paintActiveBlock(Canvas canvas, _FloatingBlock block, double progress) {
    final typedCount = floatingNameTypedGraphemeCount(
      progress,
      block.glyphs.length,
    );
    // Color each grapheme directly. Clipping a fully bright TextPainter with
    // selection rectangles can expose the tops of glyphs on the next visual
    // row when a font's ink bounds overlap tight line metrics.
    block
        .painterForTypedPrefix(
          typedCount: typedCount,
          revealedColor: activeColor.withValues(alpha: 0.98),
          pendingColor: activeColor.withValues(alpha: 0.11),
        )
        .paint(canvas, block.origin);

    if (!motionEnabled || typedCount == 0) return;
    final activeGlyphIndex = typedCount - 1;
    if (activeGlyphIndex >= block.glyphBoxes.length) return;
    final box = block.glyphBoxes[activeGlyphIndex];
    if (box == Rect.zero) return;
    var strikePhase = (progress - progress.floor()).clamp(0.0, 1.0);
    if (strikePhase == 0 && progress > 0) strikePhase = 1;
    final pulse = 1 - Curves.easeOutCubic.transform(strikePhase);
    final fontSize = block.style.fontSize ?? 28;
    final stampWidth = math.max(box.width * 0.86, fontSize * 0.34);
    final stampRect = Rect.fromCenter(
      center: block.origin + Offset(box.center.dx, box.top - fontSize * 0.10),
      width: stampWidth,
      height: fontSize * 0.56,
    ).translate(0, -fontSize * 0.18 * pulse);
    final stampPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.62 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + fontSize * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stampRect, Radius.circular(fontSize * 0.06)),
      stampPaint,
    );
  }

  void _paintBlockText(Canvas canvas, _FloatingBlock block, Color color) {
    block.painterFor(color).paint(canvas, block.origin);
  }

  @override
  bool shouldRepaint(covariant _FloatingNamePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.cameraFromIndex != cameraFromIndex ||
        oldDelegate.audioService != audioService ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.wordByWordEnabled != wordByWordEnabled ||
        oldDelegate.motionEnabled != motionEnabled;
  }
}

bool floatingNameLineIsHighlighted(
  LyricLine line,
  List<SongHighlightSegment> segments,
) {
  if (segments.isEmpty) return false;
  final start = line.start ?? line.words.firstOrNull?.start;
  final end = line.end ?? line.words.lastOrNull?.end;
  if (start == null) return false;
  final resolvedEnd = end == null || end <= start ? start : end;
  return segments.any(
    (segment) => segment.start <= resolvedEnd && segment.end >= start,
  );
}

/// Smoothly follows the printed glyph frontier instead of snapping the camera
/// to the next glyph after every completed character.
Offset? floatingNameInterpolatedGlyphCenter(
  List<Rect> glyphBoxes,
  double progress,
) {
  final anchors = <(int, Offset)>[
    for (var index = 0; index < glyphBoxes.length; index++)
      if (glyphBoxes[index] != Rect.zero) (index, glyphBoxes[index].center),
  ];
  if (anchors.isEmpty) return null;
  final clamped = progress.clamp(0.0, glyphBoxes.length.toDouble());
  final left = anchors.lastWhere(
    (anchor) => anchor.$1 <= clamped,
    orElse: () => anchors.first,
  );
  final right = anchors.firstWhere(
    (anchor) => anchor.$1 >= clamped,
    orElse: () => anchors.last,
  );
  if (left.$1 == right.$1) return left.$2;
  final fraction = ((clamped - left.$1) / (right.$1 - left.$1)).clamp(0.0, 1.0);
  return Offset.lerp(
    left.$2,
    right.$2,
    Curves.easeInOutCubic.transform(fraction),
  );
}

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
