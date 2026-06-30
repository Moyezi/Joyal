import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_context.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../utils/scroll_utils.dart';
import '../widgets/glass_top_bar.dart';
import 'album_detail_screen.dart';

class HotlistScreen extends ConsumerStatefulWidget {
  const HotlistScreen({super.key});

  @override
  ConsumerState<HotlistScreen> createState() => _HotlistScreenState();
}

class _HotlistScreenState extends ConsumerState<HotlistScreen> {
  static const double _headerHeight = 76;
  static const double _tileExtent = 72;
  static const double _sectionHeaderExtent = 36;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _locateCurrentSong() {
    final currentSong = ref.read(playerProvider).currentSong;
    final state = ref.read(libraryProvider);
    final index = currentSong == null
        ? -1
        : state.starredSongs.indexWhere((song) => song.id == currentSong.id);
    if (index < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前歌曲不在收藏列表中')));
      return;
    }
    if (!_scrollController.hasClients) return;

    final albumsSectionExtent = state.starredAlbums.isEmpty
        ? 0.0
        : _sectionHeaderExtent + state.starredAlbums.length * _tileExtent + 20;
    scrollIndexToCenter(
      controller: _scrollController,
      index: index,
      itemExtent: _tileExtent,
      leadingExtent:
          _headerHeight + 8 + albumsSectionExtent + _sectionHeaderExtent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final albums = state.starredAlbums;
    final songs = state.starredSongs;
    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: state.isLoadingStarred && albums.isEmpty && songs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: _headerHeight),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : albums.isEmpty && songs.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: _headerHeight),
                      child: Center(
                        child: Text('还没有收藏内容', style: context.textBodyMedium),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(libraryProvider.notifier).fetchStarred(),
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          _headerHeight + 8,
                          20,
                          hasSong ? 172 : 68,
                        ),
                        children: [
                          if (albums.isNotEmpty) ...[
                            Text('收藏专辑', style: context.textTitleLarge),
                            const SizedBox(height: 8),
                            ...albums.map(
                              (album) => SizedBox(
                                height: _tileExtent,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.album_outlined),
                                  title: Text(album.name),
                                  subtitle: Text(album.artist),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AlbumDetailScreen(album: album),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (songs.isNotEmpty) ...[
                            if (albums.isNotEmpty) const SizedBox(height: 20),
                            ...songs.asMap().entries.map(
                              (entry) => SizedBox(
                                height: _tileExtent,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.music_note),
                                  title: Text(entry.value.title),
                                  subtitle: Text(
                                    '${entry.value.artist}  ·  '
                                    '${entry.value.formattedDuration}',
                                  ),
                                  onTap: () => ref
                                      .read(playerProvider.notifier)
                                      .playPlaylist(
                                        songs,
                                        startIndex: entry.key,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            GlassTopBar(
              height: _headerHeight,
              child: GlassTopBarTitleRow(
                title: '收藏',
                actions: [
                  if (hasSong)
                    IconButton(
                      tooltip: '定位到当前歌曲',
                      onPressed: _locateCurrentSong,
                      icon: const Icon(Icons.my_location_rounded),
                    ),
                  IconButton(
                    tooltip: '刷新收藏',
                    onPressed: state.isLoadingStarred
                        ? null
                        : () =>
                              ref.read(libraryProvider.notifier).fetchStarred(),
                    icon: state.isLoadingStarred
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
