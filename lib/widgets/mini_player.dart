import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/lyrics.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import 'cached_disk_image.dart';

const double _miniLyricsHeight = 76;
const Duration _miniLyricsDefaultRollDuration = Duration(milliseconds: 520);
const Duration _miniLyricsMinRollDuration = Duration(milliseconds: 90);
const Duration _miniLyricsShortRollDuration = Duration(milliseconds: 160);

class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;

  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);

    if (!playerState.hasSong) {
      return const SizedBox.shrink();
    }

    final song = playerState.currentSong!;
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = (api != null && song.coverArt.isNotEmpty)
        ? api.getCoverArtUrl(song.coverArt)
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 104,
        decoration: BoxDecoration(
          color: AppTheme.miniPlayerBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _RotatingCover(
                trackId: song.id,
                isPlaying: playerState.isPlaying,
                child: ClipOval(
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: _buildMiniCover(coverUrl, song.coverArt),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MiniLyrics(
                songId: song.id,
                lyrics: ref.watch(lyricsProvider(song)),
                position: playerState.position,
              ),
            ),
            IconButton(
              onPressed: () {
                ref.read(playerProvider.notifier).togglePlayPause();
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.miniPlayerBg,
                minimumSize: const Size(58, 58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              icon: Icon(
                playerState.isPlaying ? Icons.pause : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
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

class _MiniLyrics extends StatefulWidget {
  final String songId;
  final AsyncValue<LyricsData> lyrics;
  final Duration position;

  const _MiniLyrics({
    required this.songId,
    required this.lyrics,
    required this.position,
  });

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
    final nextPair = _resolvePair();
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

  _MiniLyricPair _resolvePair() {
    return widget.lyrics.when(
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
      data: (data) => _MiniLyricPair.fromLyrics(data, widget.position),
    );
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
    final pair = _displayPair = _displayPair ?? _resolvePair();
    final previous = _previousPair;
    if (previous == null || _controller.value == 1) {
      return _MiniLyricsText(current: pair.current, next: pair.next);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return _RollingMiniLyricsText(
          previousCurrent: previous.current,
          previousNext: previous.next,
          current: pair.current,
          next: pair.next,
          progress: t,
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
          progress,
        );
        final promotedTop = _lerp(
          promotedStartTop,
          targetLayout.currentTop,
          progress,
        );
        final nextTop = _lerp(
          targetLayout.enterTop,
          targetLayout.nextTop,
          progress,
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
                    opacity: (1 - progress).clamp(0, 1),
                    child: _CurrentLyricText(displayPreviousCurrent),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: promotedTop,
                  child: Opacity(
                    opacity: (0.62 + progress * 0.38).clamp(0, 1),
                    child: _CurrentLyricText(displayPromotedText),
                  ),
                ),
                if (next.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: nextTop,
                    child: Opacity(
                      opacity: progress.clamp(0, 1),
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

/// Keeps the record at its exact angle when playback is paused.
class _RotatingCover extends StatefulWidget {
  final String trackId;
  final bool isPlaying;
  final Widget child;

  const _RotatingCover({
    required this.trackId,
    required this.isPlaying,
    required this.child,
  });

  @override
  State<_RotatingCover> createState() => _RotatingCoverState();
}

class _RotatingCoverState extends State<_RotatingCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _RotatingCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackId != oldWidget.trackId) _controller.value = 0;
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
