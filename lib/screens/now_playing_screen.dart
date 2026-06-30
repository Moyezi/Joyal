import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/album_visual_palette.dart';
import '../widgets/album_cover.dart';
import '../widgets/dynamic_album_background.dart';
import '../widgets/play_queue_sheet.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/waveform_progress.dart';
import 'lyrics_screen.dart';

@visibleForTesting
Song? nowPlayingVisualSong({
  required PlaybackState state,
  required bool isSelecting,
  required int candidateIndex,
}) {
  if (!isSelecting || state.playlist.isEmpty) {
    return state.currentSong;
  }
  if (candidateIndex < 0 || candidateIndex >= state.playlist.length) {
    final currentIndex = state.currentIndex;
    if (currentIndex >= 0 && currentIndex < state.playlist.length) {
      return state.playlist[currentIndex];
    }
    return state.currentSong;
  }
  return state.playlist[candidateIndex];
}

@visibleForTesting
bool shouldShowLyricsAfterHorizontalDrag({
  required double progress,
  required double primaryVelocity,
}) {
  const flingVelocity = 500.0;
  const openThreshold = 0.28;

  if (primaryVelocity <= -flingVelocity) return true;
  if (primaryVelocity >= flingVelocity) return false;
  return progress >= openThreshold;
}

/// The immersive Now Playing detail screen.
///
/// Features:
/// - Large album cover with diffuse shadow
/// - Waveform progress bar (simulated)
/// - Full playback controls (shuffle, prev, play/pause, next, loop)
/// - Favorite and more options
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  AlbumVisualPalette _visualPalette = AlbumVisualPalette.fallback;
  String? _paletteCoverArtId;
  bool _lyricsInitialized = false;
  bool _allowRoutePop = false;
  bool _isSelecting = false;
  int _candidateIndex = 0;
  double _dismissDragOffset = 0;
  Offset? _dismissPointerPosition;
  DateTime? _dismissPointerTime;
  static const double _dismissDistanceThreshold = 96;
  static const double _dismissVelocityThreshold = 700;
  late final AnimationController _lyricsProgress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  // ━━ Selection mode animation state ━━━━━━━━━━━━━━━━━━━━
  late final AnimationController _selEnterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _selEnterAnim = CurvedAnimation(
    parent: _selEnterCtrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final AnimationController _selSnapCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  double _selDragOffset = 0;
  double _selSnapFrom = 0;
  double _selSnapTarget = 0;

  @override
  void initState() {
    super.initState();
    _selSnapCtrl.addListener(() {
      if (mounted && _selSnapCtrl.isAnimating) setState(() {});
    });
  }

  @override
  void dispose() {
    _lyricsProgress.dispose();
    _selEnterCtrl.dispose();
    _selSnapCtrl.dispose();
    super.dispose();
  }

  void _initializeLyrics() {
    if (_lyricsInitialized) return;
    setState(() => _lyricsInitialized = true);
  }

  void _showLyrics() {
    _initializeLyrics();
    _lyricsProgress.animateTo(1, curve: Curves.easeOutCubic);
  }

  void _hideLyrics() =>
      _lyricsProgress.animateBack(0, curve: Curves.easeOutCubic);

  void _settleLyricsAfterDrag({
    required bool show,
    required double primaryVelocity,
    required double width,
  }) {
    if (show) _initializeLyrics();
    final target = show ? 1.0 : 0.0;
    final remaining = (_lyricsProgress.value - target).abs();
    final progressVelocity = width > 0 ? (primaryVelocity / width).abs() : 0.0;
    final speed = progressVelocity.clamp(0.9, 8.0);
    final durationMs = (remaining / speed * 1000).clamp(120.0, 260.0).toInt();
    _lyricsProgress.animateTo(
      target,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
  }

  void _syncVisualPalette(Song? song) {
    final coverArtId = song?.coverArt ?? '';
    if (_paletteCoverArtId == coverArtId) return;
    _paletteCoverArtId = coverArtId;
    final brightness = Theme.of(context).brightness;
    _visualPalette = AlbumVisualPalette.fallbackFor(brightness);
    if (coverArtId.isEmpty) {
      return;
    }
    final coverUrl = _coverUrl(ref, song);
    AlbumVisualPalette.resolve(
      coverArtId: coverArtId,
      coverUrl: coverUrl,
      brightness: brightness,
    ).then((palette) {
      if (!mounted || _paletteCoverArtId != coverArtId) return;
      setState(() => _visualPalette = palette);
    });
  }

  void _closePage() {
    if (_lyricsProgress.value > 0) {
      _hideLyrics();
      return;
    }
    setState(() => _allowRoutePop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onDismissPointerDown(PointerDownEvent event) {
    _dismissDragOffset = 0;
    _dismissPointerPosition = event.position;
    _dismissPointerTime = DateTime.now();
  }

  void _onDismissPointerMove(PointerMoveEvent event) {
    if (_isSelecting) return;
    _dismissDragOffset = (_dismissDragOffset + event.delta.dy).clamp(
      0.0,
      double.infinity,
    );
  }

  void _onDismissPointerUp(PointerUpEvent event) {
    if (_isSelecting) {
      _resetDismissPointer();
      return;
    }
    final velocity = _dismissVelocity(event.position);
    final shouldDismiss =
        _dismissDragOffset >= _dismissDistanceThreshold ||
        velocity >= _dismissVelocityThreshold;
    _resetDismissPointer();
    if (shouldDismiss) _closePage();
  }

  void _onDismissPointerCancel(PointerCancelEvent event) {
    _resetDismissPointer();
  }

  double _dismissVelocity(Offset endPosition) {
    final startPosition = _dismissPointerPosition;
    final startTime = _dismissPointerTime;
    if (startPosition == null || startTime == null) return 0;
    final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsedMs <= 0) return 0;
    return (endPosition.dy - startPosition.dy) / elapsedMs * 1000;
  }

  void _resetDismissPointer() {
    _dismissDragOffset = 0;
    _dismissPointerPosition = null;
    _dismissPointerTime = null;
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final hasSong = playerState.hasSong;
    final visualSong = nowPlayingVisualSong(
      state: playerState,
      isSelecting: _isSelecting,
      candidateIndex: _candidateIndex,
    );
    _syncVisualPalette(visualSong);
    final playerPage = RepaintBoundary(child: _buildPlayerPage(context));
    final lyricsPage = _lyricsInitialized
        ? RepaintBoundary(child: LyricsScreen(onBack: _hideLyrics))
        : const SizedBox.expand();
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closePage();
      },
      child: DynamicAlbumBackground(
        coverArtId: visualSong?.coverArt ?? '',
        coverUrl: _coverUrl(ref, visualSong),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onDismissPointerDown,
          onPointerMove: _onDismissPointerMove,
          onPointerUp: _onDismissPointerUp,
          onPointerCancel: _onDismissPointerCancel,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (!hasSong || _isSelecting)
                  ? null
                  : (_) => _initializeLyrics(),
              onHorizontalDragUpdate: (!hasSong || _isSelecting)
                  ? null
                  : (details) {
                      _lyricsProgress.value =
                          (_lyricsProgress.value -
                                  details.delta.dx / constraints.maxWidth)
                              .clamp(0.0, 1.0);
                    },
              onHorizontalDragEnd: (!hasSong || _isSelecting)
                  ? null
                  : (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      _settleLyricsAfterDrag(
                        show: shouldShowLyricsAfterHorizontalDrag(
                          progress: _lyricsProgress.value,
                          primaryVelocity: velocity,
                        ),
                        primaryVelocity: velocity,
                        width: constraints.maxWidth,
                      );
                    },
              child: AnimatedBuilder(
                animation: _lyricsProgress,
                builder: (context, _) {
                  final progress = Curves.easeOut.transform(
                    _lyricsProgress.value,
                  );
                  final width = constraints.maxWidth;
                  return Stack(
                    children: [
                      Transform.translate(
                        offset: Offset(-width * 0.1 * progress, 0),
                        child: Transform.scale(
                          scale: 1 - 0.055 * progress,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28 * progress),
                            child: IgnorePointer(
                              ignoring: _lyricsProgress.value > 0.01,
                              child: playerPage,
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(width * (1 - progress), 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            28 * (1 - progress),
                          ),
                          child: IgnorePointer(
                            ignoring: _lyricsProgress.value < 0.99,
                            child: lyricsPage,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPage(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;
    final visualSong = nowPlayingVisualSong(
      state: playerState,
      isSelecting: _isSelecting,
      candidateIndex: _candidateIndex,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: _closePage,
        ),
        title: const Text('Now Playing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lyrics_outlined),
            tooltip: '歌词',
            onPressed: song == null ? null : _showLyrics,
          ),
        ],
      ),
      body: DynamicAlbumBackground(
        coverArtId: visualSong?.coverArt ?? '',
        coverUrl: _coverUrl(ref, visualSong),
        child: SafeArea(
          child: song == null
              ? _emptyState()
              : _playerContent(context, ref, playerState),
        ),
      ),
    );
  }

  String _coverUrl(WidgetRef ref, Song? song) {
    final api = ref.read(subsonicApiProvider);
    return api != null && song != null && song.coverArt.isNotEmpty
        ? api.getCoverArtUrl(song.coverArt)
        : '';
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 64,
            color: context.secondaryColor,
          ),
          SizedBox(height: AppTheme.spacingMD),
          Text('暂无播放曲目', style: context.textBodyMedium),
        ],
      ),
    );
  }

  // ━━ Selection mode helpers ━━━━━━━━━━━━━━━━━━━━━━━━━━━
  double _effectiveSelDragOffset() {
    if (_selSnapCtrl.isAnimating) {
      return _selSnapFrom +
          (_selSnapTarget - _selSnapFrom) *
              const Cubic(0.25, 1.55, 0.5, 1).transform(_selSnapCtrl.value);
    }
    return _selDragOffset;
  }

  double _coverSizeFor(BuildContext context) =>
      (MediaQuery.of(context).size.width - 68).clamp(240.0, 390.0);

  double get _selOriginalSize => _coverSizeFor(context);
  double get _selCenterSize => _selOriginalSize * 0.70;

  void _onSelDragUpdate(DragUpdateDetails details) {
    if (_selEnterCtrl.value < 0.9) return;
    _selSnapCtrl.stop();
    final dragLimit = _selCenterSize * 0.36;
    setState(() {
      _selDragOffset = (_selDragOffset + details.delta.dx).clamp(
        -dragLimit,
        dragLimit,
      );
    });
  }

  void _onSelDragEnd(DragEndDetails details) {
    if (_selEnterCtrl.value < 0.9) return;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = _selCenterSize * 0.30;
    if (velocity < -300 || _selDragOffset < -threshold) {
      _selSnapTo(_candidateIndex + 1);
    } else if (velocity > 300 || _selDragOffset > threshold) {
      _selSnapTo(_candidateIndex - 1);
    } else {
      _selAnimateDragOffset(0);
    }
  }

  void _selSnapTo(int target) {
    final list = ref.read(playerProvider).playlist;
    final clamped = target.clamp(0, list.length - 1);
    if (clamped == _candidateIndex) {
      _selAnimateDragOffset(0);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _candidateIndex = clamped;
      _selDragOffset = 0;
    });
    _selEnterCtrl.forward(from: 0.68);
  }

  void _selAnimateDragOffset(double target) {
    _selSnapFrom = _selDragOffset;
    _selSnapTarget = target;
    _selSnapCtrl
      ..reset()
      ..forward();
  }

  int _clampedCandidateIndex(PlaybackState state) {
    if (state.playlist.isEmpty) return 0;
    final fallback = state.currentIndex.clamp(0, state.playlist.length - 1);
    if (_candidateIndex < 0 || _candidateIndex >= state.playlist.length) {
      return fallback;
    }
    return _candidateIndex;
  }

  Future<void> _selConfirm(int index) async {
    if (_selEnterCtrl.value < 0.9) return;
    try {
      await ref.read(playerProvider.notifier).playAtIndex(index);
      await _exitSelectionMode();
    } catch (_) {
      if (mounted) {
        showAppToast(context, '切换失败');
      }
    }
  }

  Future<void> _exitSelectionMode() async {
    _selSnapCtrl.stop();
    _selDragOffset = 0;
    await _selEnterCtrl.reverse();
    if (!mounted) return;
    setState(() => _isSelecting = false);
  }

  void _selDismiss() {
    if (!_isSelecting) return;
    unawaited(_exitSelectionMode());
  }

  void _enterSelectionMode(PlaybackState ps) {
    if (ps.playlist.length <= 1) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelecting = true;
      _candidateIndex = ps.currentIndex.clamp(0, ps.playlist.length - 1);
      _selDragOffset = 0;
    });
    _selSnapCtrl.stop();
    _selEnterCtrl.forward(from: 0);
  }

  Widget _buildSelectionCovers(WidgetRef ref, PlaybackState ps) {
    final list = ps.playlist;
    if (list.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final originalSize = _coverSizeFor(context);
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final viewportHeight = constraints.maxHeight;

        return AnimatedBuilder(
          animation: Listenable.merge([_selEnterCtrl, _selSnapCtrl]),
          builder: (context, _) {
            final progress = _selEnterAnim.value.clamp(0.0, 1.0);
            final candidateIndex = _clampedCandidateIndex(ps);
            final current = list[candidateIndex];
            final previous = candidateIndex > 0
                ? list[candidateIndex - 1]
                : null;
            final next = candidateIndex + 1 < list.length
                ? list[candidateIndex + 1]
                : null;
            final rawDrag = _effectiveSelDragOffset();
            final centerDrag = rawDrag * 0.32;
            final sideDrag = rawDrag * 0.08;
            final centerSize = originalSize * (1 - 0.30 * progress);
            final sideSize = originalSize * (0.50 + 0.04 * (1 - progress));
            final sideOpacity = progress * 0.70;
            final sideDistance = viewportWidth * 0.50;
            final centerRect = Rect.fromCenter(
              center: Offset(
                viewportWidth / 2 + centerDrag,
                viewportHeight / 2,
              ),
              width: centerSize,
              height: centerSize,
            );

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (centerRect.contains(details.localPosition)) {
                  unawaited(_selConfirm(candidateIndex));
                } else {
                  _selDismiss();
                }
              },
              onHorizontalDragUpdate: _onSelDragUpdate,
              onHorizontalDragEnd: _onSelDragEnd,
              child: SizedBox(
                width: viewportWidth,
                height: viewportHeight,
                child: OverflowBox(
                  minWidth: viewportWidth,
                  maxWidth: viewportWidth,
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Center candidate – the original cover, scaled
                      if (previous != null)
                        _selectionCover(
                          song: previous,
                          size: sideSize,
                          opacity: sideOpacity,
                          offset: Offset(-sideDistance + sideDrag, 8),
                          dimmed: true,
                        ),
                      if (next != null)
                        _selectionCover(
                          song: next,
                          size: sideSize,
                          opacity: sideOpacity,
                          offset: Offset(sideDistance + sideDrag, 8),
                          dimmed: true,
                        ),
                      _selectionCover(
                        song: current,
                        size: centerSize,
                        opacity: 1,
                        offset: Offset(centerDrag, 0),
                        showShadow: true,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _selectionCover({
    required Song song,
    required double size,
    required double opacity,
    required Offset offset,
    bool showShadow = false,
    bool dimmed = false,
  }) {
    final cover = AlbumCover(
      coverArtUrl: _coverUrl(ref, song),
      cacheKey: song.coverArt,
      size: size,
      showShadow: showShadow,
    );

    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Transform.translate(
          offset: offset,
          child: Opacity(
            opacity: opacity,
            child: dimmed
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    child: ColoredBox(
                      color: Colors.black,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.18),
                          BlendMode.darken,
                        ),
                        child: cover,
                      ),
                    ),
                  )
                : cover,
          ),
        ),
      ),
    );
  }

  Widget _playerContent(
    BuildContext context,
    WidgetRef ref,
    PlaybackState playerState,
  ) {
    final song = playerState.currentSong!;
    final notifier = ref.read(playerProvider.notifier);
    final isStarred = ref.watch(
      libraryProvider.select(
        (state) => state.starredSongs.any((item) => item.id == song.id),
      ),
    );

    // Resolve cover art URL.
    final api = ref.read(subsonicApiProvider);
    final coverUrl = api != null && song.coverArt.isNotEmpty
        ? api.getCoverArtUrl(song.coverArt)
        : '';

    // In selection mode, show info for the candidate song instead of current.
    final displayCandidateIndex = _clampedCandidateIndex(playerState);
    final displaySong =
        nowPlayingVisualSong(
          state: playerState,
          isSelecting: _isSelecting,
          candidateIndex: displayCandidateIndex,
        ) ??
        song;

    return Column(
      children: [
        const SizedBox(height: AppTheme.spacingMD),

        // ── Album cover ──
        Expanded(
          flex: 5,
          child: Center(
            child: _isSelecting
                ? _buildSelectionCovers(ref, playerState)
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXL,
                    ),
                    child: GestureDetector(
                      onLongPressStart: (_) => _enterSelectionMode(playerState),
                      child: AlbumCover(
                        coverArtUrl: coverUrl,
                        cacheKey: song.coverArt,
                        size: _coverSizeFor(context),
                      ),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: AppTheme.spacingLG),

        // ── Song info ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          child: Row(
            children: [
              IconButton(
                tooltip: isStarred ? '取消收藏' : '加入收藏',
                icon: Icon(
                  isStarred ? Icons.favorite_rounded : Icons.favorite_border,
                ),
                color: isStarred
                    ? context.favoriteRedColor
                    : context.secondaryColor,
                onPressed: _isSelecting
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(libraryProvider.notifier)
                              .setSongStarred(song, starred: !isStarred);
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
                icon: const Icon(Icons.more_horiz),
                color: context.secondaryColor,
                onPressed: _isSelecting
                    ? null
                    : () => SongActionsSheet.show(
                        context,
                        songTitle: song.title,
                        songArtist: song.artist,
                        isStarred: isStarred,
                        onPlayNext: () {
                          ref.read(playerProvider.notifier).playNext(song);
                        },
                        onToggleFavorite: () {
                          ref
                              .read(libraryProvider.notifier)
                              .setSongStarred(song, starred: !isStarred);
                        },
                        downloadService: ref.read(downloadServiceProvider),
                        songId: song.id,
                        song: song,
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingLG),

        // ── Waveform progress ──
        Opacity(
          opacity: _isSelecting ? 0.3 : 1.0,
          child: IgnorePointer(
            ignoring: _isSelecting,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
              ),
              child: WaveformProgress(
                position: playerState.position,
                duration: playerState.duration ?? Duration.zero,
                trackKey: song.id,
                isPlaying: playerState.isPlaying,
                playedColor: _visualPalette.waveformAccent,
                unplayedColor: _visualPalette.waveformTrack,
                onSeek: (position) async {
                  try {
                    await notifier.seek(position);
                  } catch (error) {
                    if (context.mounted) {
                      showAppToast(context, '跳转失败，已恢复原进度');
                    }
                    rethrow;
                  }
                },
              ),
            ),
          ),
        ),

        // ── Time labels ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(playerState.position),
                style: context.textCaption,
              ),
              Text(
                _formatDuration(playerState.duration ?? Duration.zero),
                style: context.textCaption,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingMD),

        // ── Playback controls ──
        Opacity(
          opacity: _isSelecting ? 0.3 : 1.0,
          child: IgnorePointer(
            ignoring: _isSelecting,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLG,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Combined playback mode
                  IconButton(
                    tooltip: _playbackModeLabel(playerState.playbackMode),
                    icon: Icon(_playbackModeIcon(playerState.playbackMode)),
                    color: playerState.playbackMode == PlaybackMode.sequential
                        ? context.secondaryColor
                        : context.primaryColor,
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
                    icon: const Icon(Icons.skip_previous),
                    iconSize: 36,
                    onPressed: () => notifier.previous(),
                  ),

                  // Play / Pause (large CTA)
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? context.surfaceColor
                          : context.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? context.primaryColor
                            : Colors.white,
                        size: 40,
                      ),
                      onPressed: () => notifier.togglePlayPause(),
                    ),
                  ),

                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    iconSize: 36,
                    onPressed: () => notifier.next(),
                  ),

                  // Queue
                  IconButton(
                    tooltip: '播放队列',
                    icon: const Icon(Icons.queue_music_outlined),
                    color: context.secondaryColor,
                    onPressed: () => PlayQueueSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacingLG),
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
