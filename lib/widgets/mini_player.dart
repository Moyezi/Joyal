import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/glass_effect_provider.dart';
import '../providers/mini_player_color_provider.dart';
import '../providers/player_provider.dart';
import 'cached_disk_image.dart';
import 'frosted_glass.dart';
import 'mini_player_chrome.dart';
import 'now_playing_transition.dart';
import 'mini_player/mini_player_lyrics.dart';

const double _miniPlayerHeight = 104;
const double _miniPlayerCapsuleHeight = 88;
const double _miniCoverSize = 72;
const double _collapsedCoverImageSize = 62;
const double _miniCoverLeftInset = 23;
const double _miniCoverExpandedLeftInset = _miniCoverLeftInset - 12;
const double _miniCoverLyricsGap = 12;
const double _miniLyricsHorizontalCalibration = -2;
const double _miniCoverRightInset = 18;
const double _miniPlayerHorizontalInset = 14;

class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onCollapseRequested;
  final VoidCallback? onExpandRequested;
  final bool isCollapsed;

  const MiniPlayer({
    super.key,
    this.onTap,
    this.onCollapseRequested,
    this.onExpandRequested,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((state) => state.currentSong));

    if (song == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = ref.watch(
      playerProvider.select((state) => state.isPlaying),
    );
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = (api != null && song.coverArt.isNotEmpty)
        ? api.getCoverArtUrl(song.coverArt)
        : '';
    final coverSourceId = api == null ? '' : '${api.baseUrl}|${api.username}';
    final colorMode = ref.watch(miniPlayerColorProvider);
    final brightness = Theme.of(context).brightness;
    final tintOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(GlassEffectTarget.miniPlayer),
      ),
    );
    final palette = colorMode == MiniPlayerColorMode.dynamicAlbum
        ? ref
              .watch(
                miniPlayerPaletteProvider(
                  MiniPlayerPaletteRequest(
                    coverArtId: song.coverArt,
                    coverSourceId: coverSourceId,
                    coverUrl: coverUrl,
                    brightness: brightness,
                  ),
                ),
              )
              .value
        : null;
    final chrome = MiniPlayerChrome.resolve(
      mode: colorMode,
      palette: palette,
      brightness: brightness,
    ).copyWith(tintOpacity: tintOpacity);

    final cover = _buildMiniCover(coverUrl, song.coverArt);
    final lyrics = MiniLyricsForSong(song: song);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isCollapsed ? 1 : 0),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, child) {
        return SizedBox(
          height: _miniPlayerHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return _MorphingMiniPlayer(
                availableWidth: width,
                progress: progress,
                isCollapsed: isCollapsed,
                trackId: song.id,
                isPlaying: isPlaying,
                cover: cover,
                lyrics: lyrics,
                chrome: chrome,
                onTap: onTap,
                onCollapseRequested: onCollapseRequested,
                onExpandRequested: onExpandRequested,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMiniCover(String url, String cacheKey) {
    if (url.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.1),
        child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
      );
    }

    return CachedDiskImage(
      imageUrl: url,
      cacheKey: cacheKey,
      fit: BoxFit.cover,
      decodeWidth: _miniPlayerHeight,
      placeholderBuilder: (context) => Container(
        color: Colors.white.withValues(alpha: 0.1),
        child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
      ),
      errorBuilder: (context, error) => Container(
        color: Colors.white.withValues(alpha: 0.1),
        child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
      ),
    );
  }
}

class _MorphingMiniPlayer extends ConsumerStatefulWidget {
  final double availableWidth;
  final double progress;
  final bool isCollapsed;
  final String trackId;
  final bool isPlaying;
  final Widget cover;
  final Widget lyrics;
  final MiniPlayerChrome chrome;
  final VoidCallback? onTap;
  final VoidCallback? onCollapseRequested;
  final VoidCallback? onExpandRequested;

  const _MorphingMiniPlayer({
    required this.availableWidth,
    required this.progress,
    required this.isCollapsed,
    required this.trackId,
    required this.isPlaying,
    required this.cover,
    required this.lyrics,
    required this.chrome,
    this.onTap,
    this.onCollapseRequested,
    this.onExpandRequested,
  });

  @override
  ConsumerState<_MorphingMiniPlayer> createState() =>
      _MorphingMiniPlayerState();
}

class _MorphingMiniPlayerState extends ConsumerState<_MorphingMiniPlayer> {
  static const double _collapseDragDistance = 42;
  static const double _collapseFlingVelocity = 320;
  double _dragDx = 0;

