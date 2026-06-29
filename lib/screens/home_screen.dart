import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/album.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/album_cover.dart';
import '../widgets/glass_top_bar.dart';
import 'album_detail_screen.dart';
import 'search_screen.dart';

/// 主页 Tab – Spotify 风格的专辑浏览。
///
/// 布局：顶部问候语 → 大搜索框 → 最近添加横向滚动 → 全部专辑双列网格。
/// 向下滚动时大搜索框缩小/上移/淡出，同时顶栏右侧搜索图标淡入放大。
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(Rect)? onExclusionZoneChanged;
  const HomeScreen({super.key, this.onExclusionZoneChanged});

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

  // ━━━ Animation ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  late final AnimationController _animController;
  late final ScrollController _scrollController;
  final GlobalKey _recentListKey = GlobalKey();
  bool _exclusionRectPending = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: Duration.zero,
      vsync: this,
    );
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
    callback(Rect.fromLTWH(
      globalOffset.dx, globalOffset.dy,
      box.size.width, box.size.height,
    ));
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

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);

    // 每次重建后尝试上报排除矩形（防抖：同一帧内不重复调度）
    if (!_exclusionRectPending) {
      _exclusionRectPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _exclusionRectPending = false;
        _reportExclusionRect();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody(libraryState)),
            GlassTopBar(
              height: _headerHeight,
              searchAnimation: _animController,
              onSearchTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              child: _buildHeader(),
            ),
          ],
        ),
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
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ),
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
    if (state.isLoading && state.albums.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: _headerHeight),
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
    final recentAlbums = albums.take(6).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).fetchAlbums(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── 顶部问候 ──
          const SliverToBoxAdapter(child: SizedBox(height: _headerHeight)),
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

          // ── 全部专辑（双列网格） ──
          SliverToBoxAdapter(child: _SectionTitle(title: '全部专辑')),
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
                final a = albums[index];
                return _AlbumGridCard(
                  album: a,
                  coverUrl: _coverUrl(a.coverArt),
                );
              }, childCount: albums.length),
            ),
          ),

          // 底部留白
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: _headerHeight),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 48,
                color: context.secondaryColor,
              ),
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
        const SizedBox(height: _headerHeight),
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

class _HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: context.primaryColor),
                SizedBox(width: 12),
                Text('搜索歌曲、专辑或艺人', style: context.textBodyMedium),
                Spacer(),
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
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        AppTheme.spacingLG,
        AppTheme.spacingLG,
        AppTheme.spacingSM,
      ),
      child: Row(children: [Text(title, style: context.textTitleLarge)]),
    );
  }
}
