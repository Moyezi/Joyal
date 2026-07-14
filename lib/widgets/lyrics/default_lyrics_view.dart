import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_context.dart';
import '../../models/lyrics.dart';
import '../../models/song.dart';
import '../../providers/floating_name_ai_palette_provider.dart';
import '../../providers/glass_effect_provider.dart';
import '../../providers/lyrics_personalization_provider.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../lyrics_stage/lyrics_stage_shell.dart';
import 'lyric_print_effect.dart';
import 'lyrics_palette.dart';
import 'lyrics_personalization_sheet.dart';

class DefaultLyricsView extends ConsumerStatefulWidget {
  final LyricsData data;
  final Song song;
  final int activeIndex;
  final String title;
  final String artist;
  final Color? dynamicColor;
  final bool stageVisible;
  final bool positionUpdatesEnabled;
  final ValueChanged<bool>? onSettingsSheetVisibilityChanged;
  final ValueChanged<Duration> onSeek;

  const DefaultLyricsView({
    super.key,
    required this.data,
    required this.song,
    required this.activeIndex,
    required this.title,
    required this.artist,
    required this.dynamicColor,
    required this.stageVisible,
    required this.positionUpdatesEnabled,
    this.onSettingsSheetVisibilityChanged,
    required this.onSeek,
  });

  @override
  ConsumerState<DefaultLyricsView> createState() => DefaultLyricsViewState();
}