  void _handleHorizontalDragStart(DragStartDetails details) {
    _dragDx = 0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDx > _collapseDragDistance || velocity > _collapseFlingVelocity) {
      widget.onCollapseRequested?.call();
    }
    _dragDx = 0;
  }

  void _handleHorizontalDragCancel() {
    _dragDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    final blurSigma = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.miniPlayer),
      ),
    );
    final progress = widget.progress.clamp(0.0, 1.0);
    final expandedLeft = _miniPlayerHorizontalInset;
    const expandedTop = 8.0;
    final expandedWidth = math.max(
      _miniCoverSize,
      widget.availableWidth - _miniPlayerHorizontalInset * 2,
    );
    const expandedHeight = _miniPlayerCapsuleHeight;
    final collapsedLeft = math.max(
      _miniCoverLeftInset,
      widget.availableWidth - _miniCoverRightInset - _miniCoverSize,
    );
    final collapsedTop = (_miniPlayerHeight - _miniCoverSize) / 2;
    final left = _lerp(expandedLeft, collapsedLeft, progress);
    final top = _lerp(expandedTop, collapsedTop, progress);
    final width = _lerp(expandedWidth, _miniCoverSize, progress);
    final height = _lerp(expandedHeight, _miniCoverSize, progress);
    final radius = _lerp(44, _miniCoverSize / 2, progress);
    final imageSize = _lerp(_miniCoverSize, _collapsedCoverImageSize, progress);
    final expandedCoverTop = (expandedHeight - _miniCoverSize) / 2;
    final coverLeft = _lerp(
      _miniCoverExpandedLeftInset,
      (_miniCoverSize - imageSize) / 2,
      progress,
    );
    final coverTop = _lerp(
      expandedCoverTop,
      (_miniCoverSize - imageSize) / 2,
      progress,
    );
    final contentLeft =
        _miniCoverExpandedLeftInset +
        _miniCoverSize +
        _miniCoverLyricsGap -
        _miniLyricsHorizontalCalibration;
    final isSettledCollapsed = widget.isCollapsed && progress > 0.98;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: GestureDetector(
            onTap: isSettledCollapsed ? widget.onExpandRequested : widget.onTap,
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: isSettledCollapsed
                ? null
                : _handleHorizontalDragStart,
            onHorizontalDragUpdate: isSettledCollapsed
                ? null
                : _handleHorizontalDragUpdate,
            onHorizontalDragEnd: isSettledCollapsed
                ? null
                : _handleHorizontalDragEnd,
            onHorizontalDragCancel: isSettledCollapsed
                ? null
                : _handleHorizontalDragCancel,
            child: FrostedGlass(
              blurSigma: blurSigma,
              borderRadius: BorderRadius.circular(radius),
              tintColor: Color.lerp(
                widget.chrome.tintColor,
                widget.chrome.collapsedFrameColor,
                progress,
              )!,
              tintOpacity: widget.chrome.tintOpacity,
              borderColor: widget.chrome.borderColor,
              borderOpacity: widget.chrome.borderOpacity,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: Offset(0, _lerp(10, 8, progress)),
                ),
              ],
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: contentLeft,
                    top: 0,
                    width: math.max(0, expandedWidth - contentLeft),
                    height: expandedHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(
                              _miniLyricsHorizontalCalibration,
                              0,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: widget.lyrics,
                            ),
                          ),
                        ),
                        NowPlayingSharedHero(
                          tag: nowPlayingPlayButtonHeroTag,
                          crossFadeOnPop: true,
                          child: SizedBox(
                            width: 58,
                            height: 58,
                            child: IconButton(
                              onPressed: () {
                                ref
                                    .read(playerProvider.notifier)
                                    .togglePlayPause();
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor:
                                    widget.chrome.playButtonForeground,
                                minimumSize: const Size(58, 58),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(19),
                                ),
                              ),
                              icon: Icon(
                                widget.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  Positioned(
                    left: coverLeft,
                    top: coverTop,
                    child: Hero(
                      tag: nowPlayingCoverHeroTag,
                      createRectTween: (begin, end) =>
                          NowPlayingCoverRectTween(begin: begin, end: end),
                      child: RotatingNowPlayingCover(
                        trackId: widget.trackId,
                        isPlaying: widget.isPlaying,
                        child: ClipOval(
                          child: SizedBox(
                            width: imageSize,
                            height: imageSize,
                            child: widget.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
}
