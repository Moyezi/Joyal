import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    super.build(context);
    final state = ref.watch(libraryProvider);
    final classification = ref.watch(musicClassificationProvider);
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
      body: Stack(
        children: [
          const Positioned.fill(
            child: PageCustomBackground(target: PageBackgroundTarget.favorites),
          ),
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
                        if (discoverSongs.isNotEmpty)
                          SizedBox(
                            height: _discoverCarouselHeight,
                            child: _DiscoverSongCarousel(
                              songs: discoverSongs,
                              controller: _carouselController,
                            ),
                          ),
                        _SectionHeader(title: '收藏歌曲'),
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
                        _ForYouDiscoverySection(
                          allSongs: state.songs,
                          starredSongs: starredSongs,
                        ),
                        _ClassificationStatusCard(
                          statusText: _classificationStatusText(
                            classification,
                            state.songs.length,
                          ),
                          detailText: _classificationDetailText(
                            classification,
                            state.songs.length,
                          ),
                          progress: classification.progress,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MusicClassificationScreen(),
                            ),
                          ),
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
                IconButton(
                  tooltip: '搜索',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: '智能分类状态',
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

  String _classificationStatusText(
    MusicClassificationState state,
    int songCount,
  ) {
    if (!state.hasApiKey) return '智能分类尚未开始';
    return switch (state.status) {
      ClassificationTaskStatus.running => '正在整理你的曲库',
      ClassificationTaskStatus.paused => '分类任务已暂停',
      ClassificationTaskStatus.completed => '曲库分类已完成',
      ClassificationTaskStatus.failed => '分类任务需要处理',
      ClassificationTaskStatus.idle =>
        state.classifiedCount == 0 ? '智能分类尚未开始' : '智能分类已准备好',
    };
  }

  String _classificationDetailText(
    MusicClassificationState state,
    int songCount,
  ) {
    if (!state.hasApiKey) {
      return '配置 DeepSeek API 后，为曲库生成流派、情绪和场景分类。';
    }
    if (state.status == ClassificationTaskStatus.running ||
        state.status == ClassificationTaskStatus.paused) {
      return '已完成 ${state.completedCount} / ${state.totalCount} 首';
    }
    if (state.classifiedCount == 0) {
      return '还有 $songCount 首歌曲等待分类。';
    }
    return '已为 ${state.classifiedCount} 首歌曲生成本地分类标签。';
  }
}

class _DiscoverSongCarousel extends ConsumerStatefulWidget {
  final List<Song> songs;
  final PageController controller;

  const _DiscoverSongCarousel({required this.songs, required this.controller});

  @override
  ConsumerState<_DiscoverSongCarousel> createState() =>
      _DiscoverSongCarouselState();
}

class _ForYouDiscoverySection extends ConsumerStatefulWidget {
  final List<Song> allSongs;
  final List<Song> starredSongs;

  const _ForYouDiscoverySection({
    required this.allSongs,
    required this.starredSongs,
  });

  @override
  ConsumerState<_ForYouDiscoverySection> createState() =>
      _ForYouDiscoverySectionState();
}

class _ForYouDiscoverySectionState
    extends ConsumerState<_ForYouDiscoverySection> {
  int? _cacheKey;
  List<Song>? _cachedAllSongs;
  List<Song>? _cachedStarredSongs;
  Map<String, SongClassification>? _cachedClassifications;
  List<_DiscoveryCardData> _cachedCards = const [];

  @override
  Widget build(BuildContext context) {
    if (widget.allSongs.isEmpty) return const SizedBox.shrink();
    final classifier = ref.watch(musicClassificationProvider);
    final cards = _cardsFor(classifier);

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: '为你发现'),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            itemCount: cards.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppTheme.spacingSM),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _DiscoveryPlaylistCard(
                data: card,
                enabled:
                    classifier.classifiedCount > 0 ||
                    card.title == '被遗忘的收藏' ||
                    card.title == '随机漫游',
              );
            },
          ),
        ),
      ],
    );
  }

  List<_DiscoveryCardData> _cardsFor(MusicClassificationState classifier) {
    final seed = _todaySeed(31);
    final classifications = classifier.classifications;
    final canReuse =
        _cacheKey == seed &&
        identical(_cachedAllSongs, widget.allSongs) &&
        identical(_cachedStarredSongs, widget.starredSongs) &&
        identical(_cachedClassifications, classifications);
    if (canReuse) return _cachedCards;

    final notifier = ref.read(musicClassificationProvider.notifier);
    final cards = <_DiscoveryCardData>[
      _DiscoveryCardData(
        title: '深夜独处',
        subtitle: '平静 · 忧郁 · 低能量',
        songs: notifier.songsForTag(widget.allSongs, '深夜').take(24).toList(),
      ),
      _DiscoveryCardData(
        title: '清晨轻听',
        subtitle: '清晨 · 轻松 · 治愈',
        songs: notifier.songsForTag(widget.allSongs, '清晨').take(24).toList(),
      ),
      _DiscoveryCardData(
        title: '被遗忘的收藏',
        subtitle: '从收藏里重新听见',
        songs: widget.starredSongs.take(24).toList(),
      ),
      _DiscoveryCardData(
        title: '随机漫游',
        subtitle: '今天随机抽取的曲库片段',
        songs: _stableShuffle(widget.allSongs, seed).take(24).toList(),
      ),
    ].where((card) => card.songs.isNotEmpty).toList();

    _cacheKey = seed;
    _cachedAllSongs = widget.allSongs;
    _cachedStarredSongs = widget.starredSongs;
    _cachedClassifications = classifications;
    _cachedCards = cards;
    return _cachedCards;
  }

  static int _todaySeed(int offset) {
    final today = DateTime.now();
    return today.year * 10000 + today.month * 100 + today.day + offset;
  }

  static List<Song> _stableShuffle(List<Song> songs, int seed) {
    return [...songs]..shuffle(Random(seed));
  }
}

