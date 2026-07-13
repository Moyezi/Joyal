import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../models/song.dart';
import '../../models/song_highlight.dart';
import '../../providers/glass_effect_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/song_highlight_provider.dart';
import '../../utils/app_toast.dart';
import '../album_visual_palette.dart';
import '../frosted_glass.dart';
import '../now_playing_transition.dart';
import '../play_queue_sheet.dart';
import '../song_actions_sheet.dart';
import '../waveform_progress.dart';
import 'now_playing_chrome.dart';

class NowPlayingPlayerContent extends ConsumerWidget {
  final Song song;
  final Song displaySong;
  final bool isSelecting;
  final bool isPlaying;
  final PlaybackMode playbackMode;
  final Animation<double> lyricsProgress;
  final bool positionUpdatesEnabled;
  final AlbumVisualPalette visualPalette;
  final Widget selectionCovers;
  final Widget normalCover;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const NowPlayingPlayerContent({
    super.key,
    required this.song,
    required this.displaySong,
    required this.isSelecting,
    required this.isPlaying,
    required this.playbackMode,
    required this.lyricsProgress,
    required this.positionUpdatesEnabled,
    required this.visualPalette,
    required this.selectionCovers,
    required this.normalCover,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final actionIconColor = theme.colorScheme.onSurface;
    final disabledActionIconColor = actionIconColor.withValues(alpha: 0.38);
    final playButtonBackground = context.surfaceColor;
    final playButtonForeground = theme.colorScheme.onSurface;
    final playButtonRadius = BorderRadius.circular(22);
    final playButtonShape = RoundedRectangleBorder(
      borderRadius: playButtonRadius,
    );
    final controlsBlur = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.nowPlayingControls),
      ),
    );
    final controlsTintOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(GlassEffectTarget.nowPlayingControls),
      ),
    );
    final isStarred = ref.watch(
      libraryProvider.select(
        (state) => state.starredSongs.any((item) => item.id == song.id),
      ),
    );

    return Column(
      children: [
        const SizedBox(height: AppTheme.spacingMD),

        // ── Album cover ──
        Expanded(
          flex: 5,
          child: LyricsContentFade(
            animation: lyricsProgress,
            child: Center(child: isSelecting ? selectionCovers : normalCover),
          ),
        ),

        NowPlayingControlsEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppTheme.spacingLG),

              // ── Song info ──
              LyricsContentFade(
                animation: lyricsProgress,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLG,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: isStarred ? '取消收藏' : '加入收藏',
                        icon: Icon(
                          isStarred
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                        style: IconButton.styleFrom(
                          foregroundColor: isStarred
                              ? context.favoriteRedColor
                              : actionIconColor,
                          disabledForegroundColor: disabledActionIconColor,
                        ),
                        onPressed: isSelecting
                            ? null
                            : () async {
                                try {
                                  await ref
                                      .read(libraryProvider.notifier)
                                      .setSongStarred(
                                        song,
                                        starred: !isStarred,
                                      );
                                  if (context.mounted) {
                                    showAppToast(
                                      context,
                                      isStarred ? '已取消收藏' : '已加入收藏',
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    showAppToast(context, '收藏失败：$error');
                                  }
                                }
                              },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              displaySong.title,
                              style: context.textHeadlineMedium,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppTheme.spacingXS),
                            Text(
                              displaySong.artist,
                              style: context.textTitleMedium.copyWith(
                                color: context.secondaryColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '更多操作',
                        icon: const Icon(Icons.more_horiz_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: actionIconColor,
                          disabledForegroundColor: disabledActionIconColor,
                        ),
                        onPressed: isSelecting
                            ? null
                            : () => SongActionsSheet.show(
                                context,
                                songTitle: song.title,
                                songArtist: song.artist,
                                isStarred: isStarred,
                                onPlayNext: () {
                                  ref
                                      .read(playerProvider.notifier)
                                      .playNext(song);
                                },
                                onToggleFavorite: () {
                                  ref
                                      .read(libraryProvider.notifier)
                                      .setSongStarred(
                                        song,
                                        starred: !isStarred,
                                      );
                                },
                                downloadService: ref.read(
                                  downloadServiceProvider,
                                ),
                                songId: song.id,
                                song: song,
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingLG),

              LyricsContentFade(
                animation: lyricsProgress,
                child: NowPlayingProgressSection(
                  isSelecting: isSelecting,
                  positionUpdatesEnabled: positionUpdatesEnabled,
                  trackKey: song.id,
                  playedColor: visualPalette.waveformAccentFor(brightness),
                  unplayedColor: visualPalette.waveformTrackFor(brightness),
                  onSeekFailed: () {
                    if (context.mounted) {
                      showAppToast(context, '跳转失败，已恢复原进度');
                    }
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // ── Playback controls ──
              Opacity(
                opacity: isSelecting ? 0.3 : 1.0,
                child: IgnorePointer(
                  ignoring: isSelecting,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: AnimatedBuilder(
                      animation: lyricsProgress,
                      builder: (context, child) {
                        final visibility = lyricsSurfaceVisibilityForProgress(
                          lyricsProgress.value,
                        );
                        return FrostedGlass(
                          blurSigma: controlsBlur * visibility,
                          borderRadius: BorderRadius.circular(34),
                          tintColor: theme.scaffoldBackgroundColor,
                          tintOpacity: controlsTintOpacity * visibility,
                          borderOpacity: 0,
                          liquidGlassIntensityScale: visibility,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(
                                alpha: (isDark ? 0.22 : 0.08) * visibility,
                              ),
                              blurRadius: 24 * visibility,
                              offset: Offset(0, 10 * visibility),
                            ),
                          ],
                          child: Opacity(opacity: visibility, child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Combined playback mode
                            IconButton(
                              tooltip: _playbackModeLabel(playbackMode),
                              icon: Icon(_playbackModeIcon(playbackMode)),
                              color: playbackMode == PlaybackMode.sequential
                                  ? actionIconColor
                                  : theme.colorScheme.onSurface,
                              onPressed: () async {
                                HapticFeedback.selectionClick();
                                final mode = await notifier.cyclePlaybackMode();
                                if (context.mounted) {
                                  showAppToast(
                                    context,
                                    _playbackModeLabel(mode),
                                    duration: const Duration(milliseconds: 900),
                                    replaceCurrent: true,
                                  );
                                }
                              },
                            ),

                            // Previous
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded),
                              color: actionIconColor,
                              iconSize: 34,
                              onPressed: () => onPrevious(),
                            ),

                            // Play / Pause (large CTA)
                            NowPlayingSharedHero(
                              tag: nowPlayingPlayButtonHeroTag,
                              crossFadeOnPop: true,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: playButtonBackground,
                                  borderRadius: playButtonRadius,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.shadow
                                          .withValues(
                                            alpha: isDark ? 0.20 : 0.10,
                                          ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  shape: playButtonShape,
                                  borderRadius: playButtonRadius,
                                  clipBehavior: Clip.antiAlias,
                                  child: IconButton(
                                    style: ButtonStyle(
                                      overlayColor:
                                          const WidgetStatePropertyAll(
                                            Color(0x52B6BDC7),
                                          ),
                                      shape: WidgetStatePropertyAll(
                                        playButtonShape,
                                      ),
                                    ),
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: playButtonForeground,
                                      size: 36,
                                    ),
                                    onPressed: () => notifier.togglePlayPause(),
                                  ),
                                ),
                              ),
                            ),

                            // Next
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded),
                              color: actionIconColor,
                              iconSize: 34,
                              onPressed: () => onNext(),
                            ),

                            // Queue
                            IconButton(
                              tooltip: '播放队列',
                              icon: const Icon(Icons.queue_music_rounded),
                              style: IconButton.styleFrom(
                                foregroundColor: actionIconColor,
                                disabledForegroundColor:
                                    disabledActionIconColor,
                              ),
                              onPressed: () => PlayQueueSheet.show(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingLG),
            ],
          ),
        ),
      ],
    );
  }

  IconData _playbackModeIcon(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequential => Icons.arrow_right_alt_rounded,
      PlaybackMode.shuffle => Icons.shuffle_rounded,
      PlaybackMode.repeatAll => Icons.repeat_rounded,
      PlaybackMode.repeatOne => Icons.repeat_one_rounded,
    };
  }

  String _playbackModeLabel(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequential => '顺序播放',
      PlaybackMode.shuffle => '随机播放',
      PlaybackMode.repeatAll => '列表循环',
      PlaybackMode.repeatOne => '单曲循环',
    };
  }
}

