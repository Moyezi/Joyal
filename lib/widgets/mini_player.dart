import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/player_provider.dart';
import 'cached_disk_image.dart';

/// 悬浮胶囊式迷你播放器，显示在底部导航栏上方。
///
/// - 显示当前歌曲封面
/// - 播放/暂停控制
/// - 点击展开"正在播放"全屏页面
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
            // ── 迷你封面 ──
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

            const SizedBox(width: 18),

            // ── 歌曲信息 ──
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── 播放 / 暂停 ──
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
