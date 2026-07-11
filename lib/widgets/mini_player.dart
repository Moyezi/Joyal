import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/lyrics.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/lyrics_provider.dart';
import '../providers/mini_player_color_provider.dart';
import '../providers/player_provider.dart';
import 'cached_disk_image.dart';
import 'frosted_glass.dart';
import 'mini_player_chrome.dart';
import 'now_playing_transition.dart';

const double _miniLyricsHeight = 76;
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
const Duration _miniLyricsDefaultRollDuration = Duration(milliseconds: 520);
const Duration _miniLyricsMinRollDuration = Duration(milliseconds: 90);
const Duration _miniLyricsShortRollDuration = Duration(milliseconds: 160);
const Curve _miniLyricsRollPositionCurve = Cubic(0.16, 1.0, 0.3, 1.0);
const Curve _miniLyricsRollFadeOutCurve = Cubic(0.55, 0.0, 1.0, 0.45);
const Curve _miniLyricsRollFadeInCurve = Cubic(0.0, 0.55, 0.45, 1.0);

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
    final lyrics = _MiniLyricsForSong(song: song);

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

class _MiniLyricsForSong extends ConsumerWidget {
  final Song song;

  const _MiniLyricsForSong({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider(song));
    final pair = ref.watch(
      playerProvider.select(
        (state) => lyrics.when(
          loading: () => const _MiniLyricPair(
            current: '\u6b4c\u8bcd\u52a0\u8f7d\u4e2d',
            next: '',
            index: -2,
          ),
          error: (error, stackTrace) => const _MiniLyricPair(
            current: '\u6b4c\u8bcd\u52a0\u8f7d\u5931\u8d25',
            next: '',
            index: -3,
          ),
          data: (data) => _MiniLyricPair.fromLyrics(data, state.position),
        ),
      ),
    );
    return _MiniLyrics(songId: song.id, pair: pair);
  }
}

class _MiniLyrics extends StatefulWidget {
  final String songId;
  final _MiniLyricPair pair;

  const _MiniLyrics({required this.songId, required this.pair});

  @override
  State<_MiniLyrics> createState() => _MiniLyricsState();
}

