import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../config/theme_context.dart';
import '../models/lyrics.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/library_provider.dart';
import '../providers/lyrics_personalization_provider.dart';
import '../providers/lyrics_provider.dart';
import '../providers/lyrics_source_provider.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';
import '../utils/app_toast.dart';
import '../widgets/album_visual_palette.dart';
import '../widgets/frosted_glass.dart';

class _LyricsPaletteRequest {
  final String coverArtId;
  final String coverSourceId;
  final String coverUrl;
  final Brightness brightness;

  const _LyricsPaletteRequest({
    required this.coverArtId,
    required this.coverSourceId,
    required this.coverUrl,
    required this.brightness,
  });

  @override
  bool operator ==(Object other) {
    return other is _LyricsPaletteRequest &&
        other.coverArtId == coverArtId &&
        other.coverSourceId == coverSourceId &&
        other.brightness == brightness;
  }

  @override
  int get hashCode => Object.hash(coverArtId, coverSourceId, brightness);
}

final _lyricsPaletteProvider = FutureProvider.autoDispose
    .family<AlbumVisualPalette, _LyricsPaletteRequest>((ref, request) {
      return AlbumVisualPalette.resolve(
        coverArtId: request.coverArtId,
        coverUrl: request.coverUrl,
        brightness: request.brightness,
      );
    });

Color _dynamicLyricColorFromPalette(
  AlbumVisualPalette palette,
  Brightness brightness,
) {
  final source = Color.lerp(
    palette.waveformAccentFor(brightness),
    palette.top,
    0.18,
  )!;
  final pastel = Color.lerp(
    source,
    Colors.white,
    brightness == Brightness.dark ? 0.50 : 0.28,
  )!;
  final minLuminance = brightness == Brightness.dark ? 0.58 : 0.30;
  final maxLuminance = brightness == Brightness.dark ? 0.86 : 0.58;
  return _withMaximumLuminance(
    _withMinimumLuminance(pastel, minLuminance),
    maxLuminance,
  );
}

Color _dynamicFallbackColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFE8EEFF)
      : const Color(0xFF6D7FA8);
}

Color _withMinimumLuminance(Color color, double target) {
  if (color.computeLuminance() >= target) return color;
  for (var step = 1; step <= 12; step++) {
    final adjusted = Color.lerp(color, Colors.white, step / 12)!;
    if (adjusted.computeLuminance() >= target) return adjusted;
  }
  return Colors.white;
}

Color _withMaximumLuminance(Color color, double target) {
  if (color.computeLuminance() <= target) return color;
  for (var step = 1; step <= 12; step++) {
    final adjusted = Color.lerp(color, Colors.black, step / 12)!;
    if (adjusted.computeLuminance() <= target) return adjusted;
  }
  return Colors.black;
}

class LyricsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final bool positionUpdatesEnabled;
  final ValueChanged<bool>? onSettingsSheetVisibilityChanged;

  const LyricsScreen({
    super.key,
    this.onBack,
    this.positionUpdatesEnabled = true,
    this.onSettingsSheetVisibilityChanged,
  });

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  @override
  Widget build(BuildContext context) {
    final song = ref.watch(playerProvider.select((state) => state.currentSong));
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = song != null && api != null && song.coverArt.isNotEmpty
        ? api.getCoverArtUrl(song.coverArt)
        : '';
    final brightness = Theme.of(context).brightness;
    final coverSourceId = api == null ? '' : '${api.baseUrl}|${api.username}';
    final colorMode = ref.watch(
      lyricsPersonalizationProvider.select((state) => state.colorMode),
    );
    final dynamicLyricColor =
        song == null || colorMode != LyricsColorMode.dynamicLight
        ? null
        : ref
              .watch(
                _lyricsPaletteProvider(
                  _LyricsPaletteRequest(
                    coverArtId: song.coverArt,
                    coverSourceId: coverSourceId,
                    coverUrl: coverUrl,
                    brightness: brightness,
                  ),
                ),
              )
              .maybeWhen(
                data: (palette) =>
                    _dynamicLyricColorFromPalette(palette, brightness),
                orElse: () => null,
              );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      // The enclosing now-playing route owns the shared album background.
      // Keeping one background avoids stacking two full-screen blur/animation
      // layers while preserving exactly the same visual beneath both pages.
      body: song == null
          ? const SafeArea(
              child: Center(
                child: Text('\u6682\u65e0\u64ad\u653e\u6b4c\u66f2'),
              ),
            )
          : ref
                .watch(lyricsProvider(song))
                .when(
                  loading: () {
                    return const SafeArea(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  error: (error, stackTrace) {
                    return SafeArea(
                      child: _Message(
                        icon: Icons.cloud_off_outlined,
                        text: '\u6b4c\u8bcd\u52a0\u8f7d\u5931\u8d25',
                        detail: error.toString(),
                      ),
                    );
                  },
                  data: (lyrics) {
                    if (lyrics.isEmpty) {
                      return const SafeArea(
                        child: _Message(
                          icon: Icons.lyrics_outlined,
                          text: '\u6682\u65e0\u6b4c\u8bcd',
                          detail:
                              '\u5f53\u524d\u670d\u52a1\u5668\u672a\u63d0\u4f9b\u8fd9\u9996\u6b4c\u7684\u6b4c\u8bcd',
                        ),
                      );
                    }
                    return _LyricsPositionedList(
                      data: lyrics,
                      title: song.title,
                      artist: song.artist,
                      dynamicColor: dynamicLyricColor,
                      positionUpdatesEnabled: widget.positionUpdatesEnabled,
                      onSettingsSheetVisibilityChanged:
                          widget.onSettingsSheetVisibilityChanged,
                    );
                  },
                ),
    );
  }
}

class _LyricsPositionedList extends ConsumerWidget {
  final LyricsData data;
  final String title;
  final String artist;
  final Color? dynamicColor;
  final bool positionUpdatesEnabled;
  final ValueChanged<bool>? onSettingsSheetVisibilityChanged;

  const _LyricsPositionedList({
    required this.data,
    required this.title,
    required this.artist,
    this.dynamicColor,
    required this.positionUpdatesEnabled,
    this.onSettingsSheetVisibilityChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(
      playerProvider.select((state) => activeLyricIndex(data, state.position)),
    );
    return _LyricsList(
      data: data,
      activeIndex: activeIndex,
      title: title,
      artist: artist,
      dynamicColor: dynamicColor,
      positionUpdatesEnabled: positionUpdatesEnabled,
      onSettingsSheetVisibilityChanged: onSettingsSheetVisibilityChanged,
      onSeek: (position) {
        unawaited(ref.read(playerProvider.notifier).seek(position));
      },
    );
  }
}

class _LyricsList extends ConsumerStatefulWidget {
  final LyricsData data;
  final int activeIndex;
  final String title;
  final String artist;
  final Color? dynamicColor;
  final bool positionUpdatesEnabled;
  final ValueChanged<bool>? onSettingsSheetVisibilityChanged;
  final ValueChanged<Duration> onSeek;

  const _LyricsList({
    required this.data,
    required this.activeIndex,
    required this.title,
    required this.artist,
    required this.dynamicColor,
    required this.positionUpdatesEnabled,
    this.onSettingsSheetVisibilityChanged,
    required this.onSeek,
  });

  @override
  ConsumerState<_LyricsList> createState() => _LyricsListState();
}

class _LyricsListState extends ConsumerState<_LyricsList> {
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
  void didUpdateWidget(covariant _LyricsList oldWidget) {
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
        builder: (_) => const _LyricsPersonalizationSheet(),
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
    return switch (preferences.colorMode) {
      LyricsColorMode.system => context.primaryColor,
      LyricsColorMode.black => Colors.black,
      LyricsColorMode.white => Colors.white,
      LyricsColorMode.dynamicLight =>
        widget.dynamicColor ??
            _dynamicFallbackColor(Theme.of(context).brightness),
    };
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
      LyricsAlignmentMode.justify => TextAlign.justify,
    };
  }

