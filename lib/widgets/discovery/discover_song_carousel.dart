import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_context.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../album_cover.dart';

class DiscoverSongCarousel extends ConsumerStatefulWidget {
  final List<Song> songs;
  final PageController controller;

  const DiscoverSongCarousel({
    super.key,
    required this.songs,
    required this.controller,
  });

  @override
  ConsumerState<DiscoverSongCarousel> createState() =>
      _DiscoverSongCarouselState();
}

class _DiscoverSongCarouselState extends ConsumerState<DiscoverSongCarousel> {
  int _currentIndex = 0;

  int _realIndexForPage(int page) {
    final length = widget.songs.length;
    if (length == 0) return 0;
    return (page % length + length) % length;
  }

  void _dragBy(double delta) {
    if (widget.songs.length <= 1 || !widget.controller.hasClients) return;
    final pixels = max(0.0, widget.controller.position.pixels - delta);
    widget.controller.jumpTo(pixels);
  }

  void _settleByVelocity(double velocity) {
    if (widget.songs.length <= 1 || !widget.controller.hasClients) return;
    final page =
        widget.controller.page ?? widget.controller.initialPage.toDouble();
    final speed = velocity.abs();
    final direction = velocity < 0
        ? 1
        : velocity > 0
        ? -1
        : 0;
    final pages = speed < 180 ? 0 : (speed / 1000).ceil().clamp(1, 3);
    if (pages > 0) {
      HapticFeedback.selectionClick();
    }
    widget.controller.animateToPage(
      page.round() + direction * pages,
      duration: Duration(milliseconds: 240 + pages * 28),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.songs;
    if (songs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final page = widget.controller.hasClients
                  ? widget.controller.page ?? _currentIndex.toDouble()
                  : _currentIndex.toDouble();
              final nearest = page.round();
              final offsets = <int>[-3, -2, -1, 0, 1, 2, 3]
                ..sort((a, b) => b.abs().compareTo(a.abs()));

              return LayoutBuilder(
                builder: (context, constraints) {
                  final centerSize = constraints.maxWidth * 0.65;
                  final viewportCenter = constraints.maxWidth / 2;
                  final cardCenterY = constraints.maxHeight * 0.49;

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) =>
                        _dragBy(details.delta.dx),
                    onHorizontalDragEnd: (details) =>
                        _settleByVelocity(details.primaryVelocity ?? 0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PageView.builder(
                          controller: widget.controller,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(
                              () => _currentIndex = _realIndexForPage(index),
                            );
                          },
                          itemBuilder: (_, _) => const SizedBox.expand(),
                        ),
                        for (final offset in offsets)
                          _DepthCarouselCard(
                            songs: songs,
                            pageIndex: nearest + offset,
                            relative: offset - (page - nearest),
                            centerSize: centerSize,
                            viewportCenter: viewportCenter,
                            cardCenterY: cardCenterY,
                            controller: widget.controller,
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _DiscoverDots(count: songs.length, currentIndex: _currentIndex),
        const SizedBox(height: 2),
      ],
    );
  }
}

class _DepthCarouselCard extends ConsumerWidget {
  final List<Song> songs;
  final int pageIndex;
  final double relative;
  final double centerSize;
  final double viewportCenter;
  final double cardCenterY;
  final PageController controller;

  const _DepthCarouselCard({
    required this.songs,
    required this.pageIndex,
    required this.relative,
    required this.centerSize,
    required this.viewportCenter,
    required this.cardCenterY,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final index = (pageIndex % songs.length + songs.length) % songs.length;

    final distance = relative.abs().clamp(0.0, 3.0);
    final scale = (1 - distance * 0.14).clamp(0.56, 1.0);
    final opacity = (1 - distance * 0.22).clamp(0.34, 1.0);
    final blur = distance == 0 ? 0.0 : distance * 0.7;
    final size = centerSize * scale;
    final x = viewportCenter - size / 2 + relative * centerSize * 0.37;
    final y = cardCenterY - size / 2 + distance * 10;
    final isCenter = distance < 0.5;
    final currentSong = songs[index];
    final coverCard = _DiscoverCoverCard(
      song: currentSong,
      isCenter: isCenter,
      size: size,
      onPlay: () => ref
          .read(playerProvider.notifier)
          .playPlaylist(songs, startIndex: index),
    );
    final filteredCard = blur > 0.05
        ? ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: coverCard,
          )
        : coverCard;
    final visualCard = opacity < 0.999
        ? Opacity(opacity: opacity, child: filteredCard)
        : filteredCard;

    return Positioned(
      left: x,
      top: y,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: isCenter
            ? null
            : () => controller.animateToPage(
                pageIndex,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
        child: visualCard,
      ),
    );
  }
}

class _DiscoverCoverCard extends ConsumerWidget {
  final Song song;
  final bool isCenter;
  final double size;
  final VoidCallback onPlay;

  const _DiscoverCoverCard({
    required this.song,
    required this.isCenter,
    required this.size,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsonicApiProvider);
    final playback = ref.watch(
      playerProvider.select(
        (state) =>
            (currentSongId: state.currentSong?.id, isPlaying: state.isPlaying),
      ),
    );
    final isCurrentSong = playback.currentSongId == song.id;
    final isPlaying = isCurrentSong && playback.isPlaying;
    final coverUrl = api == null || song.coverArt.isEmpty
        ? ''
        : api.getCoverArtUrl(song.coverArt);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isCenter ? 0.24 : 0.12),
            blurRadius: isCenter ? 34 : 20,
            offset: Offset(0, isCenter ? 18 : 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AlbumCover(
            coverArtUrl: coverUrl,
            cacheKey: song.coverArt,
            size: size,
            borderRadius: 24,
            showShadow: false,
          ),
          if (isCenter) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.58),
                    ],
                    stops: const [0, 0.46, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 78,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTitleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textBodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: IconButton.filled(
                tooltip: isPlaying ? '暂停' : '播放',
                onPressed: isCurrentSong
                    ? () => ref.read(playerProvider.notifier).togglePlayPause()
                    : onPlay,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: Colors.black87,
                  fixedSize: const Size(52, 52),
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(isPlaying),
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverDots extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _DiscoverDots({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == currentIndex ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? const Color(0xFF6F63FF)
                  : const Color(0xFFD7D8DF),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}