class NowPlayingProgressSection extends ConsumerWidget {
  final bool isSelecting;
  final bool positionUpdatesEnabled;
  final String trackKey;
  final Color playedColor;
  final Color unplayedColor;
  final VoidCallback onSeekFailed;

  const NowPlayingProgressSection({
    super.key,
    required this.isSelecting,
    required this.positionUpdatesEnabled,
    required this.trackKey,
    required this.playedColor,
    required this.unplayedColor,
    required this.onSeekFailed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(
      playerProvider.select((state) => state.currentSong),
    );
    final highlightSegments = currentSong == null
        ? const <SongHighlightSegment>[]
        : ref
                  .watch(cachedSongHighlightProvider(currentSong))
                  .asData
                  ?.value
                  ?.segments ??
              const <SongHighlightSegment>[];
    final progress = positionUpdatesEnabled
        ? ref.watch(
            playerProvider.select(
              (state) => (
                position: state.position,
                duration: state.duration ?? Duration.zero,
                isPlaying: state.isPlaying,
              ),
            ),
          )
        : (
            position: ref.read(playerProvider).position,
            duration: ref.read(playerProvider).duration ?? Duration.zero,
            isPlaying: false,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: isSelecting ? 0.3 : 1.0,
          child: IgnorePointer(
            ignoring: isSelecting,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
              ),
              child: WaveformProgress(
                position: progress.position,
                duration: progress.duration,
                trackKey: trackKey,
                isPlaying: progress.isPlaying,
                playedColor: playedColor,
                unplayedColor: unplayedColor,
                highlightSegments: highlightSegments,
                highlightColor: Color.lerp(
                  playedColor,
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF315D7A),
                  0.46,
                )!,
                onSeek: (position) async {
                  try {
                    await ref.read(playerProvider.notifier).seek(position);
                  } catch (_) {
                    onSeekFailed();
                    rethrow;
                  }
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatPlaybackDuration(progress.position),
                style: context.textCaption,
              ),
              Text(
                _formatPlaybackDuration(progress.duration),
                style: context.textCaption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatPlaybackDuration(Duration d) {
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
