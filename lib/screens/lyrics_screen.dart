import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../config/theme_context.dart';
import '../models/lyrics.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/lyrics_personalization_provider.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/album_visual_palette.dart';
import '../widgets/dynamic_album_background.dart';
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

  const LyricsScreen({super.key, this.onBack});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final song = player.currentSong;
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
      body: DynamicAlbumBackground(
        coverArtId: song?.coverArt ?? '',
        coverUrl: coverUrl,
        motionSeed: song?.id,
        child: song == null
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
                      return _LyricsList(
                        data: lyrics,
                        position: player.position,
                        title: song.title,
                        artist: song.artist,
                        dynamicColor: dynamicLyricColor,
                        onSeek: (position) {
                          unawaited(
                            ref.read(playerProvider.notifier).seek(position),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

class _LyricsList extends ConsumerStatefulWidget {
  final LyricsData data;
  final Duration position;
  final String title;
  final String artist;
  final Color? dynamicColor;
  final ValueChanged<Duration> onSeek;

  const _LyricsList({
    required this.data,
    required this.position,
    required this.title,
    required this.artist,
    required this.dynamicColor,
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
  Duration get position => widget.position;

  int get _activeIndex => activeLyricIndex(data, position);

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
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _LyricsPersonalizationSheet(),
      );
    } finally {
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

  Color _inactiveLyricColor(BuildContext context, Color activeColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.52 : 0.46;
    return Color.lerp(
      context.secondaryColor,
      activeColor,
      0.38,
    )!.withValues(alpha: opacity);
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
    final overlayBlur = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.lyricsPage),
      ),
    );
    final activeColor = _activeLyricColor(context, preferences);
    final inactiveColor = _inactiveLyricColor(context, activeColor);
    final textAlign = _textAlignFor(preferences.alignment);
    final scaleAlignment = _scaleAlignmentFor(preferences.alignment);
    final fontFamily = preferences.fontFamily;
    final fontFamilyFallback = fontFamily.fontFamilyFallback.isEmpty
        ? null
        : fontFamily.fontFamilyFallback;
    final activeStyle = context.textHeadlineMedium.copyWith(
      fontSize: preferences.fontSize,
      height: 1.35,
      color: activeColor,
      fontWeight: FontWeight.w800,
      fontFamily: fontFamily.fontFamily,
      fontFamilyFallback: fontFamilyFallback,
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
                  final text = line.text.isEmpty ? ' ' : line.text;
                  final canSeek = line.start != null;
                  final distance = active < 0
                      ? 0
                      : (lineIndex - active).abs().clamp(0, 6);
                  final blurSigma = isActive
                      ? 0.0
                      : (distance * 0.95).clamp(0.0, 4.8);
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
                          child: Text(
                            text,
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
          _LyricsGlassDepthOverlay(blurSigma: overlayBlur),
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

class _LyricsPersonalizationSheet extends ConsumerWidget {
  const _LyricsPersonalizationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(lyricsPersonalizationProvider);
    final blurSigma = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.lyricsPage),
      ),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.84,
      ),
      child: FrostedGlass(
        blurSigma: blurSigma,
        borderRadius: BorderRadius.circular(28),
        tintColor: context.surfaceColor,
        tintOpacity: isDark ? 0.88 : 0.82,
        borderColor: context.primaryColor,
        borderOpacity: isDark ? 0.08 : 0.06,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
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
                              GlassEffectTarget.lyricsPage,
                              GlassEffectTarget.lyricsPage.defaultBlur,
                            ),
                      );
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '双指捏合可再次打开这里，调整会实时应用到歌词页。',
                style: context.textBodySmall.copyWith(
                  color: context.secondaryColor,
                ),
              ),
              const SizedBox(height: 18),
              _LyricsSettingsSection(
                title: '歌词颜色',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
                                .read(lyricsPersonalizationProvider.notifier)
                                .setColorMode(mode),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _LyricsSettingsSection(
                title: '毛玻璃效果',
                child: Row(
                  children: [
                    Icon(
                      Icons.blur_on_rounded,
                      size: 20,
                      color: context.secondaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        value: blurSigma.clamp(0.0, 30.0).toDouble(),
                        min: 0,
                        max: 30,
                        divisions: 15,
                        label: blurSigma.toStringAsFixed(0),
                        onChanged: (value) => ref
                            .read(glassEffectProvider.notifier)
                            .setBlur(GlassEffectTarget.lyricsPage, value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        blurSigma <= 0.05 ? '关闭' : blurSigma.toStringAsFixed(0),
                        textAlign: TextAlign.end,
                        style: context.textBodySmall.copyWith(
                          color: context.secondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _LyricsSettingsSection(
                title: '对齐方式',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final alignment in LyricsAlignmentMode.values)
                      _LyricsChoiceButton(
                        label: alignment.label,
                        icon: _iconForAlignment(alignment),
                        selected: preferences.alignment == alignment,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          unawaited(
                            ref
                                .read(lyricsPersonalizationProvider.notifier)
                                .setAlignment(alignment),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _LyricsSettingsSection(
                title: '字体字号',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.format_size_rounded,
                          size: 20,
                          color: context.secondaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Slider(
                            value: preferences.fontSize,
                            min: LyricsPersonalizationState.minFontSize,
                            max: LyricsPersonalizationState.maxFontSize,
                            label: preferences.fontSize.toStringAsFixed(0),
                            onChanged: (value) => ref
                                .read(lyricsPersonalizationProvider.notifier)
                                .setFontSize(value),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            preferences.fontSize.toStringAsFixed(0),
                            textAlign: TextAlign.end,
                            style: context.textBodySmall.copyWith(
                              color: context.secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final family in LyricsFontFamily.values)
                          _LyricsChoiceButton(
                            label: family.label,
                            icon: _iconForFontFamily(family),
                            selected: preferences.fontFamily == family,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              unawaited(
                                ref
                                    .read(
                                      lyricsPersonalizationProvider.notifier,
                                    )
                                    .setFontFamily(family),
                              );
                            },
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
      LyricsFontFamily.hei => Icons.format_bold_rounded,
      LyricsFontFamily.rounded => Icons.radio_button_unchecked_rounded,
      LyricsFontFamily.handwriting => Icons.gesture_rounded,
    };
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

class _LyricsChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LyricsChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? context.primaryColor : context.secondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? context.primaryColor.withValues(alpha: 0.12)
                : context.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? context.primaryColor.withValues(alpha: 0.42)
                  : context.primaryColor.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.textBodyMedium.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricsGlassDepthOverlay extends StatelessWidget {
  final double blurSigma;

  const _LyricsGlassDepthOverlay({required this.blurSigma});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark ? Colors.black : Colors.white;
    final sigma = blurSigma.clamp(0.0, 30.0).toDouble();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final bandHeight = (height * 0.34).clamp(120.0, 220.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _GlassFadeBand(
                  height: bandHeight,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  sigma: sigma,
                  tint: tint,
                  tintAlpha: isDark ? 0.22 : 0.18,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _GlassFadeBand(
                  height: bandHeight,
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  sigma: sigma <= 0.05
                      ? 0
                      : (sigma + 2).clamp(0.0, 30.0).toDouble(),
                  tint: tint,
                  tintAlpha: isDark ? 0.30 : 0.26,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassFadeBand extends StatelessWidget {
  final double height;
  final Alignment begin;
  final Alignment end;
  final double sigma;
  final Color tint;
  final double tintAlpha;

  const _GlassFadeBand({
    required this.height,
    required this.begin,
    required this.end,
    required this.sigma,
    required this.tint,
    required this.tintAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: begin,
              end: end,
              colors: const [Colors.white, Colors.transparent],
              stops: const [0.12, 1],
            ).createShader(bounds);
          },
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: [
                    tint.withValues(alpha: tintAlpha),
                    tint.withValues(alpha: 0),
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
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
