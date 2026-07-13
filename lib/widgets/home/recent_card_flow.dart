import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/theme_context.dart';
import '../../models/song.dart';
import '../cached_disk_image.dart';

class RecentCardFlow extends StatefulWidget {
  static const double fallbackHeight = 226;

  final List<Song> songs;
  final String Function(String coverArtId) coverUrlFor;
  final void Function(int index) onSongTap;

  const RecentCardFlow({
    super.key,
    required this.songs,
    required this.coverUrlFor,
    required this.onSongTap,
  });

  @override
  State<RecentCardFlow> createState() => RecentCardFlowState();
}

class RecentCardFlowState extends State<RecentCardFlow>
    with SingleTickerProviderStateMixin {
  static const double _snapVelocity = 420;

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;
  double _page = 0;
  double _pageMotion = 0;
  double _dragExtent = 220;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final animation = _snapAnimation;
          if (animation == null) return;
          _setPage(animation.value);
        });
  }

  @override
  void didUpdateWidget(covariant RecentCardFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songs.length <= 1) {
      _snapController.stop();
      _page = 0;
      _pageMotion = 0;
      return;
    }

    if (oldWidget.songs.isEmpty) return;
    final previousPage = _page.round();
    final previousSongIndex = _wrappedIndex(
      previousPage,
      oldWidget.songs.length,
    );
    final focusedSongId = oldWidget.songs[previousSongIndex].id;
    final newSongIndex = widget.songs.indexWhere(
      (song) => song.id == focusedSongId,
    );
    if (newSongIndex == -1 || newSongIndex == previousSongIndex) return;

    // Playing a song promotes it to the front of the recent-history source.
    // Keep that same song focused even though its list index has changed.
    _snapController.stop();
    final targetPage = previousPage - previousSongIndex + newSongIndex;
    _page += targetPage - previousPage;
    _pageMotion = 0;
  }

  int _wrappedIndex(int page, int length) {
    final index = page % length;
    return index < 0 ? index + length : index;
  }

  Song _songAtPage(int page) {
    return widget.songs[_wrappedIndex(page, widget.songs.length)];
  }

  void _handleDragStart(DragStartDetails details) {
    _snapController.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.songs.length <= 1) return;
    final primaryDelta = details.primaryDelta;
    if (primaryDelta == null) return;

    _setPage(_page - primaryDelta / _dragExtent);
  }

  void _setPage(double nextPage) {
    final motion = nextPage.compareTo(_page).toDouble();
    setState(() {
      _pageMotion = motion;
      _page = nextPage;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.songs.length <= 1) return;
    final velocity = details.primaryVelocity ?? 0;
    var target = _page.round();
    if (velocity < -_snapVelocity) {
      target = _page.floor() + 1;
    } else if (velocity > _snapVelocity) {
      target = _page.ceil() - 1;
    }
    _animateToPage(target.toDouble());
  }

  void _animateToPage(double targetPage) {
    if ((targetPage - _page).abs() < 0.001) {
      _setPage(targetPage);
      return;
    }

    _snapAnimation = Tween<double>(begin: _page, end: targetPage).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController.forward(from: 0);
  }

  void _handleCardTap(int page, int songIndex) {
    if ((page - _page).abs() < 0.16) {
      widget.onSongTap(songIndex);
      return;
    }
    _animateToPage(page.toDouble());
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : RecentCardFlow.fallbackHeight;
        final metrics = _RecentFlowMetrics.forSize(
          viewportWidth: viewportWidth,
          height: height,
        );
        _dragExtent = max(160.0, metrics.fullWidth + metrics.gap);

        final basePage = _page.floor();
        final startPage = basePage - 1;
        final endPage = basePage + 3;
        final visibleCards = <_PositionedRecentCard>[];
        for (var page = startPage; page <= endPage; page += 1) {
          final slot = _slotForOffset(
            page - _page,
            metrics,
            pageMotion: _pageMotion,
          );
          if (slot.opacity <= 0.01) continue;
          final songIndex = _wrappedIndex(page, widget.songs.length);
          visibleCards.add(
            _PositionedRecentCard(
              page: page,
              songIndex: songIndex,
              song: _songAtPage(page),
              slot: slot,
            ),
          );
        }
        visibleCards.sort(
          (a, b) => a.slot.focusAmount.compareTo(b.slot.focusAmount),
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: SizedBox.expand(
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final card in visibleCards)
                    Positioned(
                      key: ValueKey('recent-${card.page}-${card.song.id}'),
                      left: card.slot.x,
                      top: 0,
                      bottom: 0,
                      width: card.slot.width,
                      child: Opacity(
                        opacity: card.slot.opacity,
                        child: _RecentCard(
                          song: card.song,
                          coverUrl: widget.coverUrlFor(card.song.coverArt),
                          focusAmount: card.slot.focusAmount,
                          borderRadius: card.slot.radius,
                          onTap: () =>
                              _handleCardTap(card.page, card.songIndex),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _RecentFlowSlot _slotForOffset(
    double offset,
    _RecentFlowMetrics metrics, {
    required double pageMotion,
  }) {
    final focus = _RecentFlowSlot(
      x: 0,
      width: metrics.fullWidth,
      opacity: 1,
      radius: 20,
      focusAmount: 1,
    );
    final firstCapsule = _RecentFlowSlot(
      x: metrics.firstCapsuleX,
      width: metrics.firstCapsuleWidth,
      opacity: 1,
      radius: metrics.pillRadius,
      focusAmount: 0,
    );
    final secondCapsule = _RecentFlowSlot(
      x: metrics.secondCapsuleX,
      width: metrics.secondCapsuleWidth,
      opacity: 1,
      radius: metrics.pillRadius,
      focusAmount: 0,
    );
    final offRight = _RecentFlowSlot(
      x: metrics.viewportWidth + metrics.gap,
      width: metrics.secondCapsuleWidth,
      opacity: 0,
      radius: metrics.pillRadius,
      focusAmount: 0,
    );
    final offLeft = _RecentFlowSlot(
      x: -metrics.fullWidth - metrics.gap,
      width: metrics.fullWidth,
      opacity: 0,
      radius: 20,
      focusAmount: 0,
    );

    if (offset <= -1) return offLeft;
    if (offset <= 0) {
      return _RecentFlowSlot.lerp(offLeft, focus, offset + 1);
    }
    if (offset <= 1) {
      final slot = _RecentFlowSlot.lerp(focus, firstCapsule, offset);
      if (slot.focusAmount <= 0.001) return slot;
      final isShrinkingToCapsule = pageMotion < 0;
      return isShrinkingToCapsule ? slot : slot.copyWith(radius: focus.radius);
    }
    if (offset <= 2) {
      return _RecentFlowSlot.lerp(firstCapsule, secondCapsule, offset - 1);
    }
    if (offset <= 3) {
      return _RecentFlowSlot.lerp(secondCapsule, offRight, offset - 2);
    }
    return offRight;
  }
}

class _RecentFlowMetrics {
  final double viewportWidth;
  final double height;
  final double gap;
  final double fullWidth;
  final double firstCapsuleWidth;
  final double secondCapsuleWidth;

  const _RecentFlowMetrics({
    required this.viewportWidth,
    required this.height,
    required this.gap,
    required this.fullWidth,
    required this.firstCapsuleWidth,
    required this.secondCapsuleWidth,
  });

  factory _RecentFlowMetrics.forSize({
    required double viewportWidth,
    required double height,
  }) {
    const gap = 12.0;
    final fullWidth = min(height, viewportWidth * 0.62);
    final secondCapsuleWidth = min(48.0, max(30.0, viewportWidth * 0.11));
    final firstCapsuleWidth = min(
      96.0,
      max(36.0, viewportWidth - fullWidth - secondCapsuleWidth - gap * 2),
    );

    return _RecentFlowMetrics(
      viewportWidth: viewportWidth,
      height: height,
      gap: gap,
      fullWidth: fullWidth,
      firstCapsuleWidth: firstCapsuleWidth,
      secondCapsuleWidth: secondCapsuleWidth,
    );
  }

  double get firstCapsuleX => fullWidth + gap;
  double get secondCapsuleX => firstCapsuleX + firstCapsuleWidth + gap;
  double get pillRadius => height / 2;
}

class _RecentFlowSlot {
  final double x;
  final double width;
  final double opacity;
  final double radius;
  final double focusAmount;

  const _RecentFlowSlot({
    required this.x,
    required this.width,
    required this.opacity,
    required this.radius,
    required this.focusAmount,
  });

  _RecentFlowSlot copyWith({double? radius}) {
    return _RecentFlowSlot(
      x: x,
      width: width,
      opacity: opacity,
      radius: radius ?? this.radius,
      focusAmount: focusAmount,
    );
  }

  static _RecentFlowSlot lerp(_RecentFlowSlot a, _RecentFlowSlot b, double t) {
    final clampedT = t.clamp(0.0, 1.0).toDouble();
    return _RecentFlowSlot(
      x: _lerp(a.x, b.x, clampedT),
      width: _lerp(a.width, b.width, clampedT),
      opacity: _lerp(a.opacity, b.opacity, clampedT),
      radius: _lerp(a.radius, b.radius, clampedT),
      focusAmount: _lerp(a.focusAmount, b.focusAmount, clampedT),
    );
  }
}

class _PositionedRecentCard {
  final int page;
  final int songIndex;
  final Song song;
  final _RecentFlowSlot slot;

  const _PositionedRecentCard({
    required this.page,
    required this.songIndex,
    required this.song,
    required this.slot,
  });
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _RecentCard extends StatelessWidget {
  final Song song;
  final String coverUrl;
  final VoidCallback onTap;
  final double focusAmount;
  final double borderRadius;

  const _RecentCard({
    required this.song,
    required this.coverUrl,
    required this.onTap,
    required this.focusAmount,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final contentOpacity = Curves.easeOut.transform(
      focusAmount.clamp(0.0, 1.0).toDouble(),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _RecentCardImage(song: song, coverUrl: coverUrl),
            if (contentOpacity > 0.02)
              Opacity(
                opacity: contentOpacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x14000000),
                        Color(0xB8000000),
                      ],
                      stops: [0.42, 0.68, 1],
                    ),
                  ),
                ),
              ),
            if (contentOpacity > 0.04)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Opacity(
                  opacity: contentOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: context.textTitleMedium.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.16,
                          shadows: const [
                            Shadow(
                              blurRadius: 12,
                              color: Color(0xAA000000),
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _songSubtitle(song),
                        style: context.textBodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _songSubtitle(Song song) {
    if (song.artist.isEmpty) return song.album;
    if (song.album.isEmpty) return song.artist;
    return '${song.artist} · ${song.album}';
  }
}

class _RecentCardImage extends StatelessWidget {
  final Song song;
  final String coverUrl;

  const _RecentCardImage({required this.song, required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    if (coverUrl.isEmpty) return const _RecentCardPlaceholder();

    return CachedDiskImage(
      imageUrl: coverUrl,
      cacheKey: song.coverArt,
      fit: BoxFit.cover,
      decodeWidth: MediaQuery.sizeOf(context).width * 0.65,
      placeholderBuilder: (_) => const _RecentCardPlaceholder(),
      errorBuilder: (_, _) => const _RecentCardPlaceholder(),
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 120),
    );
  }
}

class _RecentCardPlaceholder extends StatelessWidget {
  const _RecentCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.surfaceHighlightColor, context.surfaceColor],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 52,
          color: context.secondaryColor.withValues(alpha: 0.54),
        ),
      ),
    );
  }
}
