import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/song.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/album_visual_palette.dart';
import '../widgets/album_cover.dart';
import '../widgets/dynamic_album_background.dart';
import '../widgets/frosted_glass.dart';
import '../widgets/now_playing_transition.dart';
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

enum _CoverSlideDirection { previous, next }

class _NowPlayingEntrance extends StatelessWidget {
  final Widget child;

  const _NowPlayingEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) return child;

    return AnimatedBuilder(
      animation: routeAnimation,
      builder: (context, _) {
        final rawProgress = routeAnimation.value.clamp(0.0, 1.0);
        final revealProgress = Curves.easeOutCubic.transform(rawProgress);
        final dimProgress = Curves.easeInCubic.transform(rawProgress);
        final dimAlpha = routeAnimation.status == AnimationStatus.reverse
            ? 0.0
            : 0.34 * (1 - dimProgress);

        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final revealHeight = height * revealProgress.clamp(0.001, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: revealHeight,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: height,
                        child: child,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: dimAlpha),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NowPlayingControlsEntrance extends StatelessWidget {
  final Widget child;

  const _NowPlayingControlsEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) return child;

    return AnimatedBuilder(
      animation: routeAnimation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutQuart.transform(
          routeAnimation.value.clamp(0.0, 1.0),
        );
        final height = MediaQuery.sizeOf(context).height;
        return Transform.translate(
          offset: Offset(0, height * 0.16 * (1 - progress)),
          child: child,
        );
      },
    );
  }
}

class _HeroCoverShapeFrame extends StatelessWidget {
  final double circleProgress;
  final double shadowOpacity;
  final Widget child;

  const _HeroCoverShapeFrame({
    required this.circleProgress,
    required this.shadowOpacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final circleRadius = width.isFinite && height.isFinite
            ? math.min(width, height) / 2
            : AppTheme.radiusLarge;
        final radius = _lerp(
          AppTheme.radiusLarge,
          circleRadius,
          Curves.easeInOutCubic.transform(circleProgress.clamp(0.0, 1.0)),
        );

        final borderRadius = BorderRadius.circular(radius);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: _diffuseShadowWithOpacity(shadowOpacity),
          ),
          child: ClipRRect(borderRadius: borderRadius, child: child),
        );
      },
    );
  }

  List<BoxShadow> _diffuseShadowWithOpacity(double opacity) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    if (clampedOpacity == 0) return const [];
    return AppTheme.diffuseShadow
        .map(
          (shadow) => shadow.copyWith(
            color: shadow.color.withValues(
              alpha: shadow.color.a * clampedOpacity,
            ),
          ),
        )
        .toList();
  }

  double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
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
    _lyricsProgress.dispose();
    _selEnterCtrl.dispose();
    _coverSlideCtrl.dispose();
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
        ? RepaintBoundary(child: LyricsScreen(onBack: _hideLyrics))
        : const SizedBox.expand();
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closePage();
      },
      child: _NowPlayingEntrance(
        child: DynamicAlbumBackground(
          coverArtId: visualSong?.coverArt ?? '',
          coverUrl: _coverUrl(ref, visualSong),
          motionSeed: visualSong?.id,
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
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          color: Theme.of(context).colorScheme.onSurface,
          onPressed: _closePage,
        ),
        title: const Text('Now Playing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lyrics_rounded),
            color: Theme.of(context).colorScheme.onSurface,
            tooltip: '歌词',
            onPressed: song == null ? null : _showLyrics,
          ),
        ],
      ),
      body: SafeArea(
        child: song == null
            ? _emptyState()
            : _playerContent(
                context,
                ref,
                song: song,
                playlist: playlist,
                currentIndex: currentIndex,
                isPlaying: isPlaying,
                playbackMode: playbackMode,
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
                    child: _HeroCoverShapeFrame(
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

  Widget _playerContent(
    BuildContext context,
    WidgetRef ref, {
    required Song song,
    required List<Song> playlist,
    required int currentIndex,
    required bool isPlaying,
    required PlaybackMode playbackMode,
  }) {
    final notifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final actionIconColor = theme.colorScheme.onSurface;
    final disabledActionIconColor = actionIconColor.withValues(alpha: 0.38);
    final playButtonBackground = context.surfaceColor;
    final playButtonForeground = theme.colorScheme.onSurface;
    final controlsBlur = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.bottomNav),
      ),
    );
    final controlsTintOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(GlassEffectTarget.bottomNav),
      ),
    );
    final isStarred = ref.watch(
      libraryProvider.select(
        (state) => state.starredSongs.any((item) => item.id == song.id),
      ),
    );

    // In selection mode, show info for the candidate song instead of current.
    final displayCandidateIndex = _clampedCandidateIndex(
      playlist,
      currentIndex,
    );
    final displaySong =
        _nowPlayingVisualSongFromParts(
          currentSong: song,
          playlist: playlist,
          currentIndex: currentIndex,
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
                ? _buildSelectionCovers(ref, playlist, currentIndex)
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXL,
                    ),
                    child: GestureDetector(
                      onLongPressStart: (_) =>
                          _enterSelectionMode(playlist, currentIndex),
                      child: _nowPlayingCover(song: song),
                    ),
                  ),
          ),
        ),

        _NowPlayingControlsEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppTheme.spacingLG),

              // ── Song info ──
              Padding(
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
                      icon: const Icon(Icons.more_horiz_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: actionIconColor,
                        disabledForegroundColor: disabledActionIconColor,
                      ),
                      onPressed: _isSelecting
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
                                    .setSongStarred(song, starred: !isStarred);
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

              const SizedBox(height: AppTheme.spacingLG),

              _NowPlayingProgressSection(
                isSelecting: _isSelecting,
                trackKey: song.id,
                playedColor: _visualPalette.waveformAccentFor(brightness),
                unplayedColor: _visualPalette.waveformTrackFor(brightness),
                onSeekFailed: () {
                  if (context.mounted) {
                    showAppToast(context, '跳转失败，已恢复原进度');
                  }
                },
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // ── Playback controls ──
              Opacity(
                opacity: _isSelecting ? 0.3 : 1.0,
                child: IgnorePointer(
                  ignoring: _isSelecting,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: FrostedGlass(
                      blurSigma: controlsBlur,
                      borderRadius: BorderRadius.circular(34),
                      tintColor: theme.scaffoldBackgroundColor,
                      tintOpacity: controlsTintOpacity,
                      borderOpacity: 0,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(
                            alpha: isDark ? 0.22 : 0.08,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
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
                              onPressed: () => _slideToAdjacentTrack(
                                _CoverSlideDirection.previous,
                              ),
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
                                  borderRadius: BorderRadius.circular(22),
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
                                child: IconButton(
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

                            // Next
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded),
                              color: actionIconColor,
                              iconSize: 34,
                              onPressed: () => _slideToAdjacentTrack(
                                _CoverSlideDirection.next,
                              ),
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

class _NowPlayingProgressSection extends ConsumerWidget {
  final bool isSelecting;
  final String trackKey;
  final Color playedColor;
  final Color unplayedColor;
  final VoidCallback onSeekFailed;

  const _NowPlayingProgressSection({
    required this.isSelecting,
    required this.trackKey,
    required this.playedColor,
    required this.unplayedColor,
    required this.onSeekFailed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      playerProvider.select(
        (state) => (
          position: state.position,
          duration: state.duration ?? Duration.zero,
          isPlaying: state.isPlaying,
        ),
      ),
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