  Alignment _scaleAlignmentFor(LyricsAlignmentMode alignment) {
    return switch (alignment) {
      LyricsAlignmentMode.center => Alignment.center,
      LyricsAlignmentMode.left => Alignment.centerLeft,
      LyricsAlignmentMode.justify => Alignment.centerLeft,
    };
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    final preferences = ref.watch(lyricsPersonalizationProvider);
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
    const inactiveScale = 0.70;
    final topInset = MediaQuery.paddingOf(context).top;
    final headerReserve = MediaQuery.textScalerOf(context).scale(52) + 64;
    final lyricsTop = topInset + headerReserve;
    final titleTop = topInset + 18;
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
            top: lyricsTop,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  22,
                  0,
                  22,
                  MediaQuery.sizeOf(context).height * 0.42,
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
                      child: AnimatedScale(
                        scale: isActive ? 1 : inactiveScale,
                        alignment: scaleAlignment,
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        child: _LyricDepthFilteredLine(
                          blurSigma: blurSigma,
                          child: _TimedLyricText(
                            line: line,
                            enabled: preferences.wordByWordEnabled,
                            isActive: isActive,
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
          Padding(
            padding: EdgeInsets.fromLTRB(22, titleTop, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTitleLarge.copyWith(
                    color: activeColor.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textBodyMedium.copyWith(
                    color: activeColor.withValues(alpha: 0.68),
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

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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
  final bool positionUpdatesEnabled;
  final TextAlign textAlign;
  final TextStyle style;

  const _TimedLyricText({
    required this.line,
    required this.enabled,
    required this.isActive,
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
        style: style,
      );
    }
    final position = ref.watch(
      playerProvider.select((state) => state.position),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(end: position.inMicroseconds.toDouble()),
      duration: const Duration(milliseconds: 180),
      curve: Curves.linear,
      builder: (context, microseconds, child) {
        final animatedPosition = Duration(microseconds: microseconds.round());
        final pendingColor = style.color!.withValues(alpha: 0.30);
        return Text.rich(
          TextSpan(
            children: [
              for (final word in line.words)
                TextSpan(
                  text: word.text,
                  style: style.copyWith(
                    color: Color.lerp(
                      pendingColor,
                      style.color,
                      Curves.easeOut.transform(
                        lyricWordProgress(word, animatedPosition),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          textAlign: textAlign,
        );
      },
    );
  }
}

class _LyricsPersonalizationSheet extends ConsumerWidget {
  const _LyricsPersonalizationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(lyricsPersonalizationProvider);
    final currentSong = ref.watch(
      playerProvider.select((state) => state.currentSong),
    );
    final api = ref.watch(subsonicApiProvider);
    final hasLyricsTarget = currentSong != null && api != null;
    final lyricsSource = currentSong == null
        ? LyricsSource.amll
        : ref.watch(lyricsSourceForSongProvider(currentSong));
    final currentLyrics = currentSong == null
        ? null
        : ref.watch(lyricsProvider(currentSong));
    final resolvedLyricsSource = currentLyrics?.asData?.value.source;
    const inactiveLyricsTarget = GlassEffectTarget.lyricsPage;
    const drawerGlassTarget = GlassEffectTarget.lyricsDrawer;
    final inactiveBlur = ref
        .watch(
          glassEffectProvider.select(
            (state) => state.blurFor(inactiveLyricsTarget),
          ),
        )
        .clamp(0.0, 12.0)
        .toDouble();
    final inactiveOpacity = ref
        .watch(
          glassEffectProvider.select(
            (state) => state.opacityFor(inactiveLyricsTarget),
          ),
        )
        .clamp(0.0, 1.0)
        .toDouble();
    final drawerBlur = ref.watch(
      glassEffectProvider.select((state) => state.blurFor(drawerGlassTarget)),
    );
    final drawerTintOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(drawerGlassTarget),
      ),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.84,
      ),
      child: _LyricsDrawerGlass(
        blurSigma: drawerBlur,
        tintColor: context.surfaceColor,
        tintOpacity: drawerTintOpacity,
        borderColor: context.primaryColor,
        borderOpacity: isDark ? 0.08 : 0.06,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.secondaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '歌词个性化',
                      style: context.textTitleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '恢复默认',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      unawaited(
                        ref
                            .read(lyricsPersonalizationProvider.notifier)
                            .reset(),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setBlur(
                              inactiveLyricsTarget,
                              inactiveLyricsTarget.defaultBlur,
                            ),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setOpacity(
                              inactiveLyricsTarget,
                              inactiveLyricsTarget.defaultOpacity,
                            ),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setBlur(
                              drawerGlassTarget,
                              drawerGlassTarget.defaultBlur,
                            ),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setOpacity(
                              drawerGlassTarget,
                              drawerGlassTarget.defaultOpacity,
                            ),
                      );
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '双指捏合可再次打开；所有更改会立即生效。',
                style: context.textBodySmall.copyWith(
                  color: context.secondaryColor,
                ),
              ),
              const SizedBox(height: 22),
              _LyricsSettingsSection(
                title: '歌词内容',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasLyricsTarget) ...[
                      const _LyricsOptionLabel(title: '歌词来源'),
                      const SizedBox(height: 4),
                      Text(
                        '当前歌曲：${resolvedLyricsSource?.label ?? '正在识别…'}',
                        style: context.textBodySmall.copyWith(
                          color: context.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lyricsSource.description,
                        style: context.textBodySmall.copyWith(
                          color: context.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _LyricsChoiceGrid(
                        children: [
                          for (final source in LyricsSource.values)
                            _LyricsChoiceButton(
                              label: _lyricsSourceLabel(source),
                              icon: source == LyricsSource.amll
                                  ? Icons.auto_awesome_rounded
                                  : Icons.storage_rounded,
                              selected: lyricsSource == source,
                              onTap: () {
                                if (lyricsSource == source) return;
                                HapticFeedback.selectionClick();
                                unawaited(
                                  _setCurrentLyricsSource(context, ref, source),
                                );
                              },
                            ),
                        ],
                      ),
                      const _LyricsSectionDivider(),
                    ],
                    _LyricsToggleTile(
                      title: '逐字高亮',
                      subtitle: '内嵌逐字或 TTML 含字级时间轴时生效',
                      value: preferences.wordByWordEnabled,
                      onChanged: (enabled) {
                        HapticFeedback.selectionClick();
                        unawaited(
                          ref
                              .read(lyricsPersonalizationProvider.notifier)
                              .setWordByWordEnabled(enabled),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _LyricsSettingsSection(
                title: '文字',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LyricsOptionLabel(title: '对齐'),
                    const SizedBox(height: 8),
                    _LyricsChoiceGrid(
                      columns: 3,
                      children: [
                        for (final alignment in LyricsAlignmentMode.values)
                          _LyricsChoiceButton(
                            label: _lyricsAlignmentLabel(alignment),
                            icon: _iconForAlignment(alignment),
                            selected: preferences.alignment == alignment,
                            compact: true,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              unawaited(
                                ref
                                    .read(
                                      lyricsPersonalizationProvider.notifier,
                                    )
                                    .setAlignment(alignment),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _LyricsOptionLabel(title: '字号'),
                    const SizedBox(height: 4),
                    _LyricsSliderRow(
                      icon: Icons.format_size_rounded,
                      value: preferences.fontSize,
                      min: LyricsPersonalizationState.minFontSize,
                      max: LyricsPersonalizationState.maxFontSize,
                      divisions: 24,
                      label: preferences.fontSize.toStringAsFixed(0),
                      valueText: preferences.fontSize.toStringAsFixed(0),
                      onChanged: (value) => ref
                          .read(lyricsPersonalizationProvider.notifier)
                          .setFontSize(value),
                      onChangeEnd: (_) {},
                    ),
                    const SizedBox(height: 8),
                    _LyricsChoiceGrid(
                      children: [
                        _LyricsChoiceButton(
                          label: '系统字体',
                          icon: _iconForFontFamily(LyricsFontFamily.system),
                          selected:
                              preferences.fontFamily == LyricsFontFamily.system,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            unawaited(
                              ref
                                  .read(lyricsPersonalizationProvider.notifier)
                                  .setFontFamily(LyricsFontFamily.system),
                            );
                          },
                        ),
                        _LyricsChoiceButton(
                          label: _customFontLabel(preferences),
                          icon: _iconForFontFamily(LyricsFontFamily.custom),
                          selected:
                              preferences.fontFamily ==
                                  LyricsFontFamily.custom &&
                              preferences.hasCustomFont,
                          onTap: () {
                            unawaited(
                              _handleCustomFontTap(context, ref, preferences),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preferences.hasCustomFont
                          ? '已使用 ${preferences.customFontName}；点击可更换。'
                          : '可导入 .ttf 字体，仅用于歌词显示。',
                      style: context.textBodySmall.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _LyricsSettingsSection(
                title: '显示样式',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LyricsOptionLabel(title: '颜色'),
                    const SizedBox(height: 8),
                    _LyricsChoiceGrid(
                      children: [
                        for (final mode in LyricsColorMode.values)
                          _LyricsChoiceButton(
                            label: mode.label,
                            icon: _iconForColorMode(mode),
                            selected: preferences.colorMode == mode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              unawaited(
                                ref
                                    .read(
                                      lyricsPersonalizationProvider.notifier,
                                    )
                                    .setColorMode(mode),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _LyricsSettingsSection(
                title: '非当前行',
                child: Column(
                  children: [
                    _LyricsSliderRow(
                      icon: Icons.blur_on_rounded,
                      value: inactiveBlur,
                      max: 12,
                      divisions: 12,
                      label: inactiveBlur.toStringAsFixed(0),
                      valueText: inactiveBlur <= 0.05
                          ? '关闭'
                          : inactiveBlur.toStringAsFixed(0),
                      onChanged: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setBlur(inactiveLyricsTarget, value, persist: false),
                      onChangeEnd: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setBlur(inactiveLyricsTarget, value),
                    ),
                    _LyricsSliderRow(
                      icon: Icons.opacity_rounded,
                      value: inactiveOpacity,
                      max: 1,
                      divisions: 20,
                      label: '${(inactiveOpacity * 100).round()}%',
                      valueText: '${(inactiveOpacity * 100).round()}%',
                      onChanged: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setOpacity(
                            inactiveLyricsTarget,
                            value,
                            persist: false,
                          ),
                      onChangeEnd: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setOpacity(inactiveLyricsTarget, value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _LyricsSettingsSection(
                title: '设置面板',
                child: Column(
                  children: [
                    _LyricsSliderRow(
                      icon: Icons.blur_on_rounded,
                      value: drawerBlur.clamp(0.0, 30.0).toDouble(),
                      max: 30,
                      divisions: 15,
                      label: drawerBlur.toStringAsFixed(0),
                      valueText: drawerBlur <= 0.05
                          ? '关闭'
                          : drawerBlur.toStringAsFixed(0),
                      onChanged: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setBlur(drawerGlassTarget, value, persist: false),
                      onChangeEnd: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setBlur(drawerGlassTarget, value),
                    ),
                    _LyricsSliderRow(
                      icon: Icons.opacity_rounded,
                      value: drawerTintOpacity.clamp(0.0, 1.0).toDouble(),
                      max: 1,
                      divisions: 20,
                      label: '${(drawerTintOpacity * 100).round()}%',
                      valueText: '${(drawerTintOpacity * 100).round()}%',
                      onChanged: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setOpacity(drawerGlassTarget, value, persist: false),
                      onChangeEnd: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setOpacity(drawerGlassTarget, value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _LyricsSettingsSection(
                title: '缓存管理',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLyricsTarget ? '仅操作当前歌词来源。' : '播放歌曲后可管理缓存。',
                      style: context.textBodySmall.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _LyricsActionButton(
                            onPressed: hasLyricsTarget
                                ? () => unawaited(
                                    _refreshCurrentLyrics(context, ref),
                                  )
                                : null,
                            icon: Icons.refresh_rounded,
                            label: '刷新歌词',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LyricsActionButton(
                            onPressed: hasLyricsTarget
                                ? () => unawaited(
                                    _clearCurrentLyrics(context, ref),
                                  )
                                : null,
                            icon: Icons.delete_outline_rounded,
                            label: '清除缓存',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCustomFontTap(
    BuildContext context,
    WidgetRef ref,
    LyricsPersonalizationState preferences,
  ) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(lyricsPersonalizationProvider.notifier);
    if (preferences.hasCustomFont &&
        preferences.fontFamily != LyricsFontFamily.custom) {
      await notifier.setFontFamily(LyricsFontFamily.custom);
      if (context.mounted) {
        showAppToast(context, '已使用自定义字体', replaceCurrent: true);
      }
      return;
    }

    final picked = await notifier.pickCustomFont();
    if (!context.mounted || picked == null) return;
    showAppToast(
      context,
      picked ? '自定义字体已更新' : '字体加载失败，请选择有效的 .ttf 文件',
      replaceCurrent: true,
    );
  }

  Future<void> _refreshCurrentLyrics(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final song = ref.read(playerProvider).currentSong;
    final api = ref.read(subsonicApiProvider);
    if (song == null || api == null) return;
    final source = ref.read(lyricsSourceForSongProvider(song));
    try {
      await LyricsService(
        api: api,
        dio: ref.read(dioProvider),
      ).fetch(song, forceRefresh: true, source: source);
      invalidateLyricsMemoryCache(api, song, source: source);
      ref.invalidate(lyricsProvider(song));
      await ref.read(lyricsProvider(song).future);
      if (context.mounted) {
        showAppToast(context, '已重新获取${source.label}', replaceCurrent: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '歌词重新获取失败', replaceCurrent: true);
      }
    }
  }

  Future<void> _clearCurrentLyrics(BuildContext context, WidgetRef ref) async {
    final song = ref.read(playerProvider).currentSong;
    final api = ref.read(subsonicApiProvider);
    if (song == null || api == null) return;
    final source = ref.read(lyricsSourceForSongProvider(song));
    try {
      await LyricsService(
        api: api,
        dio: ref.read(dioProvider),
      ).clearCachedLyrics(song, source: source);
      invalidateLyricsMemoryCache(api, song, source: source);
      if (context.mounted) {
        showAppToast(context, '已清除${source.label}缓存', replaceCurrent: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '歌词缓存清除失败', replaceCurrent: true);
      }
    }
  }

  Future<void> _setCurrentLyricsSource(
    BuildContext context,
    WidgetRef ref,
    LyricsSource source,
  ) async {
    final song = ref.read(playerProvider).currentSong;
    final api = ref.read(subsonicApiProvider);
    if (song == null || api == null) return;
    try {
      await ref
          .read(lyricsSourceOverridesProvider.notifier)
          .setSourceFor(api, song, source);
      await ref.read(lyricsProvider(song).future);
      if (context.mounted) {
        showAppToast(context, '本首歌已切换为${source.label}', replaceCurrent: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '歌词来源切换失败', replaceCurrent: true);
      }
    }
  }

  String _customFontLabel(LyricsPersonalizationState preferences) {
    final name = preferences.customFontName;
    if (name == null || name.isEmpty) return '选择 .ttf';
    const maxLength = 14;
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength - 1)}…';
  }

  String _lyricsSourceLabel(LyricsSource source) {
    return switch (source) {
      LyricsSource.amll => '自动优选',
      LyricsSource.embedded => '仅内嵌',
    };
  }

  String _lyricsAlignmentLabel(LyricsAlignmentMode alignment) {
    return switch (alignment) {
      LyricsAlignmentMode.center => '居中',
      LyricsAlignmentMode.left => '左对齐',
      LyricsAlignmentMode.justify => '两端',
    };
  }

  IconData _iconForColorMode(LyricsColorMode mode) {
    return switch (mode) {
      LyricsColorMode.system => Icons.brightness_auto_rounded,
      LyricsColorMode.black => Icons.circle_rounded,
      LyricsColorMode.white => Icons.circle_outlined,
      LyricsColorMode.dynamicLight => Icons.palette_outlined,
    };
  }

  IconData _iconForAlignment(LyricsAlignmentMode alignment) {
    return switch (alignment) {
      LyricsAlignmentMode.center => Icons.format_align_center_rounded,
      LyricsAlignmentMode.left => Icons.format_align_left_rounded,
      LyricsAlignmentMode.justify => Icons.format_align_justify_rounded,
    };
  }

  IconData _iconForFontFamily(LyricsFontFamily family) {
    return switch (family) {
      LyricsFontFamily.system => Icons.text_fields_rounded,
      LyricsFontFamily.custom => Icons.upload_file_rounded,
    };
  }
}

class _LyricsDrawerGlass extends StatelessWidget {
  final double blurSigma;
  final Color tintColor;
  final double tintOpacity;
  final Color borderColor;
  final double borderOpacity;
  final Widget child;

  const _LyricsDrawerGlass({
    required this.blurSigma,
    required this.tintColor,
    required this.tintOpacity,
    required this.borderColor,
    required this.borderOpacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) {
      return _buildGlass(filtersSettled: true, child: child);
    }
    return AnimatedBuilder(
      animation: routeAnimation,
      child: child,
      builder: (context, child) => _buildGlass(
        filtersSettled: routeAnimation.status == AnimationStatus.completed,
        child: child!,
      ),
    );
  }

  Widget _buildGlass({required bool filtersSettled, required Widget child}) {
    final movingTintOpacity = tintOpacity < 0.72 ? 0.72 : tintOpacity;
    return FrostedGlass(
      // A moving, nearly full-screen backdrop/refraction filter is the worst
      // case for the GPU. Keep the glass tint during route movement, then
      // restore the full blur/refraction as soon as the drawer settles.
      blurSigma: filtersSettled ? blurSigma : 0,
      liquidGlassEnabled: filtersSettled ? null : false,
      borderRadius: BorderRadius.circular(28),
      tintColor: tintColor,
      tintOpacity: filtersSettled ? tintOpacity : movingTintOpacity,
      borderColor: borderColor,
      borderOpacity: borderOpacity,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
      child: child,
    );
  }
}

class _LyricsSettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _LyricsSettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTitleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _LyricsOptionLabel extends StatelessWidget {
  final String title;

  const _LyricsOptionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textBodyMedium.copyWith(
        color: context.secondaryColor,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LyricsSectionDivider extends StatelessWidget {
  const _LyricsSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        height: 1,
        color: context.primaryColor.withValues(alpha: 0.08),
      ),
    );
  }
}

class _LyricsToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _LyricsToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textBodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.textBodySmall.copyWith(
                    color: context.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LyricsChoiceGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;

  const _LyricsChoiceGrid({required this.children, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class _LyricsActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  const _LyricsActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? context.primaryColor : context.secondaryColor;

    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: context.primaryColor.withValues(
            alpha: enabled ? 0.055 : 0.025,
          ),
          side: BorderSide(
            color: foreground.withValues(alpha: enabled ? 0.22 : 0.08),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: context.textBodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _LyricsSliderRow extends StatelessWidget {
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final String valueText;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _LyricsSliderRow({
    required this.icon,
    required this.value,
    this.min = 0,
    required this.max,
    required this.divisions,
    required this.label,
    required this.valueText,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.secondaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: context.textBodySmall.copyWith(
              color: context.secondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _LyricsChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _LyricsChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? context.primaryColor : context.secondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: compact ? 42 : 48,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: selected
                ? context.primaryColor.withValues(alpha: 0.14)
                : context.primaryColor.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? context.primaryColor.withValues(alpha: 0.36)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              SizedBox(width: compact ? 5 : 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact ? context.textBodySmall : context.textBodyMedium)
                          .copyWith(
                            color: foreground,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String detail;

  const _Message({
    required this.icon,
    required this.text,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: context.secondaryColor),
            const SizedBox(height: 16),
            Text(text, style: context.textHeadlineMedium),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: context.textBodyMedium.copyWith(
                color: context.secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
