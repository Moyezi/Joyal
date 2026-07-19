import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/song.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/library_provider.dart';
import '../providers/page_background_provider.dart';
import '../providers/player_provider.dart';
import '../utils/app_toast.dart';
import '../utils/scroll_utils.dart';
import '../widgets/discovery/discover_song_carousel.dart';
import '../widgets/discovery/discovery_section_header.dart';
import '../widgets/discovery/for_you_discovery_section.dart';
import '../widgets/glass_top_bar.dart';
import '../widgets/navigation/search_ripple_route.dart';
import '../widgets/play_queue_sheet.dart';
import 'music_classification_screen.dart';
import 'search_screen.dart';

class HotlistScreen extends ConsumerStatefulWidget {
  const HotlistScreen({super.key});

  @override
  ConsumerState<HotlistScreen> createState() => _HotlistScreenState();
}

class _HotlistScreenState extends ConsumerState<HotlistScreen>
    with AutomaticKeepAliveClientMixin {
  static const double _headerHeight = 76;
  static const double _tileExtent = 72;
  static const double _discoverCarouselHeight = 300;
  static const int _carouselInitialPage = 10000;
  final ScrollController _scrollController = ScrollController();
  final PageController _carouselController = PageController(
    initialPage: _carouselInitialPage,
  );
  bool _isRefreshing = false;
  int _forYouRefreshToken = 0;
  int? _discoverCacheKey;
  List<Song>? _discoverSongsSource;
  List<Song> _discoverSongsCache = const [];

  double _topBarExtent(BuildContext context) =>
      _headerHeight + MediaQuery.viewPaddingOf(context).top;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    _carouselController.dispose();
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

    scrollIndexToCenter(
      controller: _scrollController,
      index: index,
      itemExtent: _tileExtent,
      leadingExtent: _topBarExtent(context) + 8 + _discoverCarouselHeight + 12,
    );
  }

  void _refreshForYouCards() {
    if (!mounted) return;
    setState(() => _forYouRefreshToken++);
  }

  Future<void> _refreshDiscovery() async {
    if (_isRefreshing || ref.read(libraryProvider).isLoadingStarred) return;
    if (ref.read(subsonicApiProvider) == null) {
      _refreshForYouCards();
      final hasLocalSongs = ref.read(libraryProvider).songs.isNotEmpty;
      showAppToast(
        context,
        hasLocalSongs ? '已刷新为你发现，收藏刷新需先连接服务器' : '请先连接服务器',
        replaceCurrent: true,
      );
      return;
    }

    setState(() {
      _isRefreshing = true;
      _forYouRefreshToken++;
    });
    showAppToast(context, '正在刷新发现', replaceCurrent: true);

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
        '为你发现已刷新，收藏刷新失败: ${error.toString().replaceFirst('Exception: ', '')}',
        replaceCurrent: true,
      );
      return;
    }

    showAppToast(context, '发现已刷新', replaceCurrent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(libraryProvider);
    final starredSongs = state.starredSongs;
    final discoverSongs = _discoverSongs(state.songs);
    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));
    final currentSongId = ref.watch(
      playerProvider.select((value) => value.currentSong?.id),
    );
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
    final topBarOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(GlassEffectTarget.topBar),
      ),
    );
    final topBarExtent = _topBarExtent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: state.isLoading && discoverSongs.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(top: topBarExtent),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : discoverSongs.isEmpty && starredSongs.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(top: topBarExtent),
                    child: Center(
                      child: Text('还没有可发现的音乐', style: context.textBodyMedium),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshDiscovery,
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        topBarExtent + 8,
                        12,
                        hasSong ? 172 : 68,
                      ),
                      children: [
                        if (discoverSongs.isNotEmpty)
                          SizedBox(
                            height: _discoverCarouselHeight,
                            child: DiscoverSongCarousel(
                              songs: discoverSongs,
                              controller: _carouselController,
                            ),
                          ),
                        const DiscoverySectionHeader(title: '收藏歌曲'),
                        if (starredSongs.isNotEmpty) ...[
                          ...starredSongs.take(6).toList().asMap().entries.map((
                            entry,
                          ) {
                            final song = entry.value;
                            return QueueSongCard(
                              song: song,
                              index: entry.key,
                              coverUrl: _coverUrl(song.coverArt),
                              isCurrent: song.id == currentSongId,
                              onTap: () => ref
                                  .read(playerProvider.notifier)
                                  .playPlaylist(
                                    starredSongs,
                                    startIndex: entry.key,
                                  ),
                            );
                          }),
                          if (starredSongs.length > 6)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => PlayQueueSheet.show(
                                  context,
                                  title: '收藏歌曲',
                                  songs: starredSongs,
                                  onSongTap: (index) => ref
                                      .read(playerProvider.notifier)
                                      .playPlaylist(
                                        starredSongs,
                                        startIndex: index,
                                      ),
                                ),
                                child: const Text('查看更多'),
                              ),
                            ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMD,
                              vertical: AppTheme.spacingLG,
                            ),
                            child: Text(
                              '还没有收藏歌曲',
                              style: context.textBodyMedium.copyWith(
                                color: context.secondaryColor,
                              ),
                            ),
                          ),
                        ForYouDiscoverySection(
                          allSongs: state.songs,
                          starredSongs: starredSongs,
                          refreshToken: _forYouRefreshToken,
                        ),
                      ],
                    ),
                  ),
          ),
          GlassTopBar(
            height: _headerHeight,
            hasPageBackground: hasPageBackground,
            blurSigma: topBarBlur,
            tintOpacity: topBarOpacity,
            child: GlassTopBarTitleRow(
              title: '发现',
              actions: [
                if (hasSong)
                  IconButton(
                    tooltip: '定位到收藏歌曲',
                    onPressed: _locateCurrentSong,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                SearchRippleIconButton(
                  pageBuilder: (_) => const SearchScreen(),
                ),
                IconButton(
                  tooltip: '小Jo同学',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MusicClassificationScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
                IconButton(
                  tooltip: '刷新发现',
                  onPressed: _isRefreshing || state.isLoadingStarred
                      ? null
                      : _refreshDiscovery,
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

  String _coverUrl(String coverArtId) {
    final api = ref.read(subsonicApiProvider);
    if (api == null || coverArtId.isEmpty) return '';
    return api.getCoverArtUrl(coverArtId);
  }

  List<Song> _discoverSongs(List<Song> songs) {
    if (songs.isEmpty) return const [];
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day + 17;
    if (_discoverCacheKey == seed && identical(_discoverSongsSource, songs)) {
      return _discoverSongsCache;
    }
    final shuffled = [...songs]..shuffle(Random(seed));
    _discoverCacheKey = seed;
    _discoverSongsSource = songs;
    _discoverSongsCache = shuffled.take(10).toList(growable: false);
    return _discoverSongsCache;
  }
}
