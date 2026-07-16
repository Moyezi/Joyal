import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/library_provider.dart';
import '../providers/listening_stats_provider.dart';
import '../providers/page_background_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/album_cover.dart';
import '../widgets/directional_anchor_reveal.dart';
import '../widgets/frosted_glass.dart';
import '../widgets/glass_top_bar.dart';
import '../widgets/home/recent_card_flow.dart';
import '../widgets/page_custom_background.dart';
import '../widgets/play_queue_sheet.dart';
import '../widgets/navigation/search_ripple_route.dart';
import 'album_detail_screen.dart';
import 'search_screen.dart';

/// 主页 Tab – Spotify 风格的专辑浏览。
///
/// 布局：顶部问候语 → 大搜索框 → 最近播放横向滚动 → 随机专辑双列网格。
/// 向下滚动时大搜索框缩小/上移/淡出，同时顶栏右侧搜索图标淡入放大。
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(Rect)? onExclusionZoneChanged;
  final VoidCallback? onShowAllAlbums;
  final Listenable? visibilityRequest;
  const HomeScreen({
    super.key,
    this.onExclusionZoneChanged,
    this.onShowAllAlbums,
    this.visibilityRequest,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // ━━━ Layout constants ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const double _headerHeight = 92;
  static const double _searchBarHeight = 54;
  static const double _searchBarTopPadding = 16;
  static const double _totalRange = _searchBarHeight + _searchBarTopPadding;
  static const double _bottomSpacerBaseHeight = 28;
  static const double _miniPlayerHeight = 104;
  static const double _recentCarouselHeight = 226;

  // ━━━ Animation ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  late final AnimationController _animController;
  late final ScrollController _scrollController;
  final ValueNotifier<DirectionalAnchorScrollDirection> _scrollDirection =
      ValueNotifier(DirectionalAnchorScrollDirection.down);
  final ValueNotifier<int> _cardVisibilityRequest = ValueNotifier<int>(0);
  final GlobalKey _recentListKey = GlobalKey();
  bool _exclusionRectPending = false;
  bool _searchRouteOpen = false;
  int? _dailySongsCacheKey;
  List<Song>? _dailySongsSource;
  List<Song> _dailySongsCache = const [];
  int? _dailyAlbumsCacheKey;
  List<Album>? _dailyAlbumsSource;
  List<Album> _dailyAlbumsCache = const [];
  List<Song>? _recentSongsSource;
  List<String>? _recentSongIdsSource;
  List<Song> _recentSongsCache = const [];
  List<Song>? _recentQueueSource;
  List<Song>? _recentQueuePlaylistSource;
  List<Song> _recentQueueCache = const [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: Duration.zero, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    widget.visibilityRequest?.addListener(_handlePageVisibilityRequest);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibilityRequest != widget.visibilityRequest) {
      oldWidget.visibilityRequest?.removeListener(_handlePageVisibilityRequest);
      widget.visibilityRequest?.addListener(_handlePageVisibilityRequest);
    }
  }

  @override
  void dispose() {
    widget.visibilityRequest?.removeListener(_handlePageVisibilityRequest);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDirection.dispose();
    _cardVisibilityRequest.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handlePageVisibilityRequest() {
    _cardVisibilityRequest.value++;
  }

  void _reportExclusionRect() {
    final callback = widget.onExclusionZoneChanged;
    if (callback == null) return;
    final ctx = _recentListKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final globalOffset = box.localToGlobal(Offset.zero);
    callback(
      Rect.fromLTWH(
        globalOffset.dx,
        globalOffset.dy,
        box.size.width,
        box.size.height,
      ),
    );
  }

  void _scheduleExclusionRectReport() {
    if (_exclusionRectPending) return;
    _exclusionRectPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exclusionRectPending = false;
      _reportExclusionRect();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    switch (_scrollController.position.userScrollDirection) {
      case ScrollDirection.reverse:
        _scrollDirection.value = DirectionalAnchorScrollDirection.down;
      case ScrollDirection.forward:
        _scrollDirection.value = DirectionalAnchorScrollDirection.up;
      case ScrollDirection.idle:
        break;
    }
    final offset = _scrollController.offset;
    final progress = (offset / _totalRange).clamp(0.0, 1.0);
    _animController.value = progress;
    _scheduleExclusionRectReport();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  double _topBarExtent(BuildContext context) =>
      _headerHeight + MediaQuery.viewPaddingOf(context).top;

  Future<void> _openSearchFromTopBar(Offset origin) async {
    if (_searchRouteOpen) return;
    _searchRouteOpen = true;
    try {
      await Navigator.of(context).push(
        buildSearchRippleRoute<void>(
          origin: origin,
          builder: (_) => const SearchScreen(),
        ),
      );
    } finally {
      _searchRouteOpen = false;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final libraryState = ref.watch(libraryProvider);
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

    // 每次重建后尝试上报排除矩形（防抖：同一帧内不重复调度）
    _scheduleExclusionRectReport();

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: PageCustomBackground(target: PageBackgroundTarget.home),
          ),
          Positioned.fill(child: _buildBody(libraryState)),
          GlassTopBar(
            height: _headerHeight,
            hasPageBackground: hasPageBackground,
            blurSigma: topBarBlur,
            tintOpacity: topBarOpacity,
            searchAnimation: _animController,
            onSearchTapAt: _openSearchFromTopBar,
            child: _buildHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_greeting(), style: context.textHeadlineLarge),
          const SizedBox(height: 4),
          Text('发现你的音乐世界', style: context.textBodyMedium),
        ],
      ),
    );
  }

  /// Animated large search bar – responds to scroll progress.
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          final p = _animController.value;
          return IgnorePointer(
            ignoring: p == 1.0,
            child: Opacity(
              opacity: 1.0 - p,
              child: Transform.translate(
                offset: Offset(0, -20 * p),
                child: Transform.scale(
                  scale: 1.0 - 0.15 * p,
                  child: _HomeSearchBar(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(LibraryState state) {
    final topBarExtent = _topBarExtent(context);
    if (state.isLoading && state.albums.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topBarExtent),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.albums.isEmpty) {
      return _buildError(state.error!);
    }

    if (state.albums.isEmpty) {
      return _buildEmpty();
    }

    final albums = state.albums;
    final randomAlbums = _dailyRandomAlbums(albums);
    final recentSongIds = ref.watch(
      listeningStatsProvider.select((state) => state.recentSongIds),
    );
    final recentSongs = _recentlyPlayedSongs(state.songs, recentSongIds);
    final playerPlaylist = ref.watch(
      playerProvider.select((state) => state.playlist),
    );
    final recentQueue = _recentQueueSongs(recentSongs, playerPlaylist);
    final dailySongs = _dailyRecommendedSongs(state.songs);
    final hasSong = ref.watch(playerProvider.select((value) => value.hasSong));
    final bottomSpacerHeight =
        _bottomSpacerBaseHeight + (hasSong ? _miniPlayerHeight : 0);

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).fetchAlbums(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── 顶部问候 ──
          SliverToBoxAdapter(child: SizedBox(height: topBarExtent)),
          SliverToBoxAdapter(child: _buildSearch()),

          // ── 最近播放（横向滚动） ──
          if (recentSongs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionTitle(
                title: '最近播放',
                actionLabel: '查看更多',
                onActionTap: () => _showRecentlyPlayed(recentQueue),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                key: _recentListKey,
                height: _recentCarouselHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppTheme.spacingLG),
                  child: RecentCardFlow(
                    songs: recentQueue,
                    coverUrlFor: _coverUrl,
                    onSongTap: (index) =>
                        unawaited(_playRecentSongs(recentQueue, index)),
                  ),
                ),
              ),
            ),
          ],

          if (dailySongs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: DirectionalAnchorReveal(
                key: const ValueKey('home-daily-title-reveal'),
                controller: _scrollController,
                scrollDirection: _scrollDirection,
                visibilityRequest: _cardVisibilityRequest,
                topInset: topBarExtent,
                child: _SectionTitle(
                  title: '每日推荐',
                  actionLabel: '查看更多',
                  onActionTap: () => _showDailyRecommendations(dailySongs),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _DailyRecommendationsPreview(
                songs: dailySongs,
                controller: _scrollController,
                scrollDirection: _scrollDirection,
                visibilityRequest: _cardVisibilityRequest,
                topInset: topBarExtent,
              ),
            ),
          ],

          // ── 随机专辑（双列网格） ──
          SliverToBoxAdapter(
            child: DirectionalAnchorReveal(
              key: const ValueKey('home-random-albums-title-reveal'),
              controller: _scrollController,
              scrollDirection: _scrollDirection,
              visibilityRequest: _cardVisibilityRequest,
              topInset: topBarExtent,
              child: _SectionTitle(
                title: '随机专辑',
                actionLabel: '查看更多',
                onActionTap: widget.onShowAllAlbums,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppTheme.spacingMD,
                crossAxisSpacing: AppTheme.spacingMD,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final a = randomAlbums[index];
                return DirectionalAnchorReveal(
                  key: ValueKey('home-album-reveal-${a.id}'),
                  controller: _scrollController,
                  scrollDirection: _scrollDirection,
                  visibilityRequest: _cardVisibilityRequest,
                  topInset: topBarExtent,
                  hiddenScale: .68,
                  child: _AlbumGridCard(
                    album: a,
                    coverUrl: _coverUrl(a.coverArt),
                  ),
                );
              }, childCount: randomAlbums.length),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Text(
                  '----到底了----',
                  style: context.textCaption.copyWith(
                    color: context.secondaryColor,
                  ),
                ),
              ),
            ),
          ),

          // 底部留白：避让 MiniPlayer + Dock 覆盖层。
          SliverToBoxAdapter(child: SizedBox(height: bottomSpacerHeight)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: EdgeInsets.only(top: _topBarExtent(context)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: context.secondaryColor),
              const SizedBox(height: AppTheme.spacingMD),
              Text('无法连接到服务器', style: context.textTitleMedium),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                msg,
                style: context.textBodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              ElevatedButton(
                onPressed: () =>
                    ref.read(libraryProvider.notifier).fetchAlbums(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: _topBarExtent(context)),
        _buildSearch(),
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.album_outlined,
                size: 48,
                color: context.secondaryColor,
              ),
              SizedBox(height: AppTheme.spacingMD),
              Text('暂无专辑', style: context.textBodyMedium),
              SizedBox(height: AppTheme.spacingSM),
              Text('请先在「我的」页面连接服务器', style: context.textCaption),
            ],
          ),
        ),
      ],
    );
  }

  String _coverUrl(String coverArtId) {
    final api = ref.read(subsonicApiProvider);
    if (api == null || coverArtId.isEmpty) return '';
    return api.getCoverArtUrl(coverArtId);
  }

  List<Song> _dailyRecommendedSongs(List<Song> songs) {
    if (songs.isEmpty) return const [];
    final seed = _todaySeed();
    if (_dailySongsCacheKey == seed && identical(_dailySongsSource, songs)) {
      return _dailySongsCache;
    }
    final recommended = [...songs]..shuffle(Random(seed));
    _dailySongsCacheKey = seed;
    _dailySongsSource = songs;
    _dailySongsCache = recommended.take(24).toList(growable: false);
    return _dailySongsCache;
  }

  List<Album> _dailyRandomAlbums(List<Album> albums) {
    if (albums.isEmpty) return const [];
    final seed = _todaySeed();
    if (_dailyAlbumsCacheKey == seed && identical(_dailyAlbumsSource, albums)) {
      return _dailyAlbumsCache;
    }
    final randomAlbums = [...albums]..shuffle(Random(seed));
    _dailyAlbumsCacheKey = seed;
    _dailyAlbumsSource = albums;
    _dailyAlbumsCache = randomAlbums.take(8).toList(growable: false);
    return _dailyAlbumsCache;
  }

  List<Song> _recentlyPlayedSongs(List<Song> songs, List<String> recentIds) {
    if (songs.isEmpty || recentIds.isEmpty) return const [];
    if (identical(_recentSongsSource, songs) &&
        identical(_recentSongIdsSource, recentIds)) {
      return _recentSongsCache;
    }
    final songsById = {for (final song in songs) song.id: song};
    final recentSongs = <Song>[];
    for (final songId in recentIds) {
      final song = songsById[songId];
      if (song == null) continue;
      recentSongs.add(song);
      if (recentSongs.length == ListeningStatsNotifier.maxRecentSongs) break;
    }
    _recentSongsSource = songs;
    _recentSongIdsSource = recentIds;
    _recentSongsCache = List.unmodifiable(recentSongs);
    return _recentSongsCache;
  }

  List<Song> _recentQueueSongs(
    List<Song> recentSongs,
    List<Song> playerPlaylist,
  ) {
    if (identical(_recentQueueSource, recentSongs) &&
        identical(_recentQueuePlaylistSource, playerPlaylist)) {
      return _recentQueueCache;
    }

    _recentQueueSource = recentSongs;
    _recentQueuePlaylistSource = playerPlaylist;
    _recentQueueCache = _hasSameSongIds(recentSongs, playerPlaylist)
        ? playerPlaylist
        : recentSongs;
    return _recentQueueCache;
  }

  bool _hasSameSongIds(List<Song> first, List<Song> second) {
    if (first.isEmpty || first.length != second.length) return false;
    final firstIds = first.map((song) => song.id).toSet();
    final secondIds = second.map((song) => song.id).toSet();
    return firstIds.length == first.length &&
        secondIds.length == second.length &&
        firstIds.containsAll(secondIds);
  }

  List<Song> _queueStartingAt(List<Song> songs, int startIndex) {
    if (songs.isEmpty) return const [];
    final start = startIndex.clamp(0, songs.length - 1);
    return List.unmodifiable([...songs.skip(start), ...songs.take(start)]);
  }

  Future<void> _playRecentSongs(List<Song> songs, int startIndex) {
    final queue = _queueStartingAt(songs, startIndex);
    if (queue.isEmpty) return Future.value();
    return ref.read(playerProvider.notifier).playPlaylist(queue);
  }

  int _todaySeed() {
    final today = DateTime.now();
    return today.year * 10000 + today.month * 100 + today.day;
  }

  void _showDailyRecommendations(List<Song> songs) {
    PlayQueueSheet.show(
      context,
      title: '每日推荐',
      songs: songs,
      onSongTap: (index) => ref
          .read(playerProvider.notifier)
          .playPlaylist(songs, startIndex: index),
    );
  }

  void _showRecentlyPlayed(List<Song> songs) {
    PlayQueueSheet.show(
      context,
      title: '最近播放',
      songs: songs,
      onSongTap: (index) => _playRecentSongs(songs, index),
    );
  }
}

