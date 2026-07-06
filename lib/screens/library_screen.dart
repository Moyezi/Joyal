import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lpinyin/lpinyin.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/music_classification.dart';
import '../models/song.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/library_provider.dart';
import '../providers/music_classification_provider.dart';
import '../providers/page_background_provider.dart';
import '../providers/player_provider.dart';
import '../utils/app_toast.dart';
import '../utils/scroll_utils.dart';
import '../widgets/album_cover.dart';
import '../widgets/glass_top_bar.dart';
import '../widgets/page_custom_background.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/song_tile.dart';
import 'album_detail_screen.dart';

enum _LibrarySongSort {
  titleInitial('歌曲名首字母'),
  playCount('播放次数'),
  language('歌曲语言');

  const _LibrarySongSort(this.label);

  final String label;
}

class LibraryScreen extends ConsumerStatefulWidget {
  final ValueListenable<int>? tabRequest;

  const LibraryScreen({super.key, this.tabRequest});

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
  bool _isRefreshing = false;
  _LibrarySongSort _songSort = _LibrarySongSort.titleInitial;

  double _topBarExtent(BuildContext context) =>
      _headerHeight + MediaQuery.viewPaddingOf(context).top;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.tabRequest?.addListener(_handleTabRequest);
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabRequest == widget.tabRequest) return;
    oldWidget.tabRequest?.removeListener(_handleTabRequest);
    widget.tabRequest?.addListener(_handleTabRequest);
  }

  @override
  void dispose() {
    widget.tabRequest?.removeListener(_handleTabRequest);
    _tabController.dispose();
    _songsController.dispose();
    _albumsController.dispose();
    super.dispose();
  }

  void _handleTabRequest() {
    final index = widget.tabRequest?.value;
    if (index == null || index < 0 || index >= _tabController.length) return;
    if (_tabController.index == index) return;
    _tabController.animateTo(index);
  }

  Future<void> _locateCurrentSong() async {
    final currentSong = ref.read(playerProvider).currentSong;
    final songs = _sortedSongs(ref.read(libraryProvider).songs);
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
      leadingExtent: _topBarExtent(context) + 8,
    );
  }

  Future<void> _refreshLibrary() async {
    if (_isRefreshing) return;
    if (ref.read(subsonicApiProvider) == null) {
      showAppToast(context, '请先连接服务器');
      return;
    }

    setState(() => _isRefreshing = true);
    showAppToast(context, '正在刷新曲库', replaceCurrent: true);

    Object? refreshError;
    try {
      await ref.read(libraryProvider.notifier).refreshLibrary();
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

    showAppToast(context, '曲库已刷新', replaceCurrent: true);
  }

  List<Song> _sortedSongs(List<Song> songs) {
    final sorted = [...songs];
    final classifications = ref
        .read(musicClassificationProvider)
        .classifications;
    sorted.sort((a, b) {
      final result = switch (_songSort) {
        _LibrarySongSort.titleInitial => _compareByTitleInitial(a, b),
        _LibrarySongSort.playCount => _compareByPlayCount(a, b),
        _LibrarySongSort.language => _compareByLanguage(a, b, classifications),
      };
      if (result != 0) return result;
      return _compareText(a.artist, b.artist);
    });
    return sorted;
  }

  int _compareByTitleInitial(Song a, Song b) {
    final result = _compareText(_sortInitial(a.title), _sortInitial(b.title));
    if (result != 0) return result;
    return _compareText(a.title, b.title);
  }

  int _compareByPlayCount(Song a, Song b) {
    final result = b.playCount.compareTo(a.playCount);
    if (result != 0) return result;
    return _compareText(a.title, b.title);
  }

  int _compareByLanguage(
    Song a,
    Song b,
    Map<String, SongClassification> classifications,
  ) {
    final languageA = classifications[a.id]?.language ?? '未分类';
    final languageB = classifications[b.id]?.language ?? '未分类';
    final result = _compareText(languageA, languageB);
    if (result != 0) return result;
    return _compareByTitleInitial(a, b);
  }

  String _sortInitial(String value) {
    final text = value.trim();
    if (text.isEmpty) return '#';
    final firstChar = String.fromCharCode(text.runes.first);
    if (ChineseHelper.isChinese(firstChar)) {
      final shortPinyin = PinyinHelper.getShortPinyin(firstChar);
      if (shortPinyin.isNotEmpty) return shortPinyin[0].toLowerCase();
    }
    return firstChar.toLowerCase();
  }

  int _compareText(String a, String b) {
    return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));
    final hasPageBackground = ref.watch(
      pageBackgroundProvider.select(
        (state) => state.imagePath != null && state.imagePath!.isNotEmpty,
      ),
    );
    final topBarBlur = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.topBar),
      ),
    );
    ref.watch(
      musicClassificationProvider.select((state) => state.classifications),
    );
    final sortedSongs = _sortedSongs(state.songs);
    final topBarExtent = _topBarExtent(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: PageCustomBackground(target: PageBackgroundTarget.library),
          ),
          Positioned.fill(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SongsView(
                  state: state,
                  songs: sortedSongs,
                  controller: _songsController,
                  topPadding: topBarExtent,
                ),
                _AlbumsView(
                  state: state,
                  controller: _albumsController,
                  topPadding: topBarExtent,
                ),
              ],
            ),
          ),
          GlassTopBar(
            height: _headerHeight,
            hasPageBackground: hasPageBackground,
            blurSigma: topBarBlur,
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
                      onPressed: _isRefreshing ? null : _refreshLibrary,
                      icon: _isRefreshing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                    PopupMenuButton<_LibrarySongSort>(
                      tooltip: '排序',
                      initialValue: _songSort,
                      icon: const Icon(Icons.sort_rounded),
                      onSelected: (value) {
                        setState(() => _songSort = value);
                        if (_songsController.hasClients) {
                          _songsController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      itemBuilder: (context) {
                        return _LibrarySongSort.values.map((sort) {
                          return PopupMenuItem<_LibrarySongSort>(
                            value: sort,
                            child: Row(
                              children: [
                                Icon(
                                  sort == _songSort
                                      ? Icons.check_rounded
                                      : Icons.sort_rounded,
                                  size: 18,
                                  color: sort == _songSort
                                      ? context.primaryColor
                                      : context.secondaryColor,
                                ),
                                const SizedBox(width: 12),
                                Text(sort.label),
                              ],
                            ),
                          );
                        }).toList();
                      },
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
    );
  }
}

class _SongsView extends ConsumerWidget {
  final LibraryState state;
  final List<Song> songs;
  final ScrollController controller;
  final double topPadding;

  const _SongsView({
    required this.state,
    required this.songs,
    required this.controller,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
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
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isStarred = starredIds.contains(song.id);
        return SongTile(
          song: song,
          index: index,
          isPlaying: song.id == currentSongId,
          isDownloaded: downloadedIds.contains(song.id),
          onTap: () => ref
              .read(playerProvider.notifier)
              .playPlaylist(songs, startIndex: index),
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