class DefaultLyricsViewState extends ConsumerState<DefaultLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, Offset> _pinchPointers = {};
  late List<GlobalKey> _lineKeys;
  Timer? _resumeTimer;
  double? _pinchStartDistance;
  bool _userBrowsing = false;
  bool _pinchSheetShown = false;
  bool _settingsSheetOpen = false;
  int _lastCenteredIndex = -1;

  LyricsData get data => widget.data;
  int get _activeIndex => widget.activeIndex;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(data.lines.length, (_) => GlobalKey());
    _scheduleCenter();
  }

  @override
  void didUpdateWidget(covariant DefaultLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != data) {
      _lineKeys = List.generate(data.lines.length, (_) => GlobalKey());
      _lastCenteredIndex = -1;
    }
    if (!_userBrowsing && _activeIndex != _lastCenteredIndex) {
      _scheduleCenter();
    }
  }

  void _scheduleCenter({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (_userBrowsing && !force)) return;
      _centerActiveLine();
    });
  }

  void _centerActiveLine() {
    final index = _activeIndex;
    if (index < 0 || index >= _lineKeys.length) return;
    final lineContext = _lineKeys[index].currentContext;
    if (lineContext == null) {
      if (!_scrollController.hasClients || data.lines.length < 2) return;
      final approximate =
          _scrollController.position.maxScrollExtent *
          index /
          (data.lines.length - 1);
      _scrollController
          .animateTo(
            approximate.clamp(
              _scrollController.position.minScrollExtent,
              _scrollController.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (!mounted) return;
            final resolvedContext = _lineKeys[index].currentContext;
            if (resolvedContext != null && resolvedContext.mounted) {
              Scrollable.ensureVisible(
                resolvedContext,
                alignment: 0.5,
                duration: const Duration(milliseconds: 180),
              );
            }
          });
      _lastCenteredIndex = index;
      return;
    }
    _lastCenteredIndex = index;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _resumeTimer?.cancel();
      _userBrowsing = true;
    } else if (notification is ScrollEndNotification && _userBrowsing) {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _userBrowsing = false);
        _scheduleCenter(force: true);
      });
    }
    return false;
  }

  void _seekToLine(LyricLine line) {
    final start = line.start;
    if (start == null) return;
    _resumeTimer?.cancel();
    _userBrowsing = false;
    widget.onSeek(start);
    _scheduleCenter(force: true);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pinchPointers[event.pointer] = event.localPosition;
    if (_pinchPointers.length == 2) {
      _pinchStartDistance = _currentPinchDistance();
      _pinchSheetShown = false;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pinchPointers.containsKey(event.pointer)) return;
    _pinchPointers[event.pointer] = event.localPosition;
    if (_pinchPointers.length < 2 || _pinchSheetShown || _settingsSheetOpen) {
      return;
    }

    final startDistance = _pinchStartDistance;
    final currentDistance = _currentPinchDistance();
    if (startDistance == null ||
        currentDistance == null ||
        startDistance < 24) {
      return;
    }

    final distanceDelta = (currentDistance - startDistance).abs();
    final scaleDelta = (currentDistance / startDistance - 1).abs();
    if (distanceDelta < 28 && scaleDelta < 0.12) return;

    _pinchSheetShown = true;
    _resumeTimer?.cancel();
    _userBrowsing = false;
    HapticFeedback.mediumImpact();
    unawaited(_showPersonalizationSheet());
  }

  void _handlePointerEnd(PointerEvent event) {
    _pinchPointers.remove(event.pointer);
    if (_pinchPointers.length < 2) {
      _pinchStartDistance = null;
      _pinchSheetShown = false;
    } else {
      _pinchStartDistance = _currentPinchDistance();
    }
  }

  double? _currentPinchDistance() {
    if (_pinchPointers.length < 2) return null;
    final points = _pinchPointers.values.take(2).toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  Future<void> _showPersonalizationSheet() async {
    if (_settingsSheetOpen || !mounted) return;
    _settingsSheetOpen = true;
    widget.onSettingsSheetVisibilityChanged?.call(true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const LyricsPersonalizationSheet(),
      );
    } finally {
      widget.onSettingsSheetVisibilityChanged?.call(false);
      if (mounted) {
        _settingsSheetOpen = false;
        _scheduleCenter(force: true);
      }
    }
  }

  Color _activeLyricColor(
    BuildContext context,
    LyricsPersonalizationState preferences,
  ) {
    return resolvedActiveLyricColor(context, preferences, widget.dynamicColor);
  }

  Color _inactiveLyricColor(
    BuildContext context,
    Color activeColor,
    double opacity,
  ) {
    return Color.lerp(
      context.secondaryColor,
      activeColor,
      0.38,
    )!.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());
  }

  double _inactiveLyricBlur(int distance, double maxBlur) {
    if (distance <= 0 || maxBlur <= 0.05) return 0;
    final ratio = (distance / 6).clamp(0.0, 1.0).toDouble();
    return (maxBlur * ratio).clamp(0.0, maxBlur).toDouble();
  }

  TextAlign _textAlignFor(LyricsAlignmentMode alignment) {
    return switch (alignment) {
      LyricsAlignmentMode.center => TextAlign.center,
      LyricsAlignmentMode.left => TextAlign.left,
      LyricsAlignmentMode.right => TextAlign.right,
    };
  }

  Alignment _scaleAlignmentFor(LyricsAlignmentMode alignment) {
    return switch (alignment) {
      LyricsAlignmentMode.center => Alignment.center,
      LyricsAlignmentMode.left => Alignment.centerLeft,
      LyricsAlignmentMode.right => Alignment.centerRight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    final preferences = ref.watch(lyricsPersonalizationProvider);
    final aiPalette = preferences.aiColorEnabled
        ? ref
              .watch(
                floatingNameAiPaletteProvider(
                  FloatingNameAiPaletteRequest(widget.song),
                ),
              )
              .maybeWhen(data: (palette) => palette, orElse: () => null)
        : null;
    final aiColors = aiPalette == null
        ? null
        : Theme.of(context).brightness == Brightness.dark
        ? aiPalette.dark
        : aiPalette.light;
    final aiPrimaryColor = aiColors == null ? null : Color(aiColors.primary);
    final inactiveBlur = ref
        .watch(
          glassEffectProvider.select(
            (state) => state.blurFor(GlassEffectTarget.lyricsPage),
          ),
        )
        .clamp(0.0, 12.0)
        .toDouble();
    final inactiveOpacity = ref
        .watch(
          glassEffectProvider.select(
            (state) => state.opacityFor(GlassEffectTarget.lyricsPage),
          ),
        )
        .clamp(0.0, 1.0)
        .toDouble();
    final activeColor = _activeLyricColor(context, preferences);
    final inactiveColor = _inactiveLyricColor(
      context,
      activeColor,
      inactiveOpacity,
    );
    final textAlign = _textAlignFor(preferences.alignment);
    final scaleAlignment = _scaleAlignmentFor(preferences.alignment);
    final activeStyle = context.textHeadlineMedium.copyWith(
      fontSize: preferences.fontSize,
      height: 1.35,
      color: activeColor,
      fontWeight: FontWeight.w800,
      fontFamily: preferences.effectiveFontFamily,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.22),
          offset: const Offset(0, 1),
          blurRadius: 8,
        ),
      ],
    );
    const inactiveScale = 0.82;
    final topInset = MediaQuery.paddingOf(context).top;
    final titleTop = topInset + 18;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  22,
                  viewportHeight * 0.42,
                  22,
                  viewportHeight * 0.42,
                ),
                itemCount: data.lines.length,
                itemBuilder: (context, lineIndex) {
                  final line = data.lines[lineIndex];
                  final isActive = lineIndex == active;
                  final canSeek = line.start != null;
                  final distance = active < 0
                      ? 0
                      : (lineIndex - active).abs().clamp(0, 6).toInt();
                  final blurSigma = isActive
                      ? 0.0
                      : _inactiveLyricBlur(distance, inactiveBlur);
                  return GestureDetector(
                    key: _lineKeys[lineIndex],
                    behavior: HitTestBehavior.translucent,
                    onTap: canSeek ? () => _seekToLine(line) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _FoliaLineFocus(
                        isActive: isActive,
                        isPassed: active >= 0 && lineIndex < active,
                        inactiveScale: inactiveScale,
                        alignment: scaleAlignment,
                        child: _LyricDepthFilteredLine(
                          blurSigma: blurSigma,
                          child: _TimedLyricText(
                            line: line,
                            enabled: preferences.wordByWordEnabled,
                            isActive: isActive,
                            highlightColor: isActive ? aiPrimaryColor : null,
                            positionUpdatesEnabled:
                                widget.positionUpdatesEnabled,
                            textAlign: textAlign,
                            style: activeStyle.copyWith(
                              color: isActive ? activeColor : inactiveColor,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          LyricsStageHeader(
            title: widget.title,
            artist: widget.artist,
            foreground: activeColor,
            visibleDuration: widget.stageVisible
                ? const Duration(seconds: 5)
                : null,
            padding: EdgeInsets.fromLTRB(22, titleTop, 22, 18),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

class _FoliaLineFocus extends StatelessWidget {
  final bool isActive;
  final bool isPassed;
  final double inactiveScale;
  final Alignment alignment;
  final Widget child;

  const _FoliaLineFocus({
    required this.isActive,
    required this.isPassed,
    required this.inactiveScale,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: isActive ? Offset.zero : Offset(isPassed ? -0.018 : 0.018, 0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isActive ? 1 : 0.86,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: isActive ? 1 : inactiveScale,
          alignment: alignment,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          child: child,
        ),
      ),
    );
  }
}

class _LyricDepthFilteredLine extends StatelessWidget {
  final double blurSigma;
  final Widget child;

  const _LyricDepthFilteredLine({required this.blurSigma, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: blurSigma),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, sigma, child) {
        if (sigma <= 0.05) return child!;
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _TimedLyricText extends ConsumerWidget {
  final LyricLine line;
  final bool enabled;
  final bool isActive;
  final Color? highlightColor;
  final bool positionUpdatesEnabled;
  final TextAlign textAlign;
  final TextStyle style;

  const _TimedLyricText({
    required this.line,
    required this.enabled,
    required this.isActive,
    required this.highlightColor,
    required this.positionUpdatesEnabled,
    required this.textAlign,
    required this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasWordTiming = line.words.any((word) => word.start != null);
    if (!enabled || !isActive || !hasWordTiming || !positionUpdatesEnabled) {
      return Text(
        line.text.isEmpty ? ' ' : line.text,
        textAlign: textAlign,
        style: highlightColor == null
            ? style
            : style.copyWith(color: highlightColor),
      );
    }
    final position = ref.watch(
      playerProvider.select((state) => state.position),
    );
    final motionEnabled = !MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: position.inMicroseconds.toDouble()),
      duration: const Duration(milliseconds: 180),
      curve: Curves.linear,
      builder: (context, microseconds, child) {
        final animatedPosition = Duration(microseconds: microseconds.round());
        final activeColor = highlightColor ?? style.color!;
        final pendingColor = style.color!.withValues(alpha: 0.24);
        return Text.rich(
          TextSpan(
            children: [
              for (final word in line.words)
                ..._glyphSpans(
                  word,
                  animatedPosition,
                  style,
                  pendingColor,
                  activeColor,
                  motionEnabled,
                ),
            ],
          ),
          textAlign: textAlign,
        );
      },
    );
  }

  List<InlineSpan> _glyphSpans(
    LyricWord word,
    Duration position,
    TextStyle style,
    Color pendingColor,
    Color activeColor,
    bool motionEnabled,
  ) {
    final glyphs = word.text.characters.toList(growable: false);
    if (glyphs.isEmpty) return const [];
    return List<InlineSpan>.generate(glyphs.length, (glyphIndex) {
      final rawProgress = lyricGlyphProgress(
        word,
        position,
        glyphIndex: glyphIndex,
        glyphCount: glyphs.length,
      );
      final progress = Curves.easeOutCubic.transform(rawProgress);
      final frontier = (1 - (rawProgress * 2 - 1).abs()).clamp(0.0, 1.0);
      final shadows = <Shadow>[
        ...?style.shadows,
        if (frontier > 0.02)
          Shadow(
            color: activeColor.withValues(alpha: 0.42 * frontier),
            blurRadius: 12 * frontier,
          ),
      ];
      final glyph = glyphs[glyphIndex];
      final glyphStyle = style.copyWith(
        color: Color.lerp(pendingColor, activeColor, progress),
        shadows: shadows,
      );
      final effectEnabled = motionEnabled && glyph.trim().isNotEmpty;
      final fontSize = glyphStyle.fontSize ?? 28;
      final bounceOffset = effectEnabled
          ? lyricPrintGlyphBounceOffset(rawProgress, fontSize)
          : 0.0;
      final stampPulse = effectEnabled
          ? lyricPrintStampPulse(rawProgress)
          : 0.0;
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Transform.translate(
          offset: Offset(0, bounceOffset),
          transformHitTests: false,
          child: CustomPaint(
            painter: _DefaultLyricPrintStampPainter(
              color: activeColor,
              fontSize: fontSize,
              pulse: stampPulse,
            ),
            child: Text(glyph, style: glyphStyle),
          ),
        ),
      );
    });
  }
}

class _DefaultLyricPrintStampPainter extends CustomPainter {
  final Color color;
  final double fontSize;
  final double pulse;

  const _DefaultLyricPrintStampPainter({
    required this.color,
    required this.fontSize,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pulse <= 0 || size.isEmpty) return;
    final stampWidth = math.max(size.width * 0.86, fontSize * 0.34);
    final stampRect = Rect.fromCenter(
      center: Offset(size.width / 2, -fontSize * (0.10 + 0.18 * pulse)),
      width: stampWidth,
      height: fontSize * 0.56,
    );
    final stampPaint = Paint()
      ..color = color.withValues(alpha: 0.62 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + fontSize * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stampRect, Radius.circular(fontSize * 0.06)),
      stampPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DefaultLyricPrintStampPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.pulse != pulse;
  }
}
