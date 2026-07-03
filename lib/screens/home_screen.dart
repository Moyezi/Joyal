import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/library_provider.dart';
import '../providers/page_background_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/album_cover.dart';
import '../widgets/frosted_glass.dart';
import '../widgets/glass_top_bar.dart';
import '../widgets/page_custom_background.dart';
import '../widgets/play_queue_sheet.dart';
import 'album_detail_screen.dart';
import 'search_screen.dart';

/// 主页 Tab – Spotify 风格的专辑浏览。
///
/// 布局：顶部问候语 → 大搜索框 → 最近添加横向滚动 → 随机专辑双列网格。
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
    with SingleTickerProviderStateMixin {
  // ━━━ Layout constants ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const double _headerHeight = 92;
  static const double _searchBarHeight = 54;
  static const double _searchBarTopPadding = 16;
  static const double _totalRange = _searchBarHeight + _searchBarTopPadding;
  static const double _bottomSpacerBaseHeight = 28;
  static const double _miniPlayerHeight = 104;

  // ━━━ Animation ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  late final AnimationController _animController;
  late final ScrollController _scrollController;
  final GlobalKey _recentListKey = GlobalKey();
  bool _exclusionRectPending = false;

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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final progress = (offset / _totalRange).clamp(0.0, 1.0);
    _animController.value = progress;
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
  Widget build(BuildContext context) {
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

    // 每次重建后尝试上报排除矩形（防抖：同一帧内不重复调度）
    if (!_exclusionRectPending) {
      _exclusionRectPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _exclusionRectPending = false;
        _reportExclusionRect();
      });
    }

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
    final recentAlbums = albums.take(6).toList();
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

          // ── 最近添加（横向滚动） ──
          if (recentAlbums.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionTitle(title: '最近添加')),
            SliverToBoxAdapter(
              child: SizedBox(
                key: _recentListKey,
                height: 200,
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingLG,
                    2,
                    AppTheme.spacingLG,
                    0,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: recentAlbums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final a = recentAlbums[index];
                    return _RecentCard(
                      album: a,
                      coverUrl: _coverUrl(a.coverArt),
                    );
                  },
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
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final recommended = [...songs]..shuffle(Random(seed));
    return recommended.take(24).toList();
  }

  List<Album> _dailyRandomAlbums(List<Album> albums) {
    if (albums.isEmpty) return const [];
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final randomAlbums = [...albums]..shuffle(Random(seed));
    return randomAlbums.take(8).toList();
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

// ━━━ 最近添加横向卡片 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RecentCard extends ConsumerWidget {
  final Album album;
  final String coverUrl;
  const _RecentCard({required this.album, required this.coverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 136,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumCover(
                coverArtUrl: coverUrl,
                cacheKey: album.coverArt,
                size: 136,
                borderRadius: 16,
                showShadow: false,
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                style: context.textTitleMedium.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                album.artist,
                style: context.textBodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FrostedGlass(
      blurSigma: blurSigma,
      borderRadius: BorderRadius.circular(18),
      tintColor: context.surfaceColor,
      tintOpacity: isDark ? 0.72 : 0.62,
      borderColor: context.primaryColor,
      borderOpacity: isDark ? 0.08 : 0.05,
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
