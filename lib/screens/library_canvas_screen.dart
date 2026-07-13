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
import '../utils/two_finger_pinch_tracker.dart';
import '../widgets/cached_disk_image.dart';
import '../widgets/home_sidebar.dart';

class LibraryCanvasScreen extends ConsumerStatefulWidget {
  final Object heroTag;

  const LibraryCanvasScreen({super.key, this.heroTag = libraryCanvasHeroTag});

  @override
  ConsumerState<LibraryCanvasScreen> createState() =>
      _LibraryCanvasScreenState();
}

class _LibraryCanvasScreenState extends ConsumerState<LibraryCanvasScreen>
    with SingleTickerProviderStateMixin {
  static const double _horizontalStep = 248;
  static const double _verticalStep = 232;
  static const double _viewportInset = 0;
  static const double _pinchCloseScale = 0.82;
  static const double _pinchCloseDistance = 48;

  late final AnimationController _snapController;
  late final ValueNotifier<Offset> _canvasOffsetNotifier;
  late final ValueNotifier<bool> _interactionNotifier;
  Animation<Offset>? _snapAnimation;
  Size _lastViewport = Size.zero;
  List<_AxialCell> _cells = const [];
  Map<int, int> _indexByCell = const {};
  int _songCount = -1;
  bool _hasInitialFocus = false;
  int? _lastDragFocusIndex;
  final TwoFingerPinchTracker _pinchTracker = TwoFingerPinchTracker();
  bool _isPinchClosing = false;

  @override
  void initState() {
    super.initState();
    _canvasOffsetNotifier = ValueNotifier(Offset.zero);
    _interactionNotifier = ValueNotifier(false);
    _snapController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 520),
          )
          ..addListener(() {
            final animation = _snapAnimation;
            if (animation != null && mounted) {
              _canvasOffsetNotifier.value = animation.value;
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed) {
              _interactionNotifier.value = false;
            }
          });
  }

  Offset get _canvasOffset => _canvasOffsetNotifier.value;

  @override
  void dispose() {
    _snapController.dispose();
    _canvasOffsetNotifier.dispose();
    _interactionNotifier.dispose();
    _pinchTracker.reset();
    super.dispose();
  }

  void _handlePinchPointerDown(PointerDownEvent event) {
    if (_isPinchClosing) return;
    _pinchTracker.addPointer(event.pointer, event.position);
    if (_pinchTracker.isTracking) {
      _snapController.stop();
      _interactionNotifier.value = true;
      _lastDragFocusIndex = null;
    }
  }

  void _handlePinchPointerMove(PointerMoveEvent event) {
    final progress = _pinchTracker.updatePointer(event.pointer, event.position);
    if (progress == null || _pinchTracker.hasTriggered || _isPinchClosing) {
      return;
    }
    if (progress.scale > _pinchCloseScale ||
        progress.distanceDelta > -_pinchCloseDistance) {
      return;
    }

    _pinchTracker.markTriggered();
    _isPinchClosing = true;
    HapticFeedback.mediumImpact();
    Navigator.maybePop(context);
  }

  void _handlePinchPointerEnd(PointerEvent event) {
    _pinchTracker.removePointer(event.pointer);
    if (_pinchTracker.pointerCount != 0 || _isPinchClosing) return;

    final nearest = _lastViewport.isEmpty
        ? null
        : _nearestVisibleIndex(_lastViewport);
    if (nearest == null) {
      _interactionNotifier.value = false;
    } else {
      _animateToIndex(nearest);
    }
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
    _canvasOffsetNotifier.value = -_worldPosition(index);
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
    _interactionNotifier.value = true;
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
    return _nearestIndex(candidates);
  }

  int? _nearestIndex(Iterable<int> candidates) {
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
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePinchPointerDown,
        onPointerMove: _handlePinchPointerMove,
        onPointerUp: _handlePinchPointerEnd,
        onPointerCancel: _handlePinchPointerEnd,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(_viewportInset),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _lastViewport = size;
                _initializeFocus(songs, currentSong);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) {
                          _snapController.stop();
                          _interactionNotifier.value = true;
                          _lastDragFocusIndex = _nearestVisibleIndex(size);
                          HapticFeedback.lightImpact();
                        },
                        onPanUpdate: (details) {
                          if (_pinchTracker.isTracking) return;
                          _canvasOffsetNotifier.value =
                              _canvasOffset + details.delta;
                          final nearest = _nearestVisibleIndex(size);
                          if (nearest != null &&
                              nearest != _lastDragFocusIndex) {
                            _lastDragFocusIndex = nearest;
                            HapticFeedback.selectionClick();
                          }
                        },
                        onPanEnd: (_) {
                          final nearest = _nearestVisibleIndex(size);
                          _lastDragFocusIndex = null;
                          if (nearest != null) _animateToIndex(nearest);
                        },
                        onPanCancel: () {
                          _lastDragFocusIndex = null;
                          _interactionNotifier.value = false;
                        },
                        child: ColoredBox(
                          color: const Color(0xFF121416),
                          child: songs.isEmpty
                              ? const _EmptyCanvas()
                              : ValueListenableBuilder<bool>(
                                  valueListenable: _interactionNotifier,
                                  builder: (context, isInteracting, _) {
                                    return ValueListenableBuilder<Offset>(
                                      valueListenable: _canvasOffsetNotifier,
                                      builder: (context, canvasOffset, _) {
                                        final visibleIndices = _visibleIndices(
                                          size,
                                        );
                                        return _CanvasCards(
                                          songs: songs,
                                          indices: visibleIndices,
                                          focusedIndex: _nearestIndex(
                                            visibleIndices,
                                          ),
                                          canvasOffset: canvasOffset,
                                          viewportSize: size,
                                          worldPosition: _worldPosition,
                                          blurEnabled: !isInteracting,
                                          onFocus: _animateToIndex,
                                          onPlay: (index) =>
                                              _playSong(songs, index),
                                          onPlayNext: (index) => ref
                                              .read(playerProvider.notifier)
                                              .playNext(songs[index]),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 12,
                      child: _CanvasHeader(
                        heroTag: widget.heroTag,
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
  final bool blurEnabled;
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
    required this.blurEnabled,
    required this.onFocus,
    required this.onPlay,
    required this.onPlayNext,
  });

  @override
  Widget build(BuildContext context) {
    final center = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final maxDistance =
        math.min(viewportSize.width, viewportSize.height) * 0.68;
    // Keep child order stable while panning so keyed cover elements are not
    // repeatedly moved through the Stack. Only lift the nearest card when the
    // focus actually crosses into another cell.
    final ordered = [
      for (final index in indices)
        if (index != focusedIndex) index,
      if (focusedIndex != null && indices.contains(focusedIndex)) focusedIndex!,
    ];

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
    const cardWidth = 224.0;
    final width = 86 + 138 * focus;
    final scale = width / cardWidth;
    final opacity = (0.16 + focus * 0.84).clamp(0.0, 1.0);
    return Positioned(
      key: ValueKey('library-canvas-${songs[index].id}'),
      left: center.dx - cardWidth / 2,
      top: center.dy - cardWidth * 0.66,
      width: cardWidth,
      child: Transform.translate(
        offset: Offset(relative.dx, relative.dy + (cardWidth - width) * 0.66),
        child: Transform.scale(
          alignment: Alignment.topCenter,
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: _SongCanvasCard(
              song: songs[index],
              isFocused: isFocused,
              blurSigma: blurEnabled ? (1 - focus) * 2.8 : 0,
              onTap: () => onFocus(index),
              onPlay: () => onPlay(index),
              onPlayNext: () => onPlayNext(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongCanvasCard extends ConsumerStatefulWidget {
  final Song song;
  final bool isFocused;
  final double blurSigma;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onPlayNext;

  const _SongCanvasCard({
    required this.song,
    required this.isFocused,
    required this.blurSigma,
    required this.onTap,
    required this.onPlay,
    required this.onPlayNext,
  });

  @override
  ConsumerState<_SongCanvasCard> createState() => _SongCanvasCardState();
}

class _SongCanvasCardState extends ConsumerState<_SongCanvasCard> {
  Object? _coverApiIdentity;
  String? _coverArtId;
  String _coverUrl = '';

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(subsonicApiProvider);
    // Subsonic URLs contain a fresh random salt and MD5 token. Rebuilding one
    // for every visible card on every pan frame is both needless CPU work and
    // makes the image widgets observe a different URL continuously. Keep the
    // authenticated URL stable until either the API session or cover changes.
    if (!identical(_coverApiIdentity, api) ||
        _coverArtId != widget.song.coverArt) {
      _coverApiIdentity = api;
      _coverArtId = widget.song.coverArt;
      _coverUrl = api == null || widget.song.coverArt.isEmpty
          ? ''
          : api.getCoverArtUrl(widget.song.coverArt);
    }
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CachedDiskImage(
        imageUrl: _coverUrl,
        cacheKey: widget.song.coverArt,
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
        label: '${widget.song.title}，${widget.song.artist}',
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xF5202326),
              borderRadius: BorderRadius.circular(22),
              boxShadow: !widget.isFocused
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x29000000),
                        blurRadius: 34,
                        offset: Offset(0, 16),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ImageFiltered(
                    enabled: widget.blurSigma >= 0.2,
                    imageFilter: ImageFilter.blur(
                      sigmaX: widget.blurSigma,
                      sigmaY: widget.blurSigma,
                    ),
                    child: image,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.song.artist.isEmpty
                            ? '未知艺术家'
                            : widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !widget.isFocused,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: widget.isFocused ? 1 : 0,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final isPlayingThisSong = ref.watch(
                              playerProvider.select(
                                (state) =>
                                    state.currentSong?.id == widget.song.id &&
                                    state.isPlaying,
                              ),
                            );
                            return _CardAction(
                              icon: isPlayingThisSong
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              tooltip: isPlayingThisSong ? '暂停' : '播放',
                              onTap: widget.onPlay,
                            );
                          },
                        ),
                      ),
                    ),
                    _CardAction(
                      icon: Icons.playlist_play_rounded,
                      tooltip: '下一首播放',
                      onTap: widget.onPlayNext,
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
  final Object heroTag;
  final String? imagePath;
  final Alignment alignment;
  final int songCount;
  final VoidCallback onBack;

  const _CanvasHeader({
    required this.heroTag,
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
                  tag: heroTag,
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
