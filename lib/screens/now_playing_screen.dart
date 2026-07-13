import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/album_visual_palette.dart';
import '../widgets/album_cover.dart';
import '../widgets/dynamic_album_background.dart';
import '../widgets/now_playing_transition.dart';
import '../widgets/now_playing/now_playing_chrome.dart';
import '../widgets/now_playing/now_playing_player_content.dart';
import 'lyrics_screen.dart';

@visibleForTesting
Song? nowPlayingVisualSong({
  required PlaybackState state,
  required bool isSelecting,
  required int candidateIndex,
}) {
  return _nowPlayingVisualSongFromParts(
    currentSong: state.currentSong,
    playlist: state.playlist,
    currentIndex: state.currentIndex,
    isSelecting: isSelecting,
    candidateIndex: candidateIndex,
  );
}

Song? _nowPlayingVisualSongFromParts({
  required Song? currentSong,
  required List<Song> playlist,
  required int currentIndex,
  required bool isSelecting,
  required int candidateIndex,
}) {
  if (!isSelecting || playlist.isEmpty) {
    return currentSong;
  }
  if (candidateIndex < 0 || candidateIndex >= playlist.length) {
    if (currentIndex >= 0 && currentIndex < playlist.length) {
      return playlist[currentIndex];
    }
    return currentSong;
  }
  return playlist[candidateIndex];
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

@visibleForTesting
double nowPlayingSurfaceVisibilityForLyricsProgress(double progress) {
  final normalized = progress.clamp(0.0, 1.0).toDouble();
  return 1 - Curves.easeOut.transform(normalized);
}

enum _CoverSlideDirection { previous, next }

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
  bool _lyricsForeground = false;
  bool _lyricsTransitionActive = false;
  bool _lyricsSettingsOpen = false;
  bool _allowRoutePop = false;
  bool _isSelecting = false;
  int _candidateIndex = 0;
  Song? _coverTransitionFrom;
  Song? _coverTransitionTo;
  _CoverSlideDirection _coverSlideDirection = _CoverSlideDirection.next;
  bool _coverTransitionPending = false;
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
  late final AnimationController _coverSlideCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final Animation<double> _coverSlideAnim = CurvedAnimation(
    parent: _coverSlideCtrl,
    curve: const Cubic(0.2, 0, 0, 1),
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
    _lyricsProgress.addStatusListener(_handleLyricsStatus);
    _selSnapCtrl.addListener(() {
      if (mounted && _selSnapCtrl.isAnimating) setState(() {});
    });
    _coverSlideCtrl.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() {
        _coverTransitionFrom = null;
        _coverTransitionTo = null;
      });
      _coverSlideCtrl.reset();
    });
  }

  @override
  void dispose() {
    _lyricsProgress.removeStatusListener(_handleLyricsStatus);
    _lyricsProgress.dispose();
    _selEnterCtrl.dispose();
    _coverSlideCtrl.dispose();
    _selSnapCtrl.dispose();
    super.dispose();
  }

  void _beginLyricsTransition({required bool initializeLyrics}) {
    if ((!initializeLyrics || _lyricsInitialized) && _lyricsTransitionActive) {
      return;
    }
    setState(() {
      if (initializeLyrics) _lyricsInitialized = true;
      _lyricsTransitionActive = true;
    });
  }

  void _showLyrics() {
    _beginLyricsTransition(initializeLyrics: true);
    _lyricsProgress.animateTo(1, curve: Curves.easeOutCubic);
  }

  void _hideLyrics() {
    if (_lyricsProgress.value <= 0) return;
    _beginLyricsTransition(initializeLyrics: false);
    _lyricsProgress.animateBack(0, curve: Curves.easeOutCubic);
  }

  void _handleLyricsStatus(AnimationStatus status) {
    if (!mounted ||
        (status != AnimationStatus.completed &&
            status != AnimationStatus.dismissed)) {
      return;
    }
    final foreground = _lyricsProgress.value >= 0.999;
    if (_lyricsForeground == foreground && !_lyricsTransitionActive) return;
    setState(() {
      _lyricsForeground = foreground;
      _lyricsTransitionActive = false;
    });
  }

  void _handleLyricsSettingsVisibility(bool visible) {
    if (!mounted || _lyricsSettingsOpen == visible) return;
    setState(() => _lyricsSettingsOpen = visible);
  }

  void _settleLyricsAfterDrag({
    required bool show,
    required double primaryVelocity,
    required double width,
  }) {
    if (show && !_lyricsInitialized) {
      _beginLyricsTransition(initializeLyrics: true);
    }
    final target = show ? 1.0 : 0.0;
    final remaining = (_lyricsProgress.value - target).abs();
    if (remaining <= 0.0001) {
      _handleLyricsStatus(
        show ? AnimationStatus.completed : AnimationStatus.dismissed,
      );
      return;
    }
    final progressVelocity = width > 0 ? (primaryVelocity / width).abs() : 0.0;
    final speed = progressVelocity.clamp(0.9, 8.0);
    final durationMs = (remaining / speed * 1000).clamp(120.0, 260.0).toInt();
    final duration = Duration(milliseconds: durationMs);
    if (show) {
      _lyricsProgress.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    } else {
      // Keep swipe-back on the same reverse path as the system back gesture.
      // animateTo(0) can complete with a forward/completed status, which used
      // to leave the hidden player page permanently paused.
      _lyricsProgress.animateBack(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
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
    if (_isDismissGestureDisabled) {
      _resetDismissPointer();
      return;
    }
    _dismissDragOffset = 0;
    _dismissPointerPosition = event.position;
    _dismissPointerTime = DateTime.now();
  }

  void _onDismissPointerMove(PointerMoveEvent event) {
    if (_isDismissGestureDisabled) {
      _resetDismissPointer();
      return;
    }
    _dismissDragOffset = (_dismissDragOffset + event.delta.dy).clamp(
      0.0,
      double.infinity,
    );
  }

  void _onDismissPointerUp(PointerUpEvent event) {
    if (_isDismissGestureDisabled) {
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

  bool get _isDismissGestureDisabled =>
      _isSelecting || _lyricsProgress.value > 0.01;

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
    final currentSong = ref.watch(
      playerProvider.select((state) => state.currentSong),
    );
    final playlist = ref.watch(
      playerProvider.select((state) => state.playlist),
    );
    final currentIndex = ref.watch(
      playerProvider.select((state) => state.currentIndex),
    );
    final hasSong = currentSong != null;
    final visualSong = _nowPlayingVisualSongFromParts(
      currentSong: currentSong,
      playlist: playlist,
      currentIndex: currentIndex,
      isSelecting: _isSelecting,
      candidateIndex: _candidateIndex,
    );
    _syncVisualPalette(visualSong);
    final playerPage = RepaintBoundary(child: _buildPlayerPage(context));
    final lyricsPage = _lyricsInitialized
        ? RepaintBoundary(
            child: LyricsScreen(
              onBack: _hideLyrics,
              stageVisible: _lyricsForeground,
              positionUpdatesEnabled: _lyricsForeground && !_lyricsSettingsOpen,
              onSettingsSheetVisibilityChanged: _handleLyricsSettingsVisibility,
            ),
          )
        : const SizedBox.expand();
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closePage();
      },
      child: NowPlayingEntrance(
        child: DynamicAlbumBackground(
          coverArtId: visualSong?.coverArt ?? '',
          coverUrl: _coverUrl(ref, visualSong),
          motionSeed: visualSong?.id,
          motionEnabled: !_lyricsSettingsOpen && !_lyricsTransitionActive,
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
                    : (_) => _beginLyricsTransition(initializeLyrics: true),
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
                onHorizontalDragCancel: (!hasSong || _isSelecting)
                    ? null
                    : () => _settleLyricsAfterDrag(
                        show: shouldShowLyricsAfterHorizontalDrag(
                          progress: _lyricsProgress.value,
                          primaryVelocity: 0,
                        ),
                        primaryVelocity: 0,
                        width: constraints.maxWidth,
                      ),
                child: AnimatedBuilder(
                  animation: _lyricsProgress,
                  builder: (context, _) {
                    final progress = Curves.easeOut.transform(
                      _lyricsProgress.value,
                    );
                    final width = constraints.maxWidth;
                    return Stack(
                      children: [
                        // Backdrop and liquid filters cannot sit under the
                        // page-wide animated opacity without resampling at
                        // gesture boundaries. Plain content fades locally;
                        // the control rail interpolates its own glass values.
                        TickerMode(
                          enabled: _lyricsProgress.value < 0.99,
                          child: Transform.translate(
                            offset: Offset(-width * 0.1 * progress, 0),
                            child: Transform.scale(
                              scale: 1 - 0.055 * progress,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  28 * progress,
                                ),
                                child: IgnorePointer(
                                  ignoring: _lyricsProgress.value > 0.01,
                                  child: playerPage,
                                ),
                              ),
                            ),
                          ),
                        ),
                        TickerMode(
                          enabled: _lyricsProgress.value > 0.01,
                          child: Transform.translate(
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
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPage(BuildContext context) {
    final song = ref.watch(playerProvider.select((state) => state.currentSong));
    final playlist = ref.watch(
      playerProvider.select((state) => state.playlist),
    );
    final currentIndex = ref.watch(
      playerProvider.select((state) => state.currentIndex),
    );
    final isPlaying = ref.watch(
      playerProvider.select((state) => state.isPlaying),
    );
    final playbackMode = ref.watch(
      playerProvider.select((state) => state.playbackMode),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: LyricsContentFade(
          animation: _lyricsProgress,
          child: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: Theme.of(context).colorScheme.onSurface,
            onPressed: _closePage,
          ),
        ),
        title: LyricsContentFade(
          animation: _lyricsProgress,
          child: const Text('Now Playing'),
        ),
        actions: [
          LyricsContentFade(
            animation: _lyricsProgress,
            child: IconButton(
              icon: const Icon(Icons.lyrics_rounded),
              color: Theme.of(context).colorScheme.onSurface,
              tooltip: '歌词',
              onPressed: song == null ? null : _showLyrics,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: song == null
            ? _emptyState()
            : NowPlayingPlayerContent(
                song: song,
                displaySong:
                    _nowPlayingVisualSongFromParts(
                      currentSong: song,
                      playlist: playlist,
                      currentIndex: currentIndex,
                      isSelecting: _isSelecting,
                      candidateIndex: _clampedCandidateIndex(
                        playlist,
                        currentIndex,
                      ),
                    ) ??
                    song,
                isSelecting: _isSelecting,
                isPlaying: isPlaying,
                playbackMode: playbackMode,
                lyricsProgress: _lyricsProgress,
                positionUpdatesEnabled:
                    !_lyricsForeground && !_lyricsSettingsOpen,
                visualPalette: _visualPalette,
                selectionCovers: _buildSelectionCovers(
                  ref,
                  playlist,
                  currentIndex,
                ),
                normalCover: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingXL,
                  ),
                  child: GestureDetector(
                    onLongPressStart: (_) =>
                        _enterSelectionMode(playlist, currentIndex),
                    child: _nowPlayingCover(song: song),
                  ),
                ),
                onPrevious: () =>
                    _slideToAdjacentTrack(_CoverSlideDirection.previous),
                onNext: () => _slideToAdjacentTrack(_CoverSlideDirection.next),
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

  int _clampedCandidateIndex(List<Song> playlist, int currentIndex) {
    if (playlist.isEmpty) return 0;
    final fallback = currentIndex.clamp(0, playlist.length - 1);
    if (_candidateIndex < 0 || _candidateIndex >= playlist.length) {
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

  void _enterSelectionMode(List<Song> playlist, int currentIndex) {
    if (playlist.length <= 1) return;
    HapticFeedback.heavyImpact();
    _coverSlideCtrl.stop();
    setState(() {
      _coverTransitionFrom = null;
      _coverTransitionTo = null;
      _coverTransitionPending = false;
      _isSelecting = true;
      _candidateIndex = currentIndex.clamp(0, playlist.length - 1);
      _selDragOffset = 0;
    });
    _selSnapCtrl.stop();
    _selEnterCtrl.forward(from: 0);
  }

  Widget _buildSelectionCovers(
    WidgetRef ref,
    List<Song> list,
    int currentIndex,
  ) {
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
            final candidateIndex = _clampedCandidateIndex(list, currentIndex);
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

  Future<void> _slideToAdjacentTrack(_CoverSlideDirection direction) async {
    if (_isSelecting) return;
    final playerState = ref.read(playerProvider);
    final fromSong = playerState.currentSong;
    if (fromSong == null) return;

    _coverSlideCtrl.stop();
    setState(() {
      _coverSlideDirection = direction;
      _coverTransitionFrom = fromSong;
      _coverTransitionTo = null;
      _coverTransitionPending = true;
    });

    final notifier = ref.read(playerProvider.notifier);
    try {
      if (direction == _CoverSlideDirection.next) {
        await notifier.next();
      } else {
        await notifier.previous();
      }
    } catch (_) {
      if (!mounted) rethrow;
      setState(() {
        _coverTransitionFrom = null;
        _coverTransitionTo = null;
        _coverTransitionPending = false;
      });
      showAppToast(context, '切换失败');
      return;
    }

    if (!mounted) return;
    final toSong = ref.read(playerProvider).currentSong;
    setState(() => _coverTransitionPending = false);
    if (toSong == null || toSong.id == fromSong.id) {
      setState(() {
        _coverTransitionFrom = null;
        _coverTransitionTo = null;
      });
      return;
    }

    setState(() {
      _coverTransitionFrom = fromSong;
      _coverTransitionTo = toSong;
      _coverSlideDirection = direction;
    });
    _coverSlideCtrl.forward(from: 0);
  }

  Widget _nowPlayingCover({required Song song}) {
    final lockedSong = _coverTransitionFrom;
    if (_coverTransitionPending && lockedSong != null) {
      return _coverForSong(lockedSong);
    }

    final incomingSong = _coverTransitionTo;
    if (lockedSong == null ||
        incomingSong == null ||
        !_coverSlideCtrl.isAnimating) {
      return Hero(
        tag: nowPlayingCoverHeroTag,
        createRectTween: (begin, end) =>
            NowPlayingCoverRectTween(begin: begin, end: end),
        flightShuttleBuilder:
            (context, animation, direction, fromContext, toContext) {
              final isPop = direction == HeroFlightDirection.pop;
              return AnimatedBuilder(
                animation: animation,
                child: _coverForSong(song, showShadow: false),
                builder: (context, child) {
                  final progress = animation.value.clamp(0.0, 1.0);
                  final alignProgress = isPop ? 1 - progress : progress;
                  final circleProgress = 1 - progress;
                  final miniTurns = RotatingNowPlayingCover.turnsFor(song.id);
                  final turns = isPop
                      ? miniTurns * alignProgress
                      : miniTurns * (1 - alignProgress);
                  return Transform.rotate(
                    angle: turns * 2 * 3.141592653589793,
                    child: HeroCoverShapeFrame(
                      circleProgress: circleProgress,
                      shadowOpacity: progress,
                      child: child!,
                    ),
                  );
                },
              );
            },
        child: _coverForSong(song),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = _coverSizeFor(context);
        final screenWidth = MediaQuery.sizeOf(context).width;
        final travel = (screenWidth + coverSize) / 2 + AppTheme.spacingLG;
        final sign = _coverSlideDirection == _CoverSlideDirection.next
            ? 1.0
            : -1.0;

        return AnimatedBuilder(
          animation: _coverSlideAnim,
          builder: (context, _) {
            final progress = _coverSlideAnim.value;
            return SizedBox(
              width: coverSize,
              height: coverSize,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(-sign * travel * progress, 0),
                    child: _coverForSong(lockedSong),
                  ),
                  Transform.translate(
                    offset: Offset(sign * travel * (1 - progress), 0),
                    child: _coverForSong(incomingSong),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _coverForSong(Song song, {bool showShadow = true}) {
    return AlbumCover(
      coverArtUrl: _coverUrl(ref, song),
      cacheKey: song.coverArt,
      size: _coverSizeFor(context),
      showShadow: showShadow,
    );
  }
}
