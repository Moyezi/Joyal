import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
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
import '../widgets/cached_disk_image.dart';
import '../widgets/frosted_glass.dart';
import '../widgets/glass_top_bar.dart';
import '../widgets/page_custom_background.dart';
import '../widgets/play_queue_sheet.dart';
import 'album_detail_screen.dart';
import 'search_screen.dart';

/// 主页 Tab – Spotify 风格的专辑浏览。
///
/// 布局：顶部问候语 → 大搜索框 → 最近播放横向滚动 → 随机专辑双列网格。
/// 向下滚动时大搜索框缩小/上移/淡出，同时顶栏右侧搜索图标淡入放大。
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(Rect)? onExclusionZoneChanged;
  final VoidCallback? onShowAllAlbums;
  const HomeScreen({
    super.key,
    this.onExclusionZoneChanged,
    this.onShowAllAlbums,
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
  final GlobalKey _recentListKey = GlobalKey();
  bool _exclusionRectPending = false;
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
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
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
            onSearchTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
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
                  child: _RecentCardFlow(
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
              child: _SectionTitle(
                title: '每日推荐',
                actionLabel: '查看更多',
                onActionTap: () => _showDailyRecommendations(dailySongs),
              ),
            ),
            SliverToBoxAdapter(
              child: _DailyRecommendationsPreview(songs: dailySongs),
            ),
          ],

          // ── 随机专辑（双列网格） ──
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: '随机专辑',
              actionLabel: '查看更多',
              onActionTap: widget.onShowAllAlbums,
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
                return _AlbumGridCard(
                  album: a,
                  coverUrl: _coverUrl(a.coverArt),
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

  const _DailyRecommendationsPreview({required this.songs});

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
            QueueSongCard(
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
        ],
      ),
    );
  }
}

// ━━━ 最近播放横向卡片 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RecentCardFlow extends StatefulWidget {
  final List<Song> songs;
  final String Function(String coverArtId) coverUrlFor;
  final void Function(int index) onSongTap;

  const _RecentCardFlow({
    required this.songs,
    required this.coverUrlFor,
    required this.onSongTap,
  });

  @override
  State<_RecentCardFlow> createState() => _RecentCardFlowState();
}

