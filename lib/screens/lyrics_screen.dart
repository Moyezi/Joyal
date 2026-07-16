import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_context.dart';
import '../models/lyrics.dart';
import '../models/song.dart';
import '../providers/lyrics_ai_palette_provider.dart';
import '../providers/lyrics_personalization_provider.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/lyrics/default_lyrics_view.dart';
import '../widgets/lyrics/lyrics_palette.dart';
import '../widgets/lyrics/lyrics_personalization_sheet.dart';
import '../widgets/lyrics_stage/flowing_light_lyrics_stage.dart';
import '../widgets/lyrics_stage/floating_name_lyrics_stage.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final bool stageVisible;
  final bool positionUpdatesEnabled;
  final ValueChanged<bool>? onSettingsSheetVisibilityChanged;

  const LyricsScreen({
    super.key,
    this.onBack,
    this.stageVisible = true,
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
    final coverSourceId = api == null ? '' : '${api.baseUrl}|${api.username}';
    final aiColorEnabled = ref.watch(
      lyricsPersonalizationProvider.select((state) => state.aiColorEnabled),
    );
    final dynamicLyricColor = song == null
        ? null
        : ref
              .watch(
                lyricsPaletteProvider(
                  LyricsPaletteRequest(
                    coverArtId: song.coverArt,
                    coverSourceId: coverSourceId,
                    coverUrl: coverUrl,
                    brightness: Brightness.dark,
                  ),
                ),
              )
              .maybeWhen(
                data: dynamicLyricColorFromPalette,
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
                    final aiPalette = !aiColorEnabled
                        ? null
                        : ref
                              .watch(
                                lyricsAiPaletteProvider(
                                  LyricsAiPaletteRequest(song, lyrics),
                                ),
                              )
                              .maybeWhen(
                                data: (palette) => palette,
                                orElse: () => null,
                              );
                    final aiKeywordColors = <String, Color>{
                      for (final keyword in aiPalette?.keywords ?? const [])
                        keyword.text: Color(keyword.color),
                    };
                    return _LyricsPositionedList(
                      data: lyrics,
                      song: song,
                      title: song.title,
                      artist: song.artist,
                      dynamicColor: dynamicLyricColor,
                      aiKeywordColors: aiKeywordColors,
                      stageVisible: widget.stageVisible,
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
  final Song song;
  final String title;
  final String artist;
  final Color? dynamicColor;
  final Map<String, Color> aiKeywordColors;
  final bool stageVisible;
  final bool positionUpdatesEnabled;
  final ValueChanged<bool>? onSettingsSheetVisibilityChanged;

  const _LyricsPositionedList({
    required this.data,
    required this.song,
    required this.title,
    required this.artist,
    this.dynamicColor,
    this.aiKeywordColors = const {},
    required this.stageVisible,
    required this.positionUpdatesEnabled,
    this.onSettingsSheetVisibilityChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = positionUpdatesEnabled
        ? ref.watch(
            playerProvider.select(
              (state) => activeLyricIndex(data, state.position),
            ),
          )
        : activeLyricIndex(data, ref.read(playerProvider).position);
    final stageMode = ref.watch(
      lyricsPersonalizationProvider.select((state) => state.stageMode),
    );
    if (stageMode == LyricsStageMode.flowingLight ||
        stageMode == LyricsStageMode.floatingName) {
      return _FlowingLightStageHost(
        data: data,
        song: song,
        activeIndex: activeIndex,
        stageMode: stageMode,
        title: title,
        artist: artist,
        dynamicColor: dynamicColor,
        aiKeywordColors: aiKeywordColors,
        stageVisible: stageVisible,
        positionUpdatesEnabled: positionUpdatesEnabled,
        onSettingsSheetVisibilityChanged: onSettingsSheetVisibilityChanged,
      );
    }
    return DefaultLyricsView(
      data: data,
      activeIndex: activeIndex,
      title: title,
      artist: artist,
      dynamicColor: dynamicColor,
      aiKeywordColors: aiKeywordColors,
      stageVisible: stageVisible,
      positionUpdatesEnabled: positionUpdatesEnabled,
      onSettingsSheetVisibilityChanged: onSettingsSheetVisibilityChanged,
      onSeek: (position) {
        unawaited(ref.read(playerProvider.notifier).seek(position));
      },
    );
  }
}

class _FlowingLightStageHost extends ConsumerStatefulWidget {
  final LyricsData data;
  final Song song;
  final int activeIndex;
  final LyricsStageMode stageMode;
  final String title;
  final String artist;
  final Color? dynamicColor;
  final Map<String, Color> aiKeywordColors;
  final bool stageVisible;
  final bool positionUpdatesEnabled;
  final ValueChanged<bool>? onSettingsSheetVisibilityChanged;

  const _FlowingLightStageHost({
    required this.data,
    required this.song,
    required this.activeIndex,
    required this.stageMode,
    required this.title,
    required this.artist,
    required this.dynamicColor,
    required this.aiKeywordColors,
    required this.stageVisible,
    required this.positionUpdatesEnabled,
    this.onSettingsSheetVisibilityChanged,
  });

  @override
  ConsumerState<_FlowingLightStageHost> createState() =>
      _FlowingLightStageHostState();
}

class _FlowingLightStageHostState
    extends ConsumerState<_FlowingLightStageHost> {
  bool _settingsSheetOpen = false;

  Future<void> _openSettings() async {
    if (_settingsSheetOpen || !mounted) return;
    setState(() => _settingsSheetOpen = true);
    HapticFeedback.mediumImpact();
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
        setState(() => _settingsSheetOpen = false);
      } else {
        _settingsSheetOpen = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(lyricsPersonalizationProvider);
    if (widget.stageMode == LyricsStageMode.floatingName) {
      return FloatingNameLyricsStage(
        data: widget.data,
        song: widget.song,
        activeIndex: widget.activeIndex,
        title: widget.title,
        artist: widget.artist,
        activeColor: resolvedActiveLyricColor(
          context,
          preferences,
          widget.dynamicColor,
        ),
        fontFamily: preferences.effectiveFontFamily,
        fontSize: preferences.floatingNameFontSize,
        effectColor: widget.dynamicColor,
        aiKeywordColors: widget.aiKeywordColors,
        wordByWordEnabled: preferences.wordByWordEnabled,
        stageVisible: widget.stageVisible,
        positionUpdatesEnabled:
            widget.positionUpdatesEnabled && !_settingsSheetOpen,
        onOpenSettings: () => unawaited(_openSettings()),
      );
    }
    return FlowingLightLyricsStage(
      data: widget.data,
      song: widget.song,
      activeIndex: widget.activeIndex,
      title: widget.title,
      artist: widget.artist,
      activeColor: resolvedActiveLyricColor(
        context,
        preferences,
        widget.dynamicColor,
      ),
      fontFamily: preferences.effectiveFontFamily,
      fontSize: preferences.flowingLightFontSize,
      effectColor: widget.dynamicColor,
      aiKeywordColors: widget.aiKeywordColors,
      wordByWordEnabled: preferences.wordByWordEnabled,
      stageVisible: widget.stageVisible,
      positionUpdatesEnabled:
          widget.positionUpdatesEnabled && !_settingsSheetOpen,
      onOpenSettings: () => unawaited(_openSettings()),
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