class _DiscoveryCardData {
  final String title;
  final String subtitle;
  final List<Song> songs;

  const _DiscoveryCardData({
    required this.title,
    required this.subtitle,
    required this.songs,
  });
}

class _DiscoveryPlaylistCard extends ConsumerWidget {
  final _DiscoveryCardData data;
  final bool enabled;

  const _DiscoveryPlaylistCard({required this.data, required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 188,
      child: Material(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: !enabled
              ? null
              : () => PlayQueueSheet.show(
                  context,
                  title: data.title,
                  songs: data.songs,
                  onSongTap: (index) => ref
                      .read(playerProvider.notifier)
                      .playPlaylist(data.songs, startIndex: index),
                ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: context.primaryColor,
                ),
                const Spacer(),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTitleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${data.songs.length} 首歌曲 · ${data.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textBodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassificationStatusCard extends StatelessWidget {
  final String statusText;
  final String detailText;
  final double progress;
  final VoidCallback onTap;

  const _ClassificationStatusCard({
    required this.statusText,
    required this.detailText,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingLG,
        AppTheme.spacingMD,
        0,
      ),
      child: Material(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: context.primaryColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText, style: context.textTitleMedium),
                      const SizedBox(height: 3),
                      Text(
                        detailText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textBodySmall,
                      ),
                      if (progress > 0 && progress < 1) ...[
                        const SizedBox(height: AppTheme.spacingSM),
                        LinearProgressIndicator(value: progress),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverSongCarouselState extends ConsumerState<_DiscoverSongCarousel> {
  int _currentIndex = 0;

  int _realIndexForPage(int page) {
    final length = widget.songs.length;
    if (length == 0) return 0;
    return (page % length + length) % length;
  }

  void _dragBy(double delta) {
    if (widget.songs.length <= 1 || !widget.controller.hasClients) return;
    final pixels = max(0.0, widget.controller.position.pixels - delta);
    widget.controller.jumpTo(pixels);
  }

  void _settleByVelocity(double velocity) {
    if (widget.songs.length <= 1 || !widget.controller.hasClients) return;
    final page =
        widget.controller.page ?? widget.controller.initialPage.toDouble();
    final speed = velocity.abs();
    final direction = velocity < 0
        ? 1
        : velocity > 0
        ? -1
        : 0;
    final pages = speed < 180 ? 0 : (speed / 1000).ceil().clamp(1, 3);
    if (pages > 0) {
      HapticFeedback.selectionClick();
    }
    widget.controller.animateToPage(
      page.round() + direction * pages,
      duration: Duration(milliseconds: 240 + pages * 28),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.songs;
    if (songs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final page = widget.controller.hasClients
                  ? widget.controller.page ?? _currentIndex.toDouble()
                  : _currentIndex.toDouble();
              final nearest = page.round();
              final offsets = <int>[-3, -2, -1, 0, 1, 2, 3]
                ..sort((a, b) => b.abs().compareTo(a.abs()));

              return LayoutBuilder(
                builder: (context, constraints) {
                  final centerSize = constraints.maxWidth * 0.65;
                  final viewportCenter = constraints.maxWidth / 2;
                  final cardCenterY = constraints.maxHeight * 0.49;

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) =>
                        _dragBy(details.delta.dx),
                    onHorizontalDragEnd: (details) =>
                        _settleByVelocity(details.primaryVelocity ?? 0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PageView.builder(
                          controller: widget.controller,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(
                              () => _currentIndex = _realIndexForPage(index),
                            );
                          },
                          itemBuilder: (_, _) => const SizedBox.expand(),
                        ),
                        for (final offset in offsets)
                          _DepthCarouselCard(
                            songs: songs,
                            pageIndex: nearest + offset,
                            relative: offset - (page - nearest),
                            centerSize: centerSize,
                            viewportCenter: viewportCenter,
                            cardCenterY: cardCenterY,
                            controller: widget.controller,
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _DiscoverDots(count: songs.length, currentIndex: _currentIndex),
        const SizedBox(height: 2),
      ],
    );
  }
}

class _DepthCarouselCard extends ConsumerWidget {
  final List<Song> songs;
  final int pageIndex;
  final double relative;
  final double centerSize;
  final double viewportCenter;
  final double cardCenterY;
  final PageController controller;

  const _DepthCarouselCard({
    required this.songs,
    required this.pageIndex,
    required this.relative,
    required this.centerSize,
    required this.viewportCenter,
    required this.cardCenterY,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final index = (pageIndex % songs.length + songs.length) % songs.length;

    final distance = relative.abs().clamp(0.0, 3.0);
    final scale = (1 - distance * 0.14).clamp(0.56, 1.0);
    final opacity = (1 - distance * 0.22).clamp(0.34, 1.0);
    final blur = distance == 0 ? 0.0 : distance * 0.7;
    final size = centerSize * scale;
    final x = viewportCenter - size / 2 + relative * centerSize * 0.37;
    final y = cardCenterY - size / 2 + distance * 10;
    final isCenter = distance < 0.5;
    final currentSong = songs[index];
    final coverCard = _DiscoverCoverCard(
      song: currentSong,
      isCenter: isCenter,
      size: size,
      onPlay: () => ref
          .read(playerProvider.notifier)
          .playPlaylist(songs, startIndex: index),
    );
    final filteredCard = blur > 0.05
        ? ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: coverCard,
          )
        : coverCard;
    final visualCard = opacity < 0.999
        ? Opacity(opacity: opacity, child: filteredCard)
        : filteredCard;

    return Positioned(
      left: x,
      top: y,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: isCenter
            ? null
            : () => controller.animateToPage(
                pageIndex,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
        child: visualCard,
      ),
    );
  }
}

class _DiscoverCoverCard extends ConsumerWidget {
  final Song song;
  final bool isCenter;
  final double size;
  final VoidCallback onPlay;

  const _DiscoverCoverCard({
    required this.song,
    required this.isCenter,
    required this.size,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsonicApiProvider);
    final playback = ref.watch(
      playerProvider.select(
        (state) =>
            (currentSongId: state.currentSong?.id, isPlaying: state.isPlaying),
      ),
    );
    final isCurrentSong = playback.currentSongId == song.id;
    final isPlaying = isCurrentSong && playback.isPlaying;
    final coverUrl = api == null || song.coverArt.isEmpty
        ? ''
        : api.getCoverArtUrl(song.coverArt);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isCenter ? 0.24 : 0.12),
            blurRadius: isCenter ? 34 : 20,
            offset: Offset(0, isCenter ? 18 : 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AlbumCover(
            coverArtUrl: coverUrl,
            cacheKey: song.coverArt,
            size: size,
            borderRadius: 24,
            showShadow: false,
          ),
          if (isCenter) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.58),
                    ],
                    stops: const [0, 0.46, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 78,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTitleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textBodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: IconButton.filled(
                tooltip: isPlaying ? '暂停' : '播放',
                onPressed: isCurrentSong
                    ? () => ref.read(playerProvider.notifier).togglePlayPause()
                    : onPlay,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: Colors.black87,
                  fixedSize: const Size(52, 52),
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(isPlaying),
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverDots extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _DiscoverDots({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == currentIndex ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? const Color(0xFF6F63FF)
                  : const Color(0xFFD7D8DF),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingLG,
        AppTheme.spacingMD,
        AppTheme.spacingSM,
      ),
      child: Text(title, style: context.textTitleLarge),
    );
  }
}
