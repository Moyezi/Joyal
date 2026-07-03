import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_context.dart';
import '../providers/library_provider.dart';
import '../providers/page_background_provider.dart';
import '../providers/player_provider.dart';
import '../utils/app_toast.dart';
import '../utils/scroll_utils.dart';
import '../widgets/glass_top_bar.dart';
import '../widgets/page_custom_background.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/song_tile.dart';
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
  bool _isRefreshing = false;

  double _topBarExtent(BuildContext context) =>
      _headerHeight + MediaQuery.viewPaddingOf(context).top;

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
      showAppToast(context, '当前歌曲不在收藏列表中');
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
          _topBarExtent(context) +
          8 +
          albumsSectionExtent +
          _sectionHeaderExtent,
    );
  }

  Future<void> _refreshStarred() async {
    if (_isRefreshing) return;
    if (ref.read(subsonicApiProvider) == null) {
      showAppToast(context, '请先连接服务器');
      return;
    }

    setState(() => _isRefreshing = true);
    showAppToast(context, '正在刷新收藏', replaceCurrent: true);

    Object? refreshError;
    try {
      await ref.read(libraryProvider.notifier).fetchStarred();
    } catch (error) {
      refreshError = error;
    }

    if (!mounted) return;
    setState(() => _isRefreshing = false);

    final stateError = ref.read(libraryProvider).error;
    final error = refreshError ?? stateError;
    if (error != null) {
      showAppToast(
        context,
        '刷新失败: ${error.toString().replaceFirst('Exception: ', '')}',
        replaceCurrent: true,
      );
      return;
    }

    showAppToast(context, '收藏已刷新', replaceCurrent: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final albums = state.starredAlbums;
    final songs = state.starredSongs;
    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));
    final currentSongId = ref.watch(
      playerProvider.select((value) => value.currentSong?.id),
    );
    final hasPageBackground = ref.watch(
      pageBackgroundProvider.select(
        (state) => state.imagePath != null && state.imagePath!.isNotEmpty,
      ),
    );
    final starredIds = state.starredSongs.map((song) => song.id).toSet();
    final downloadedIds = ref
        .watch(downloadRecordsProvider)
        .maybeWhen(
          data: (records) => records.map((record) => record.song.id).toSet(),
          orElse: () => <String>{},
        );
    final topBarExtent = _topBarExtent(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: PageCustomBackground(target: PageBackgroundTarget.favorites),
          ),
          Positioned.fill(
            child: state.isLoadingStarred && albums.isEmpty && songs.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(top: topBarExtent),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : albums.isEmpty && songs.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(top: topBarExtent),
                    child: Center(
                      child: Text('还没有收藏内容', style: context.textBodyMedium),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshStarred,
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        topBarExtent + 8,
                        12,
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
                              child: SongTile(
                                song: entry.value,
                                index: entry.key,
                                isPlaying: entry.value.id == currentSongId,
                                isDownloaded: downloadedIds.contains(
                                  entry.value.id,
                                ),
                                onTap: () => ref
                                    .read(playerProvider.notifier)
                                    .playPlaylist(songs, startIndex: entry.key),
                                onMore: () {
                                  final song = entry.value;
                                  final isStarred = starredIds.contains(
                                    song.id,
                                  );
                                  SongActionsSheet.show(
                                    context,
                                    songTitle: song.title,
                                    songArtist: song.artist,
                                    isStarred: isStarred,
                                    onPlayNext: () {
                                      ref
                                          .read(playerProvider.notifier)
                                          .playNext(song);
                                    },
                                    onToggleFavorite: () {
                                      ref
                                          .read(libraryProvider.notifier)
                                          .setSongStarred(
                                            song,
                                            starred: !isStarred,
                                          );
                                    },
                                    downloadService: ref.read(
                                      downloadServiceProvider,
                                    ),
                                    songId: song.id,
                                    song: song,
                                  );
                                },
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
            hasPageBackground: hasPageBackground,
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
                  onPressed: _isRefreshing || state.isLoadingStarred
                      ? null
                      : _refreshStarred,
                  icon: _isRefreshing || state.isLoadingStarred
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
    );
  }
}
