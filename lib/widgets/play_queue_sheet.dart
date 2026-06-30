import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../utils/scroll_utils.dart';
import 'album_cover.dart';

class PlayQueueSheet extends ConsumerStatefulWidget {
  final String title;
  final List<Song>? songs;
  final int? initialIndex;
  final Future<void> Function(int index)? onSongTap;

  const PlayQueueSheet({
    super.key,
    this.title = '播放队列',
    this.songs,
    this.initialIndex,
    this.onSongTap,
  });

  static Future<void> show(
    BuildContext context, {
    String title = '播放队列',
    List<Song>? songs,
    int? initialIndex,
    Future<void> Function(int index)? onSongTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .22),
      builder: (_) => PlayQueueSheet(
        title: title,
        songs: songs,
        initialIndex: initialIndex,
        onSongTap: onSongTap,
      ),
    );
  }

  @override
  ConsumerState<PlayQueueSheet> createState() => _PlayQueueSheetState();
}

class _PlayQueueSheetState extends ConsumerState<PlayQueueSheet> {
  static const double _itemExtent = 68;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent(int currentIndex) {
    scrollIndexToCenter(
      controller: _scrollController,
      index: currentIndex,
      itemExtent: _itemExtent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final api = ref.watch(subsonicApiProvider);
    final songs = widget.songs ?? state.playlist;
    final currentSongId = state.currentSong?.id;
    final customCurrentIndex = currentSongId == null
        ? -1
        : songs.indexWhere((song) => song.id == currentSongId);
    final activeIndex =
        widget.initialIndex ??
        (widget.songs == null ? state.currentIndex : customCurrentIndex);

    return Container(
      height: MediaQuery.sizeOf(context).height * .78,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.waveformUnplayed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: context.textHeadlineMedium),
                ),
                Text('${songs.length} 首', style: context.textBodyMedium),
                if (activeIndex >= 0)
                  IconButton(
                    tooltip: '定位到当前歌曲',
                    onPressed: () => _scrollToCurrent(activeIndex),
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text('正在播放', style: context.textTitleMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.currentSong?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textBodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: songs.isEmpty
                ? Center(child: Text('队列还是空的', style: context.textBodyMedium))
                : ListView.builder(
                    controller: _scrollController,
                    itemExtent: _itemExtent,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      final isCurrent = widget.songs == null
                          ? index == state.currentIndex
                          : song.id == currentSongId;
                      final canTap = widget.songs != null || !isCurrent;
                      final coverUrl = api == null || song.coverArt.isEmpty
                          ? ''
                          : api.getCoverArtUrl(song.coverArt);

                      return QueueSongCard(
                        song: song,
                        index: index,
                        coverUrl: coverUrl,
                        isCurrent: isCurrent,
                        onTap: !canTap
                            ? null
                            : () async {
                                final onSongTap = widget.onSongTap;
                                if (onSongTap != null) {
                                  await onSongTap(index);
                                  return;
                                }
                                await ref
                                    .read(playerProvider.notifier)
                                    .playAtIndex(index);
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class QueueSongCard extends StatelessWidget {
  final Song song;
  final int index;
  final String coverUrl;
  final bool isCurrent;
  final VoidCallback? onTap;

  const QueueSongCard({
    super.key,
    required this.song,
    required this.index,
    required this.coverUrl,
    this.isCurrent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isCurrent ? context.surfaceColor : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipOval(
                  child: AlbumCover(
                    coverArtUrl: coverUrl,
                    cacheKey: song.coverArt,
                    size: 48,
                    borderRadius: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTitleMedium.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${song.artist} · ${song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textBodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrent)
                  SizedBox(
                    width: 34,
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: context.primaryColor,
                    ),
                  )
                else
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: context.textCaption,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
