import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/sidebar_image_provider.dart';
import '../widgets/cached_disk_image.dart';
import '../widgets/home_sidebar.dart';

class LibraryCanvasScreen extends ConsumerStatefulWidget {
  const LibraryCanvasScreen({super.key});

  @override
  ConsumerState<LibraryCanvasScreen> createState() =>
      _LibraryCanvasScreenState();
}

class _LibraryCanvasScreenState extends ConsumerState<LibraryCanvasScreen>
    with SingleTickerProviderStateMixin {
  static const double _horizontalStep = 248;
  static const double _verticalStep = 232;
  static const double _viewportInset = 0;

  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;
  Offset _canvasOffset = Offset.zero;
  Size _lastViewport = Size.zero;
  List<_AxialCell> _cells = const [];
  Map<int, int> _indexByCell = const {};
  int _songCount = -1;
  bool _hasInitialFocus = false;
  int? _lastDragFocusIndex;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 520),
        )..addListener(() {
          final animation = _snapAnimation;
          if (animation != null && mounted) {
            setState(() => _canvasOffset = animation.value);
          }
        });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _ensureIndex(List<Song> songs) {
    if (_songCount == songs.length) return;
    _songCount = songs.length;
    _cells = _buildSpiral(songs.length);
    _indexByCell = {
      for (var i = 0; i < _cells.length; i++)
        _cellKey(_cells[i].q, _cells[i].r): i,
    };
    _hasInitialFocus = false;
  }

  void _initializeFocus(List<Song> songs, Song? currentSong) {
    if (_hasInitialFocus || songs.isEmpty || _lastViewport.isEmpty) return;
    final currentIndex = currentSong == null
        ? -1
        : songs.indexWhere((song) => song.id == currentSong.id);
    final index = currentIndex < 0 ? 0 : currentIndex;
    _canvasOffset = -_worldPosition(index);
    _hasInitialFocus = true;
  }

  Offset _worldPosition(int index) {
    final cell = _cells[index];
    final jitter = _jitterFor(index);
    return Offset(
      _horizontalStep * (cell.q + cell.r * 0.5) + jitter.dx,
      _verticalStep * cell.r + jitter.dy,
    );
  }

  void _animateToIndex(int index) {
    if (index < 0 || index >= _cells.length) return;
    _snapController.stop();
    _snapAnimation =
        Tween<Offset>(
          begin: _canvasOffset,
          end: -_worldPosition(index),
        ).animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
        );
    _snapController.forward(from: 0);
  }

  int? _nearestVisibleIndex(Size size) {
    final visible = _visibleIndices(size, overscan: 260);
    final candidates = visible.isEmpty
        ? List<int>.generate(_cells.length, (index) => index)
        : visible;
    if (candidates.isEmpty) return null;
    var closest = candidates.first;
    var closestDistance =
        (_worldPosition(closest) + _canvasOffset).distanceSquared;
    for (final index in candidates.skip(1)) {
      final distance = (_worldPosition(index) + _canvasOffset).distanceSquared;
      if (distance < closestDistance) {
        closest = index;
        closestDistance = distance;
      }
    }
    return closest;
  }

  List<int> _visibleIndices(Size size, {double overscan = 180}) {
    if (_cells.isEmpty) return const [];
    final halfWidth = size.width / 2 + overscan;
    final halfHeight = size.height / 2 + overscan;
    final minR = ((-halfHeight - _canvasOffset.dy) / _verticalStep).floor() - 1;
    final maxR = ((halfHeight - _canvasOffset.dy) / _verticalStep).ceil() + 1;
    final result = <int>[];
    for (var r = minR; r <= maxR; r++) {
      final rowShift = _horizontalStep * r * 0.5;
      final minQ =
          ((-halfWidth - _canvasOffset.dx - rowShift) / _horizontalStep)
              .floor() -
          1;
      final maxQ =
          ((halfWidth - _canvasOffset.dx - rowShift) / _horizontalStep).ceil() +
          1;
      for (var q = minQ; q <= maxQ; q++) {
        final index = _indexByCell[_cellKey(q, r)];
        if (index != null) result.add(index);
      }
    }
    return result;
  }

  Future<void> _playSong(List<Song> songs, int index) async {
    final playback = ref.read(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    if (playback.currentSong?.id == songs[index].id) {
      await notifier.togglePlayPause();
    } else {
      await notifier.playPlaylist(songs, startIndex: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(libraryProvider.select((state) => state.songs));
    final currentSong = ref.watch(
      playerProvider.select((state) => state.currentSong),
    );
    final sidebarImage = ref.watch(sidebarImageProvider);
    _ensureIndex(songs);

    return Scaffold(
      backgroundColor: const Color(0xFF121416),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_viewportInset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              _lastViewport = size;
              _initializeFocus(songs, currentSong);
              final focusedIndex = _nearestVisibleIndex(size);
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) {
                        _snapController.stop();
                        _lastDragFocusIndex = _nearestVisibleIndex(size);
                        HapticFeedback.lightImpact();
                      },
                      onPanUpdate: (details) {
                        setState(() => _canvasOffset += details.delta);
                        final nearest = _nearestVisibleIndex(size);
                        if (nearest != null && nearest != _lastDragFocusIndex) {
                          _lastDragFocusIndex = nearest;
                          HapticFeedback.selectionClick();
                        }
                      },
                      onPanEnd: (_) {
                        final nearest = _nearestVisibleIndex(size);
                        _lastDragFocusIndex = null;
                        if (nearest != null) _animateToIndex(nearest);
                      },
                      onPanCancel: () => _lastDragFocusIndex = null,
                      child: ColoredBox(
                        color: const Color(0xFF121416),
                        child: songs.isEmpty
                            ? const _EmptyCanvas()
                            : _CanvasCards(
                                songs: songs,
                                indices: _visibleIndices(size),
                                focusedIndex: focusedIndex,
                                canvasOffset: _canvasOffset,
                                viewportSize: size,
                                worldPosition: _worldPosition,
                                onFocus: _animateToIndex,
                                onPlay: (index) => _playSong(songs, index),
                                onPlayNext: (index) => ref
                                    .read(playerProvider.notifier)
                                    .playNext(songs[index]),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    top: 12,
                    child: _CanvasHeader(
                      imagePath: sidebarImage.imagePath,
                      alignment: Alignment(
                        sidebarImage.alignmentX,
                        sidebarImage.alignmentY,
                      ),
                      songCount: songs.length,
                      onBack: () => Navigator.maybePop(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CanvasCards extends StatelessWidget {
  final List<Song> songs;
  final List<int> indices;
  final int? focusedIndex;
  final Offset canvasOffset;
  final Size viewportSize;
  final Offset Function(int index) worldPosition;
  final ValueChanged<int> onFocus;
  final ValueChanged<int> onPlay;
  final ValueChanged<int> onPlayNext;

  const _CanvasCards({
    required this.songs,
    required this.indices,
    required this.focusedIndex,
    required this.canvasOffset,
    required this.viewportSize,
    required this.worldPosition,
    required this.onFocus,
    required this.onPlay,
    required this.onPlayNext,
  });

  @override
  Widget build(BuildContext context) {
    final center = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final maxDistance =
        math.min(viewportSize.width, viewportSize.height) * 0.68;
    final ordered = [...indices]
      ..sort((a, b) {
        final da = (worldPosition(a) + canvasOffset).distanceSquared;
        final db = (worldPosition(b) + canvasOffset).distanceSquared;
        return db.compareTo(da);
      });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final index in ordered)
          _positionedCard(index, center, maxDistance),
      ],
    );
  }

  Widget _positionedCard(int index, Offset center, double maxDistance) {
    final relative = worldPosition(index) + canvasOffset;
    final distance = relative.distance;
    final focus = (1 - distance / maxDistance).clamp(0.0, 1.0);
    final isFocused = index == focusedIndex;
    final width = 86 + 138 * focus;
    final opacity = (0.16 + focus * 0.84).clamp(0.0, 1.0);
    return Positioned(
      key: ValueKey('library-canvas-${songs[index].id}'),
      left: center.dx + relative.dx - width / 2,
      top: center.dy + relative.dy - width * 0.66,
      width: width,
      child: Opacity(
        opacity: opacity,
        child: _SongCanvasCard(
          song: songs[index],
          isFocused: isFocused,
          prominence: focus,
          blurSigma: (1 - focus) * 2.8,
          onTap: () => onFocus(index),
          onPlay: () => onPlay(index),
          onPlayNext: () => onPlayNext(index),
        ),
      ),
    );
  }
}

class _SongCanvasCard extends ConsumerWidget {
  final Song song;
  final bool isFocused;
  final double prominence;
  final double blurSigma;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onPlayNext;

  const _SongCanvasCard({
    required this.song,
    required this.isFocused,
    required this.prominence,
    required this.blurSigma,
    required this.onTap,
    required this.onPlay,
    required this.onPlayNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = api == null || song.coverArt.isEmpty
        ? ''
        : api.getCoverArtUrl(song.coverArt);
    final centerReveal = ((prominence - 0.72) / 0.28).clamp(0.0, 1.0);
    final padding = 6 + 4 * prominence;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12 + 6 * prominence),
      child: CachedDiskImage(
        imageUrl: coverUrl,
        cacheKey: song.coverArt,
        decodeWidth: 224,
        placeholderBuilder: (_) => const ColoredBox(
          color: Color(0xFF282B2E),
          child: Center(
            child: Icon(Icons.music_note_rounded, color: Colors.white30),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${song.title}，${song.artist}',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: const Color(
                0xFF202326,
              ).withValues(alpha: 0.96 * centerReveal),
              borderRadius: BorderRadius.circular(16 + 6 * prominence),
              boxShadow: centerReveal <= 0
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(
                          0x66000000,
                        ).withValues(alpha: 0.4 * centerReveal),
                        blurRadius: 34 * centerReveal,
                        offset: Offset(0, 16 * centerReveal),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ImageFiltered(
                    enabled: blurSigma >= 0.2,
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: image,
                  ),
                ),
                SizedBox(height: 7 + 5 * prominence),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11 + 6 * prominence,
                    fontWeight: prominence > 0.72
                        ? FontWeight.w700
                        : FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        song.artist.isEmpty ? '未知艺术家' : song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9 + 3 * prominence,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !isFocused,
                      child: Opacity(
                        opacity: centerReveal,
                        child: _CardAction(
                          icon: Icons.play_arrow_rounded,
                          tooltip: '播放',
                          onTap: onPlay,
                        ),
                      ),
                    ),
                    _CardAction(
                      icon: Icons.playlist_play_rounded,
                      tooltip: '下一首播放',
                      onTap: onPlayNext,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _CanvasHeader extends StatelessWidget {
  final String? imagePath;
  final Alignment alignment;
  final int songCount;
  final VoidCallback onBack;

  const _CanvasHeader({
    required this.imagePath,
    required this.alignment,
    required this.songCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: '返回',
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xCC24272A),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: const Color(0xD924272A),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage)
                Hero(
                  tag: libraryCanvasHeroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath!),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      alignment: alignment,
                    ),
                  ),
                ),
              if (hasImage) const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '曲库',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$songCount 首歌曲',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '曲库同步后，歌曲会散落在这里',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }
}

List<_AxialCell> _buildSpiral(int count) {
  if (count <= 0) return const [];
  final result = <_AxialCell>[const _AxialCell(0, 0)];
  for (var radius = 1; result.length < count; radius++) {
    final ring = _buildRing(radius);
    final remaining = count - result.length;
    if (remaining >= ring.length) {
      result.addAll(ring);
      continue;
    }
    for (var index = 0; index < remaining; index++) {
      final ringIndex = (index * ring.length / remaining).floor();
      result.add(ring[ringIndex]);
    }
  }
  return result;
}

List<_AxialCell> _buildRing(int radius) {
  const directions = [
    _AxialCell(1, 0),
    _AxialCell(1, -1),
    _AxialCell(0, -1),
    _AxialCell(-1, 0),
    _AxialCell(-1, 1),
    _AxialCell(0, 1),
  ];
  final ring = <_AxialCell>[];
  var q = -radius;
  var r = radius;
  for (final direction in directions) {
    for (var step = 0; step < radius; step++) {
      ring.add(_AxialCell(q, r));
      q += direction.q;
      r += direction.r;
    }
  }
  return ring;
}

Offset _jitterFor(int index) {
  final x = (((index * 37) % 17) - 8) * 1.4;
  final y = (((index * 53) % 19) - 9) * 1.1;
  return Offset(x, y);
}

int _cellKey(int q, int r) => (q + 100000) * 200001 + r + 100000;

class _AxialCell {
  final int q;
  final int r;

  const _AxialCell(this.q, this.r);
}