class _MiniLyricsState extends State<_MiniLyrics>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  _MiniLyricPair? _previousPair;
  _MiniLyricPair? _displayPair;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: _miniLyricsDefaultRollDuration,
          )
          ..value = 1
          ..addStatusListener((status) {
            if (mounted &&
                status == AnimationStatus.completed &&
                _previousPair != null) {
              setState(() => _previousPair = null);
            }
          });
  }

  @override
  void didUpdateWidget(covariant _MiniLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPair = widget.pair;
    final currentPair = _displayPair;
    if (currentPair == null ||
        nextPair.index == currentPair.index ||
        nextPair.current == currentPair.current) {
      _displayPair = nextPair;
      _previousPair = null;
      _controller.value = 1;
      return;
    }

    _previousPair = currentPair;
    _displayPair = nextPair;
    _controller
      ..duration = _rollDurationFor(nextPair)
      ..value = 0
      ..forward();
  }

  Duration _rollDurationFor(_MiniLyricPair pair) {
    final currentStart = pair.currentStart;
    final nextStart = pair.nextStart;
    if (currentStart == null || nextStart == null) {
      return _miniLyricsDefaultRollDuration;
    }

    final availableMs = nextStart.inMilliseconds - currentStart.inMilliseconds;
    if (availableMs <= 0) return _miniLyricsDefaultRollDuration;
    if (availableMs <= _miniLyricsShortRollDuration.inMilliseconds) {
      final compressedMs = (availableMs - 24).clamp(
        _miniLyricsMinRollDuration.inMilliseconds,
        _miniLyricsShortRollDuration.inMilliseconds,
      );
      return Duration(milliseconds: compressedMs);
    }

    final adaptiveMs = (availableMs * 0.45).round().clamp(
      _miniLyricsShortRollDuration.inMilliseconds,
      _miniLyricsDefaultRollDuration.inMilliseconds,
    );
    return Duration(milliseconds: adaptiveMs);
  }

  @override
  Widget build(BuildContext context) {
    final pair = _displayPair = _displayPair ?? widget.pair;
    final previous = _previousPair;
    if (previous == null || _controller.value == 1) {
      return _MiniLyricsText(current: pair.current, next: pair.next);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _RollingMiniLyricsText(
          previousCurrent: previous.current,
          previousNext: previous.next,
          current: pair.current,
          next: pair.next,
          progress: _controller.value,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _MiniLyricPair {
  final String current;
  final String next;
  final int index;
  final Duration? currentStart;
  final Duration? nextStart;

  const _MiniLyricPair({
    required this.current,
    required this.next,
    required this.index,
    this.currentStart,
    this.nextStart,
  });

  factory _MiniLyricPair.fromLyrics(LyricsData data, Duration position) {
    final pair = lyricPairForPosition(data, position);
    if (!data.synced || pair.index < 0) {
      return _MiniLyricPair(
        current: pair.current,
        next: pair.next,
        index: pair.index,
      );
    }

    Duration? nextStart;
    for (var index = pair.index + 1; index < data.lines.length; index++) {
      final line = data.lines[index];
      if (line.text.trim().isNotEmpty) {
        nextStart = line.start;
        break;
      }
    }

    return _MiniLyricPair(
      current: pair.current,
      next: pair.next,
      index: pair.index,
      currentStart: data.lines[pair.index].start,
      nextStart: nextStart,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _MiniLyricPair &&
        other.current == current &&
        other.next == next &&
        other.index == index &&
        other.currentStart == currentStart &&
        other.nextStart == nextStart;
  }

  @override
  int get hashCode =>
      Object.hash(current, next, index, currentStart, nextStart);
}

class _MiniLyricsText extends StatelessWidget {
  final String current;
  final String next;

  const _MiniLyricsText({required this.current, required this.next});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayCurrent = _MiniLyricsLayout.balanceCurrentLine(
          current,
          constraints.maxWidth,
        );
        final layout = _MiniLyricsLayout.resolve(
          current: displayCurrent,
          next: next,
          maxWidth: constraints.maxWidth,
        );
        return ClipRect(
          child: SizedBox(
            height: _miniLyricsHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: layout.currentTop,
                  child: _CurrentLyricText(displayCurrent),
                ),
                if (next.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: layout.nextTop,
                    child: _NextLyricText(next),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RollingMiniLyricsText extends StatelessWidget {
  final String previousCurrent;
  final String previousNext;
  final String current;
  final String next;
  final double progress;

  const _RollingMiniLyricsText({
    required this.previousCurrent,
    required this.previousNext,
    required this.current,
    required this.next,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final promotedText = previousNext.isNotEmpty ? previousNext : current;
    final rollProgress = _miniLyricsRollPositionCurve.transform(progress);
    final fadeOutProgress = _miniLyricsRollFadeOutCurve.transform(progress);
    final fadeInProgress = _miniLyricsRollFadeInCurve.transform(progress);

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayPreviousCurrent = _MiniLyricsLayout.balanceCurrentLine(
          previousCurrent,
          constraints.maxWidth,
        );
        final displayPromotedText = _MiniLyricsLayout.balanceCurrentLine(
          promotedText,
          constraints.maxWidth,
        );
        final displayCurrent = _MiniLyricsLayout.balanceCurrentLine(
          current,
          constraints.maxWidth,
        );
        final previousLayout = _MiniLyricsLayout.resolve(
          current: displayPreviousCurrent,
          next: previousNext,
          maxWidth: constraints.maxWidth,
        );
        final promotedStartTop = _MiniLyricsLayout.resolvePromotedStartTop(
          current: displayPreviousCurrent,
          promoted: displayPromotedText,
          maxWidth: constraints.maxWidth,
        );
        final targetLayout = _MiniLyricsLayout.resolve(
          current: displayCurrent,
          next: next,
          maxWidth: constraints.maxWidth,
        );
        final oldCurrentTop = _lerp(
          previousLayout.currentTop,
          previousLayout.exitTop,
          rollProgress,
        );
        final promotedTop = _lerp(
          promotedStartTop,
          targetLayout.currentTop,
          rollProgress,
        );
        final nextTop = _lerp(
          targetLayout.enterTop,
          targetLayout.nextTop,
          rollProgress,
        );

        return ClipRect(
          child: SizedBox(
            height: _miniLyricsHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: oldCurrentTop,
                  child: Opacity(
                    opacity: (1 - fadeOutProgress).clamp(0, 1),
                    child: _CurrentLyricText(displayPreviousCurrent),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: promotedTop,
                  child: Opacity(
                    opacity: (0.62 + fadeInProgress * 0.38).clamp(0, 1),
                    child: _CurrentLyricText(displayPromotedText),
                  ),
                ),
                if (next.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: nextTop,
                    child: Opacity(
                      opacity: fadeInProgress.clamp(0, 1),
                      child: _NextLyricText(next),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
}

class _MiniLyricsLayout {
  final double currentTop;
  final double nextTop;
  final double exitTop;
  final double enterTop;

  const _MiniLyricsLayout({
    required this.currentTop,
    required this.nextTop,
    required this.exitTop,
    required this.enterTop,
  });

  static _MiniLyricsLayout resolve({
    required String current,
    required String next,
    required double maxWidth,
  }) {
    final safeWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 220.0;
    final currentHeight = _measureTextHeight(
      current,
      _CurrentLyricText.style,
      safeWidth,
      maxLines: 2,
      strutStyle: _CurrentLyricText.strutStyle,
    );

    if (next.isEmpty) {
      final currentTop = ((_miniLyricsHeight - currentHeight) / 2).clamp(
        0.0,
        _miniLyricsHeight,
      );
      return _MiniLyricsLayout(
        currentTop: currentTop,
        nextTop: _miniLyricsHeight,
        exitTop: -currentHeight - 8,
        enterTop: _miniLyricsHeight + 8,
      );
    }

    final nextHeight = _measureTextHeight(
      next,
      _NextLyricText.style,
      safeWidth,
      maxLines: 1,
      strutStyle: _NextLyricText.strutStyle,
    );
    final freeSpace = (_miniLyricsHeight - currentHeight - nextHeight).clamp(
      0.0,
      _miniLyricsHeight,
    );
    final topInset = freeSpace * 0.32;
    final currentTop = topInset.clamp(0.0, _miniLyricsHeight);
    final nextTop = (currentTop + currentHeight + freeSpace * 0.36).clamp(
      currentTop,
      _miniLyricsHeight - nextHeight,
    );

    return _MiniLyricsLayout(
      currentTop: currentTop,
      nextTop: nextTop,
      exitTop: -currentHeight - 8,
      enterTop: _miniLyricsHeight + 8,
    );
  }

  static String balanceCurrentLine(String text, double maxWidth) {
    final safeWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 220.0;
    if (text.contains('\n')) return text;

    final runes = text.runes.toList(growable: false);
    if (runes.length < 3) return text;

    if (!_exceedsOneLine(text, safeWidth)) return text;

    final prefixWithoutLast = String.fromCharCodes(
      runes.take(runes.length - 1),
    );
    if (_exceedsOneLine(prefixWithoutLast, safeWidth)) return text;

    final balancedPrefix = String.fromCharCodes(runes.take(runes.length - 2));
    final balancedTail = _preserveLeadingSpaces(
      String.fromCharCodes(runes.skip(runes.length - 2)),
    );
    return '$balancedPrefix\n$balancedTail';
  }

  static double resolvePromotedStartTop({
    required String current,
    required String promoted,
    required double maxWidth,
  }) {
    final safeWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 220.0;
    final currentHeight = _measureTextHeight(
      current,
      _CurrentLyricText.style,
      safeWidth,
      maxLines: 2,
      strutStyle: _CurrentLyricText.strutStyle,
    );
    final promotedHeight = _measureTextHeight(
      promoted,
      _CurrentLyricText.style,
      safeWidth,
      maxLines: 2,
      strutStyle: _CurrentLyricText.strutStyle,
    );
    final freeSpace = (_miniLyricsHeight - currentHeight - promotedHeight)
        .clamp(0.0, _miniLyricsHeight);
    final currentTop = (freeSpace * 0.32).clamp(0.0, _miniLyricsHeight);
    return (currentTop + currentHeight + freeSpace * 0.36).clamp(
      currentTop,
      _miniLyricsHeight - promotedHeight,
    );
  }

  static String _preserveLeadingSpaces(String text) {
    final firstNonSpace = text.indexOf(RegExp(r'[^ ]'));
    if (firstNonSpace == -1) return '\u00A0' * text.length;
    if (firstNonSpace <= 0) return text;
    return '${'\u00A0' * firstNonSpace}${text.substring(firstNonSpace)}';
  }

  static bool _exceedsOneLine(String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _CurrentLyricText.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '\u2026',
      strutStyle: _CurrentLyricText.strutStyle,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  static double _measureTextHeight(
    String text,
    TextStyle style,
    double maxWidth, {
    required int maxLines,
    StrutStyle? strutStyle,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '\u2026',
      strutStyle: strutStyle,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }
}

class _CurrentLyricText extends StatelessWidget {
  final String text;
  static const style = TextStyle(
    color: Colors.white,
    fontSize: 16,
    height: 1.18,
    fontWeight: FontWeight.w700,
  );
  static const strutStyle = StrutStyle(
    fontSize: 16,
    height: 1.18,
    forceStrutHeight: true,
  );

  const _CurrentLyricText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      strutStyle: strutStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _NextLyricText extends StatelessWidget {
  final String text;
  static const style = TextStyle(
    color: Colors.white60,
    fontSize: 12.5,
    height: 1.15,
    fontWeight: FontWeight.w500,
  );
  static const strutStyle = StrutStyle(
    fontSize: 12.5,
    height: 1.15,
    forceStrutHeight: true,
  );

  const _NextLyricText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      strutStyle: strutStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