class _RecentCardFlowState extends State<_RecentCardFlow>
    with SingleTickerProviderStateMixin {
  static const double _snapVelocity = 420;

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;
  double _page = 0;
  double _pageMotion = 0;
  double _dragExtent = 220;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final animation = _snapAnimation;
          if (animation == null) return;
          _setPage(animation.value);
        });
  }

  @override
  void didUpdateWidget(covariant _RecentCardFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songs.length <= 1) {
      _snapController.stop();
      _page = 0;
      _pageMotion = 0;
      return;
    }

    if (oldWidget.songs.isEmpty) return;
    final previousPage = _page.round();
    final previousSongIndex = _wrappedIndex(
      previousPage,
      oldWidget.songs.length,
    );
    final focusedSongId = oldWidget.songs[previousSongIndex].id;
    final newSongIndex = widget.songs.indexWhere(
      (song) => song.id == focusedSongId,
    );
    if (newSongIndex == -1 || newSongIndex == previousSongIndex) return;

    // Playing a song promotes it to the front of the recent-history source.
    // Keep that same song focused even though its list index has changed.
    _snapController.stop();
    final targetPage = previousPage - previousSongIndex + newSongIndex;
    _page += targetPage - previousPage;
    _pageMotion = 0;
  }

  int _wrappedIndex(int page, int length) {
    final index = page % length;
    return index < 0 ? index + length : index;
  }

  Song _songAtPage(int page) {
    return widget.songs[_wrappedIndex(page, widget.songs.length)];
  }

  void _handleDragStart(DragStartDetails details) {
    _snapController.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.songs.length <= 1) return;
    final primaryDelta = details.primaryDelta;
    if (primaryDelta == null) return;

    _setPage(_page - primaryDelta / _dragExtent);
  }

  void _setPage(double nextPage) {
    final motion = nextPage.compareTo(_page).toDouble();
    setState(() {
      _pageMotion = motion;
      _page = nextPage;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.songs.length <= 1) return;
    final velocity = details.primaryVelocity ?? 0;
    var target = _page.round();
    if (velocity < -_snapVelocity) {
      target = _page.floor() + 1;
    } else if (velocity > _snapVelocity) {
      target = _page.ceil() - 1;
    }
    _animateToPage(target.toDouble());
  }

  void _animateToPage(double targetPage) {
    if ((targetPage - _page).abs() < 0.001) {
      _setPage(targetPage);
      return;
    }

    _snapAnimation = Tween<double>(begin: _page, end: targetPage).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController.forward(from: 0);
  }

  void _handleCardTap(int page, int songIndex) {
    if ((page - _page).abs() < 0.16) {
      widget.onSongTap(songIndex);
      return;
    }
    _animateToPage(page.toDouble());
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _HomeScreenState._recentCarouselHeight;
        final metrics = _RecentFlowMetrics.forSize(
          viewportWidth: viewportWidth,
          height: height,
        );
        _dragExtent = max(160.0, metrics.fullWidth + metrics.gap);

        final basePage = _page.floor();
        final startPage = basePage - 1;
        final endPage = basePage + 3;
        final visibleCards = <_PositionedRecentCard>[];
        for (var page = startPage; page <= endPage; page += 1) {
          final slot = _slotForOffset(
            page - _page,
            metrics,
            pageMotion: _pageMotion,
          );
          if (slot.opacity <= 0.01) continue;
          final songIndex = _wrappedIndex(page, widget.songs.length);
          visibleCards.add(
            _PositionedRecentCard(
              page: page,
              songIndex: songIndex,
              song: _songAtPage(page),
              slot: slot,
            ),
          );
        }
        visibleCards.sort(
          (a, b) => a.slot.focusAmount.compareTo(b.slot.focusAmount),
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: SizedBox.expand(
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final card in visibleCards)
                    Positioned(
                      key: ValueKey('recent-${card.page}-${card.song.id}'),
                      left: card.slot.x,
                      top: 0,
                      bottom: 0,
                      width: card.slot.width,
                      child: Opacity(
                        opacity: card.slot.opacity,
                        child: _RecentCard(
                          song: card.song,
                          coverUrl: widget.coverUrlFor(card.song.coverArt),
                          focusAmount: card.slot.focusAmount,
                          borderRadius: card.slot.radius,
                          onTap: () =>
                              _handleCardTap(card.page, card.songIndex),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _RecentFlowSlot _slotForOffset(
    double offset,
    _RecentFlowMetrics metrics, {
    required double pageMotion,
  }) {
    final focus = _RecentFlowSlot(
      x: 0,
      width: metrics.fullWidth,
      opacity: 1,
      radius: 20,
      focusAmount: 1,
    );
    final firstCapsule = _RecentFlowSlot(
      x: metrics.firstCapsuleX,
      width: metrics.firstCapsuleWidth,
      opacity: 1,
      radius: metrics.pillRadius,
      focusAmount: 0,
    );
    final secondCapsule = _RecentFlowSlot(
      x: metrics.secondCapsuleX,
      width: metrics.secondCapsuleWidth,
      opacity: 1,
      radius: metrics.pillRadius,
      focusAmount: 0,
    );
    final offRight = _RecentFlowSlot(
      x: metrics.viewportWidth + metrics.gap,
      width: metrics.secondCapsuleWidth,
      opacity: 0,
      radius: metrics.pillRadius,
      focusAmount: 0,
    );
    final offLeft = _RecentFlowSlot(
      x: -metrics.fullWidth - metrics.gap,
      width: metrics.fullWidth,
      opacity: 0,
      radius: 20,
      focusAmount: 0,
    );

    if (offset <= -1) return offLeft;
    if (offset <= 0) {
      return _RecentFlowSlot.lerp(offLeft, focus, offset + 1);
    }
    if (offset <= 1) {
      final slot = _RecentFlowSlot.lerp(focus, firstCapsule, offset);
      if (slot.focusAmount <= 0.001) return slot;
      final isShrinkingToCapsule = pageMotion < 0;
      return isShrinkingToCapsule ? slot : slot.copyWith(radius: focus.radius);
    }
    if (offset <= 2) {
      return _RecentFlowSlot.lerp(firstCapsule, secondCapsule, offset - 1);
    }
    if (offset <= 3) {
      return _RecentFlowSlot.lerp(secondCapsule, offRight, offset - 2);
    }
    return offRight;
  }
}

class _RecentFlowMetrics {
  final double viewportWidth;
  final double height;
  final double gap;
  final double fullWidth;
  final double firstCapsuleWidth;
  final double secondCapsuleWidth;

  const _RecentFlowMetrics({
    required this.viewportWidth,
    required this.height,
    required this.gap,
    required this.fullWidth,
    required this.firstCapsuleWidth,
    required this.secondCapsuleWidth,
  });

  factory _RecentFlowMetrics.forSize({
    required double viewportWidth,
    required double height,
  }) {
    const gap = 12.0;
    final fullWidth = min(height, viewportWidth * 0.62);
    final secondCapsuleWidth = min(48.0, max(30.0, viewportWidth * 0.11));
    final firstCapsuleWidth = min(
      96.0,
      max(36.0, viewportWidth - fullWidth - secondCapsuleWidth - gap * 2),
    );

    return _RecentFlowMetrics(
      viewportWidth: viewportWidth,
      height: height,
      gap: gap,
      fullWidth: fullWidth,
      firstCapsuleWidth: firstCapsuleWidth,
      secondCapsuleWidth: secondCapsuleWidth,
    );
  }

  double get firstCapsuleX => fullWidth + gap;
  double get secondCapsuleX => firstCapsuleX + firstCapsuleWidth + gap;
  double get pillRadius => height / 2;
}

class _RecentFlowSlot {
  final double x;
  final double width;
  final double opacity;
  final double radius;
  final double focusAmount;

  const _RecentFlowSlot({
    required this.x,
    required this.width,
    required this.opacity,
    required this.radius,
    required this.focusAmount,
  });

  _RecentFlowSlot copyWith({double? radius}) {
    return _RecentFlowSlot(
      x: x,
      width: width,
      opacity: opacity,
      radius: radius ?? this.radius,
      focusAmount: focusAmount,
    );
  }

  static _RecentFlowSlot lerp(_RecentFlowSlot a, _RecentFlowSlot b, double t) {
    final clampedT = t.clamp(0.0, 1.0).toDouble();
    return _RecentFlowSlot(
      x: _lerp(a.x, b.x, clampedT),
      width: _lerp(a.width, b.width, clampedT),
      opacity: _lerp(a.opacity, b.opacity, clampedT),
      radius: _lerp(a.radius, b.radius, clampedT),
      focusAmount: _lerp(a.focusAmount, b.focusAmount, clampedT),
    );
  }
}

class _PositionedRecentCard {
  final int page;
  final int songIndex;
  final Song song;
  final _RecentFlowSlot slot;

  const _PositionedRecentCard({
    required this.page,
    required this.songIndex,
    required this.song,
    required this.slot,
  });
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _RecentCard extends StatelessWidget {
  final Song song;
  final String coverUrl;
  final VoidCallback onTap;
  final double focusAmount;
  final double borderRadius;

  const _RecentCard({
    required this.song,
    required this.coverUrl,
    required this.onTap,
    required this.focusAmount,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final contentOpacity = Curves.easeOut.transform(
      focusAmount.clamp(0.0, 1.0).toDouble(),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _RecentCardImage(song: song, coverUrl: coverUrl),
            if (contentOpacity > 0.02)
              Opacity(
                opacity: contentOpacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x14000000),
                        Color(0xB8000000),
                      ],
                      stops: [0.42, 0.68, 1],
                    ),
                  ),
                ),
              ),
            if (contentOpacity > 0.04)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Opacity(
                  opacity: contentOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: context.textTitleMedium.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.16,
                          shadows: const [
                            Shadow(
                              blurRadius: 12,
                              color: Color(0xAA000000),
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _songSubtitle(song),
                        style: context.textBodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _songSubtitle(Song song) {
    if (song.artist.isEmpty) return song.album;
    if (song.album.isEmpty) return song.artist;
    return '${song.artist} · ${song.album}';
  }
}

class _RecentCardImage extends StatelessWidget {
  final Song song;
  final String coverUrl;

  const _RecentCardImage({required this.song, required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    if (coverUrl.isEmpty) return const _RecentCardPlaceholder();

    return CachedDiskImage(
      imageUrl: coverUrl,
      cacheKey: song.coverArt,
      fit: BoxFit.cover,
      decodeWidth: MediaQuery.sizeOf(context).width * 0.65,
      placeholderBuilder: (_) => const _RecentCardPlaceholder(),
      errorBuilder: (_, _) => const _RecentCardPlaceholder(),
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 120),
    );
  }
}

class _RecentCardPlaceholder extends StatelessWidget {
  const _RecentCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.surfaceHighlightColor, context.surfaceColor],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 52,
          color: context.secondaryColor.withValues(alpha: 0.54),
        ),
      ),
    );
  }
}

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