class _DailyRecommendationsPreview extends ConsumerWidget {
  final List<Song> songs;
  final ScrollController controller;
  final ValueListenable<DirectionalAnchorScrollDirection> scrollDirection;
  final Listenable visibilityRequest;
  final double topInset;

  const _DailyRecommendationsPreview({
    required this.songs,
    required this.controller,
    required this.scrollDirection,
    required this.visibilityRequest,
    required this.topInset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewSongs = songs.take(3).toList();
    final api = ref.watch(subsonicApiProvider);
    final currentSongId = ref.watch(
      playerProvider.select((value) => value.currentSong?.id),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final entry in previewSongs.indexed)
            DirectionalAnchorReveal(
              key: ValueKey('home-daily-song-reveal-${entry.$2.id}'),
              controller: controller,
              scrollDirection: scrollDirection,
              visibilityRequest: visibilityRequest,
              topInset: topInset,
              hiddenScale: .82,
              child: QueueSongCard(
                song: entry.$2,
                index: entry.$1,
                coverUrl: api == null || entry.$2.coverArt.isEmpty
                    ? ''
                    : api.getCoverArtUrl(entry.$2.coverArt),
                isCurrent: entry.$2.id == currentSongId,
                onTap: () => ref
                    .read(playerProvider.notifier)
                    .playPlaylist(songs, startIndex: entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

// ━━━ 最近播放横向卡片 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HomeSearchBar extends ConsumerWidget {
  final VoidCallback onTap;

  const _HomeSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blurSigma = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.searchBar),
      ),
    );
    final tintOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(GlassEffectTarget.searchBar),
      ),
    );
    return FrostedGlass(
      blurSigma: blurSigma,
      borderRadius: BorderRadius.circular(18),
      tintColor: context.surfaceColor,
      tintOpacity: tintOpacity,
      borderColor: context.primaryColor,
      borderOpacity: 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: context.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '搜索歌曲、专辑或艺人',
                      style: context.textBodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: context.secondaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━ 全部专辑网格卡片 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AlbumGridCard extends ConsumerWidget {
  final Album album;
  final String coverUrl;
  const _AlbumGridCard({required this.album, required this.coverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AlbumCover(
              coverArtUrl: coverUrl,
              cacheKey: album.coverArt,
              size: double.infinity,
              borderRadius: AppTheme.radiusMedium,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            album.name,
            style: context.textTitleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            style: context.textBodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ━━━ 区域标题 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        AppTheme.spacingLG,
        AppTheme.spacingLG,
        AppTheme.spacingSM,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.textTitleLarge)),
          if (actionLabel != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                foregroundColor: context.secondaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: context.textBodyMedium),
            ),
        ],
      ),
    );
  }
}
