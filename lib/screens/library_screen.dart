import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../utils/app_toast.dart';
import '../utils/scroll_utils.dart';
import '../widgets/album_cover.dart';
import '../widgets/glass_top_bar.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/song_tile.dart';
import 'album_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  static const double _topBarHeight = 76;
  static const double _tabBarHeight = 48;
  static const double _headerHeight = _topBarHeight + _tabBarHeight;
  static const double _songExtent = 72;

  late final TabController _tabController;
  final ScrollController _songsController = ScrollController();
  final ScrollController _albumsController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _songsController.dispose();
    _albumsController.dispose();
    super.dispose();
  }

  Future<void> _locateCurrentSong() async {
    final currentSong = ref.read(playerProvider).currentSong;
    final songs = ref.read(libraryProvider).songs;
    final index = currentSong == null
        ? -1
        : songs.indexWhere((song) => song.id == currentSong.id);
    if (index < 0) {
      showAppToast(context, '当前歌曲不在曲库列表中');
      return;
    }

    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      await Future<void>.delayed(const Duration(milliseconds: 320));
    } else {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    await scrollIndexToCenter(
      controller: _songsController,
      index: index,
      itemExtent: _songExtent,
      leadingExtent: _headerHeight + 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SongsView(
                    state: state,
                    controller: _songsController,
                    topPadding: _headerHeight,
                  ),
                  _AlbumsView(
                    state: state,
                    controller: _albumsController,
                    topPadding: _headerHeight,
                  ),
                ],
              ),
            ),
            GlassTopBar(
              height: _headerHeight,
              child: Column(
                children: [
                  GlassTopBarTitleRow(
                    height: _topBarHeight,
                    title: '曲库',
                    actions: [
                      if (hasSong)
                        IconButton(
                          tooltip: '定位到当前歌曲',
                          onPressed: _locateCurrentSong,
                          icon: const Icon(Icons.my_location_rounded),
                        ),
                      IconButton(
                        tooltip: '刷新曲库',
                        onPressed: () =>
                            ref.read(libraryProvider.notifier).refreshLibrary(),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    labelColor: context.primaryColor,
                    unselectedLabelColor: context.secondaryColor,
                    indicatorColor: context.primaryColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: '歌曲  ${state.songs.length}'),
                      Tab(text: '专辑  ${state.albums.length}'),
                    ],
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

class _SongsView extends ConsumerWidget {
  final LibraryState state;
  final ScrollController controller;
  final double topPadding;

  const _SongsView({
    required this.state,
    required this.controller,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.songs.isEmpty) {
      return _EmptyState(
        topPadding: topPadding,
        loading: state.isLoadingSongs,
        loadingText: '正在同步全部歌曲…',
        emptyText: '连接服务器后，歌曲会出现在这里',
      );
    }

    final currentSongId = ref.watch(
      playerProvider.select((value) => value.currentSong?.id),
    );
    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));
    final starredIds = ref.watch(
      libraryProvider.select(
        (value) => value.starredSongs.map((s) => s.id).toSet(),
      ),
    );
    final downloadedIds = ref
        .watch(downloadRecordsProvider)
        .maybeWhen(
          data: (records) => records.map((record) => record.song.id).toSet(),
          orElse: () => <String>{},
        );

    return ListView.builder(
      controller: controller,
      itemExtent: _LibraryScreenState._songExtent,
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, hasSong ? 172 : 68),
      itemCount: state.songs.length,
      itemBuilder: (context, index) {
        final song = state.songs[index];
        final isStarred = starredIds.contains(song.id);
        return SongTile(
          song: song,
          index: index,
          isPlaying: song.id == currentSongId,
          isDownloaded: downloadedIds.contains(song.id),
          onTap: () => ref
              .read(playerProvider.notifier)
              .playPlaylist(state.songs, startIndex: index),
          onMore: () => SongActionsSheet.show(
            context,
            songTitle: song.title,
            songArtist: song.artist,
            isStarred: isStarred,
            onPlayNext: () {
              ref.read(playerProvider.notifier).playNext(song);
            },
            onToggleFavorite: () {
              ref
                  .read(libraryProvider.notifier)
                  .setSongStarred(song, starred: !isStarred);
            },
            downloadService: ref.read(downloadServiceProvider),
            songId: song.id,
            song: song,
          ),
        );
      },
    );
  }
}

class _AlbumsView extends ConsumerWidget {
  final LibraryState state;
  final ScrollController controller;
  final double topPadding;

  const _AlbumsView({
    required this.state,
    required this.controller,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.albums.isEmpty) {
      return _EmptyState(
        topPadding: topPadding,
        loading: state.isLoading,
        loadingText: '正在同步全部专辑…',
        emptyText: '连接服务器后，专辑会出现在这里',
      );
    }

    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));
    final api = ref.watch(subsonicApiProvider);
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, hasSong ? 172 : 68),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 22,
        crossAxisSpacing: 16,
        childAspectRatio: .78,
      ),
      itemCount: state.albums.length,
      itemBuilder: (context, index) {
        final album = state.albums[index];
        final cover = api == null || album.coverArt.isEmpty
            ? ''
            : api.getCoverArtUrl(album.coverArt);
        return InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AlbumCover(
                  coverArtUrl: cover,
                  cacheKey: album.coverArt,
                  size: double.infinity,
                  borderRadius: AppTheme.radiusMedium,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                album.name,
                style: context.textTitleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                album.artist,
                style: context.textBodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final double topPadding;
  final bool loading;
  final String loadingText;
  final String emptyText;

  const _EmptyState({
    required this.topPadding,
    required this.loading,
    required this.loadingText,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              loading ? loadingText : emptyText,
              style: context.textBodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
