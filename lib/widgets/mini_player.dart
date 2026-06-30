import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/lyrics.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import 'cached_disk_image.dart';

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
  ({String current, String next, int index})? _previousPair;
  ({String current, String next, int index})? _displayPair;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..value = 1;
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
      ..value = 0
      ..forward();
  }

  ({String current, String next, int index}) _resolvePair() {
    return widget.lyrics.when(
      loading: () =>
          (current: '\u6b4c\u8bcd\u52a0\u8f7d\u4e2d', next: '', index: -2),
      error: (error, stackTrace) => (
        current: '\u6b4c\u8bcd\u52a0\u8f7d\u5931\u8d25',
        next: '',
        index: -3,
      ),
      data: (data) => lyricPairForPosition(data, widget.position),
    );
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

class _MiniLyricsText extends StatelessWidget {
  final String current;
  final String next;

  const _MiniLyricsText({required this.current, required this.next});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              current,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.18,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              next,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
                height: 1.15,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _RollingMiniLyricsText extends StatelessWidget {
  static const double _height = 76;
  static const double _currentTop = 11;
  static const double _nextTop = 57;
  static const double _exitTop = -36;
  static const double _enterTop = 78;

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
    final oldCurrentTop = _lerp(_currentTop, _exitTop, progress);
    final promotedTop = _lerp(_nextTop, _currentTop, progress);
    final nextTop = _lerp(_enterTop, _nextTop, progress);
    final promotedText = previousNext.isNotEmpty ? previousNext : current;

    return ClipRect(
      child: SizedBox(
        height: _height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: oldCurrentTop,
              child: Opacity(
                opacity: (1 - progress).clamp(0, 1),
                child: _CurrentLyricText(previousCurrent),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: promotedTop,
              child: Opacity(
                opacity: (0.62 + progress * 0.38).clamp(0, 1),
                child: _CurrentLyricText(promotedText),
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
  }

  double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
}

class _CurrentLyricText extends StatelessWidget {
  final String text;

  const _CurrentLyricText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.18,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _NextLyricText extends StatelessWidget {
  final String text;

  const _NextLyricText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 12.5,
        height: 1.15,
        fontWeight: FontWeight.w500,
      ),
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
