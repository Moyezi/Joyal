import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lpinyin/lpinyin.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/music_classification.dart';
import '../models/song.dart';
import '../providers/auth_provider.dart';
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

enum _LibrarySongSortField {
  addedAt('按添加时间排序'),
  language('歌曲语言排序'),
  title('按歌曲名排序'),
  artist('按艺术家排序');

  const _LibrarySongSortField(this.label);

  final String label;
}

enum _LibrarySortDirection {
  ascending('正序'),
  descending('倒序');

  const _LibrarySortDirection(this.label);

  final String label;
}

class _LibrarySongSort {
  final _LibrarySongSortField field;
  final _LibrarySortDirection direction;

  const _LibrarySongSort({required this.field, required this.direction});

  static const fallback = _LibrarySongSort(
    field: _LibrarySongSortField.title,
    direction: _LibrarySortDirection.ascending,
  );

  String get storageValue => '${field.name}:${direction.name}';
  String get label => '${field.label} · ${direction.label}';

  bool sameAs(_LibrarySongSort other) {
    return field == other.field && direction == other.direction;
  }

  static _LibrarySongSort fromStorageValue(String? value) {
    if (value == null || value.isEmpty) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final field = _enumByName(_LibrarySongSortField.values, parts[0]);
    final direction = _enumByName(_LibrarySortDirection.values, parts[1]);
    if (field == null || direction == null) return fallback;
    return _LibrarySongSort(field: field, direction: direction);
  }

  static T? _enumByName<T extends Enum>(List<T> values, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

class LibraryScreen extends ConsumerStatefulWidget {
  final ValueListenable<int>? tabRequest;
  final Listenable? visibilityRequest;

  const LibraryScreen({super.key, this.tabRequest, this.visibilityRequest});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const double _topBarHeight = 76;
  static const double _tabBarHeight = 48;
  static const double _headerHeight = _topBarHeight + _tabBarHeight;
  static const double _songExtent = 72;
  static const int _songPageSize = 50;
  static const String _sortStorageKey = 'library_song_sort';

  late final TabController _tabController;
  late final Animation<double> _libraryTabAnimation;
  final ScrollController _songsController = ScrollController();
  final ScrollController _albumsController = ScrollController();
  final ValueNotifier<_LibraryScrollDirection> _songsScrollDirection =
      ValueNotifier(_LibraryScrollDirection.down);
  final ValueNotifier<_LibraryScrollDirection> _albumsScrollDirection =
      ValueNotifier(_LibraryScrollDirection.down);
  final ValueNotifier<int> _cardVisibilityRequest = ValueNotifier<int>(0);
  bool _isRefreshing = false;
  _LibrarySongSort _songSort = _LibrarySongSort.fallback;
  List<Song>? _sortedSongsSource;
  Map<String, SongClassification>? _sortedSongsClassifications;
  _LibrarySongSort? _sortedSongsSort;
  List<Song> _sortedSongsCache = const [];
  int _visibleSongCount = _songPageSize;
  int _lastSettledLibraryTab = 0;

  double _topBarExtent(BuildContext context) =>
      _headerHeight + MediaQuery.viewPaddingOf(context).top;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _libraryTabAnimation = _tabController.animation!;
    _lastSettledLibraryTab = _tabController.index;
    _tabController.addListener(_handleLibraryTabStateChanged);
    _libraryTabAnimation.addListener(_handleLibraryTabAnimationTick);
    _songsController.addListener(_handleSongsScroll);
    _albumsController.addListener(_handleAlbumsScroll);
    widget.tabRequest?.addListener(_handleTabRequest);
    widget.visibilityRequest?.addListener(_handlePageVisibilityRequest);
    unawaited(_loadSongSort());
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabRequest != widget.tabRequest) {
      oldWidget.tabRequest?.removeListener(_handleTabRequest);
      widget.tabRequest?.addListener(_handleTabRequest);
    }
    if (oldWidget.visibilityRequest != widget.visibilityRequest) {
      oldWidget.visibilityRequest?.removeListener(_handlePageVisibilityRequest);
      widget.visibilityRequest?.addListener(_handlePageVisibilityRequest);
    }
  }

  @override
  void dispose() {
    widget.tabRequest?.removeListener(_handleTabRequest);
    widget.visibilityRequest?.removeListener(_handlePageVisibilityRequest);
    _libraryTabAnimation.removeListener(_handleLibraryTabAnimationTick);
    _tabController.removeListener(_handleLibraryTabStateChanged);
    _tabController.dispose();
    _songsController.removeListener(_handleSongsScroll);
    _albumsController.removeListener(_handleAlbumsScroll);
    _songsController.dispose();
    _albumsController.dispose();
    _songsScrollDirection.dispose();
    _albumsScrollDirection.dispose();
    _cardVisibilityRequest.dispose();
    super.dispose();
  }

  void _handlePageVisibilityRequest() {
    _cardVisibilityRequest.value++;
  }

  void _handleLibraryTabAnimationTick() {
    final tabPosition = _libraryTabAnimation.value;
    if ((tabPosition - tabPosition.round()).abs() <= .001) return;
    _cardVisibilityRequest.value++;
  }

  void _handleLibraryTabStateChanged() {
    if (_tabController.indexIsChanging ||
        _tabController.offset.abs() > .001 ||
        _tabController.index == _lastSettledLibraryTab) {
      return;
    }
    _lastSettledLibraryTab = _tabController.index;
    _cardVisibilityRequest.value++;
  }

  void _handleTabRequest() {
    final index = widget.tabRequest?.value;
    if (index == null || index < 0 || index >= _tabController.length) return;
    if (_tabController.index == index) return;
    _tabController.animateTo(index);
  }

  void _handleSongsScroll() {
    if (!_songsController.hasClients) return;
    _updateScrollDirection(_songsController, _songsScrollDirection);
    if (_visibleSongCount >= _sortedSongsCache.length) return;
    final position = _songsController.position;
    if (position.extentAfter > _songExtent * 8) return;
    setState(() {
      _visibleSongCount = (_visibleSongCount + _songPageSize).clamp(
        0,
        _sortedSongsCache.length,
      );
    });
  }

  void _handleAlbumsScroll() {
    if (!_albumsController.hasClients) return;
    _updateScrollDirection(_albumsController, _albumsScrollDirection);
  }

  void _updateScrollDirection(
    ScrollController controller,
    ValueNotifier<_LibraryScrollDirection> direction,
  ) {
    switch (controller.position.userScrollDirection) {
      case ScrollDirection.reverse:
        direction.value = _LibraryScrollDirection.down;
      case ScrollDirection.forward:
        direction.value = _LibraryScrollDirection.up;
      case ScrollDirection.idle:
        break;
    }
  }

  Future<void> _loadSongSort() async {
    final saved = await ref
        .read(secureStorageProvider)
        .read(key: _sortStorageKey);
    if (!mounted) return;
    setState(() {
      _songSort = _LibrarySongSort.fromStorageValue(saved);
      _visibleSongCount = _songPageSize;
    });
  }

  Future<void> _locateCurrentSong() async {
    final currentSong = ref.read(playerProvider).currentSong;
    final songs = _sortedSongs(
      ref.read(libraryProvider).songs,
      ref.read(musicClassificationProvider).classifications,
    );
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
    if (index >= _visibleSongCount) {
      setState(() {
        _visibleSongCount = (index + _songPageSize).clamp(0, songs.length);
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
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

  List<Song> _sortedSongs(
    List<Song> songs,
    Map<String, SongClassification> classifications,
  ) {
    final canReuse =
        identical(_sortedSongsSource, songs) &&
        identical(_sortedSongsClassifications, classifications) &&
        _sortedSongsSort?.sameAs(_songSort) == true;
    if (canReuse) return _sortedSongsCache;

    final sorted = [...songs];
    sorted.sort((a, b) {
      final primary = switch (_songSort.field) {
        _LibrarySongSortField.addedAt => _compareByAddedAt(a, b),
        _LibrarySongSortField.language => _compareByLanguage(
          a,
          b,
          classifications,
        ),
        _LibrarySongSortField.title => _compareByTitle(a, b),
        _LibrarySongSortField.artist => _compareByArtist(a, b),
      };
      final result = _songSort.direction == _LibrarySortDirection.ascending
          ? primary
          : -primary;
      if (result != 0) return result;
      return _compareText(a.title, b.title);
    });
    final resetVisible =
        !identical(_sortedSongsSource, songs) ||
        _sortedSongsSort?.sameAs(_songSort) != true;
    _sortedSongsSource = songs;
    _sortedSongsClassifications = classifications;
    _sortedSongsSort = _songSort;
    _sortedSongsCache = sorted;
    if (resetVisible) {
      _visibleSongCount = _songPageSize;
    } else if (_visibleSongCount > sorted.length) {
      _visibleSongCount = sorted.length;
    }
    return sorted;
  }

  int _compareByAddedAt(Song a, Song b) {
    final createdA = a.created;
    final createdB = b.created;
    if (createdA != null && createdB != null) {
      final result = createdA.compareTo(createdB);
      if (result != 0) return result;
    } else if (createdA != null) {
      return -1;
    } else if (createdB != null) {
      return 1;
    }
    return _compareText(a.id, b.id);
  }

  int _compareByTitle(Song a, Song b) {
    final result = _compareText(_sortInitial(a.title), _sortInitial(b.title));
    if (result != 0) return result;
    return _compareText(a.title, b.title);
  }

  int _compareByArtist(Song a, Song b) {
    final result = _compareText(_sortInitial(a.artist), _sortInitial(b.artist));
    if (result != 0) return result;
    return _compareText(a.artist, b.artist);
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
    return _compareByTitle(a, b);
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

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<_LibrarySongSort>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LibrarySortSheet(currentSort: _songSort),
    );
    if (selected == null || !mounted || selected.sameAs(_songSort)) return;

    setState(() {
      _songSort = selected;
      _visibleSongCount = _songPageSize;
    });
    unawaited(
      ref
          .read(secureStorageProvider)
          .write(key: _sortStorageKey, value: selected.storageValue),
    );
    if (_songsController.hasClients) {
      await _songsController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
    final topBarOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(GlassEffectTarget.topBar),
      ),
    );
    final classifications = ref.watch(
      musicClassificationProvider.select((state) => state.classifications),
    );
    final sortedSongs = _sortedSongs(state.songs, classifications);
    final visibleSongs = sortedSongs
        .take(_visibleSongCount.clamp(0, sortedSongs.length))
        .toList(growable: false);
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
                  songs: visibleSongs,
                  playlist: sortedSongs,
                  controller: _songsController,
                  scrollDirection: _songsScrollDirection,
                  visibilityRequest: _cardVisibilityRequest,
                  topPadding: topBarExtent,
                ),
                _AlbumsView(
                  state: state,
                  controller: _albumsController,
                  scrollDirection: _albumsScrollDirection,
                  visibilityRequest: _cardVisibilityRequest,
                  topPadding: topBarExtent,
                ),
              ],
            ),
          ),
          GlassTopBar(
            height: _headerHeight,
            hasPageBackground: hasPageBackground,
            blurSigma: topBarBlur,
            tintOpacity: topBarOpacity,
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
                    IconButton(
                      tooltip: '排序',
                      onPressed: _showSortSheet,
                      icon: const Icon(Icons.sort_rounded),
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

class _LibrarySortSheet extends StatelessWidget {
  final _LibrarySongSort currentSort;

  const _LibrarySortSheet({required this.currentSort});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: context.surfaceColor.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.primaryColor.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.secondaryColor.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text('歌曲排序', style: context.textTitleMedium),
          const SizedBox(height: 12),
          for (final field in _LibrarySongSortField.values) ...[
            Text(
              field.label,
              style: context.textBodyMedium.copyWith(
                color: context.secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SortChoiceButton(
                    sort: _LibrarySongSort(
                      field: field,
                      direction: _LibrarySortDirection.ascending,
                    ),
                    currentSort: currentSort,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SortChoiceButton(
                    sort: _LibrarySongSort(
                      field: field,
                      direction: _LibrarySortDirection.descending,
                    ),
                    currentSort: currentSort,
                  ),
                ),
              ],
            ),
            if (field != _LibrarySongSortField.values.last)
              const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SortChoiceButton extends StatelessWidget {
  final _LibrarySongSort sort;
  final _LibrarySongSort currentSort;

  const _SortChoiceButton({required this.sort, required this.currentSort});

  @override
  Widget build(BuildContext context) {
    final selected = sort.sameAs(currentSort);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).pop(sort),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? context.primaryColor.withValues(alpha: .12)
              : context.primaryColor.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? context.primaryColor.withValues(alpha: .42)
                : context.primaryColor.withValues(alpha: .08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : sort.direction == _LibrarySortDirection.ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 17,
              color: selected ? context.primaryColor : context.secondaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              sort.direction.label,
              style: context.textBodyMedium.copyWith(
                color: selected ? context.primaryColor : context.secondaryColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  final List<Song> songs;
  final List<Song> playlist;
  final ScrollController controller;
  final ValueListenable<_LibraryScrollDirection> scrollDirection;
  final Listenable visibilityRequest;
  final double topPadding;

  const _SongsView({
    required this.state,
    required this.songs,
    required this.playlist,
    required this.controller,
    required this.scrollDirection,
    required this.visibilityRequest,
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
        return _ViewportRevealCard(
          key: ValueKey('library-song-reveal-${song.id}'),
          controller: controller,
          scrollDirection: scrollDirection,
          visibilityRequest: visibilityRequest,
          topInset: topPadding,
          hiddenScale: .82,
          child: SongTile(
            song: song,
            index: index,
            isPlaying: song.id == currentSongId,
            isDownloaded: downloadedIds.contains(song.id),
            onTap: () => ref
                .read(playerProvider.notifier)
                .playPlaylist(playlist, startIndex: index),
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
          ),
        );
      },
    );
  }
}

class _AlbumsView extends ConsumerWidget {
  final LibraryState state;
  final ScrollController controller;
  final ValueListenable<_LibraryScrollDirection> scrollDirection;
  final Listenable visibilityRequest;
  final double topPadding;

  const _AlbumsView({
    required this.state,
    required this.controller,
    required this.scrollDirection,
    required this.visibilityRequest,
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
        return _ViewportRevealCard(
          key: ValueKey('library-album-reveal-${album.id}'),
          controller: controller,
          scrollDirection: scrollDirection,
          visibilityRequest: visibilityRequest,
          topInset: topPadding,
          hiddenScale: .68,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(album: album),
              ),
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
          ),
        );
      },
    );
  }
}

enum _LibraryScrollDirection { up, down }

class _ViewportRevealCard extends StatefulWidget {
  static const double _visibilityThreshold = .15;
  static const Duration _duration = Duration(milliseconds: 520);
  static const Curve _scaleCurve = Cubic(.2, .8, .2, 1);

  final ScrollController controller;
  final ValueListenable<_LibraryScrollDirection> scrollDirection;
  final Listenable visibilityRequest;
  final double topInset;
  final double hiddenScale;
  final Widget child;

  const _ViewportRevealCard({
    super.key,
    required this.controller,
    required this.scrollDirection,
    required this.visibilityRequest,
    required this.topInset,
    required this.hiddenScale,
    required this.child,
  });

  @override
  State<_ViewportRevealCard> createState() => _ViewportRevealCardState();
}

class _ViewportRevealCardState extends State<_ViewportRevealCard> {
  bool _isVisible = false;
  bool _visibilityCheckScheduled = false;
  Alignment _scaleAlignment = Alignment.topCenter;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
    widget.visibilityRequest.addListener(_handleVisibilityRequest);
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant _ViewportRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
    if (oldWidget.visibilityRequest != widget.visibilityRequest) {
      oldWidget.visibilityRequest.removeListener(_handleVisibilityRequest);
      widget.visibilityRequest.addListener(_handleVisibilityRequest);
    }
    _scheduleVisibilityCheck();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    widget.visibilityRequest.removeListener(_handleVisibilityRequest);
    super.dispose();
  }

  void _handleScroll() => _scheduleVisibilityCheck();

  void _handleVisibilityRequest() => _scheduleVisibilityCheck();

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      _updateVisibility();
    });
  }

  void _updateVisibility() {
    if (!mounted || !widget.controller.hasClients) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final cardRect = origin & renderObject.size;
    final viewportRect = Rect.fromLTRB(
      0,
      widget.topInset,
      mediaQuery.size.width,
      mediaQuery.size.height,
    );
    final intersection = cardRect.intersect(viewportRect);
    final cardArea = cardRect.width * cardRect.height;
    final visibleArea = intersection.width <= 0 || intersection.height <= 0
        ? 0.0
        : intersection.width * intersection.height;
    final visibleFraction = cardArea <= 0 ? 0.0 : visibleArea / cardArea;

    // Match IntersectionObserver semantics: reveal after 15% enters, then keep
    // the card visible until it has completely left the usable viewport.
    final shouldBeVisible = _isVisible
        ? visibleFraction > 0
        : visibleFraction >= _ViewportRevealCard._visibilityThreshold;
    if (shouldBeVisible == _isVisible) return;

    setState(() {
      if (shouldBeVisible) {
        _scaleAlignment =
            widget.scrollDirection.value == _LibraryScrollDirection.down
            ? Alignment.topCenter
            : Alignment.bottomCenter;
      }
      _isVisible = shouldBeVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return RepaintBoundary(child: widget.child);
    }

    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: _isVisible ? 1 : 0,
        duration: _ViewportRevealCard._duration,
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _isVisible ? 1 : widget.hiddenScale,
          alignment: _scaleAlignment,
          duration: _ViewportRevealCard._duration,
          curve: _ViewportRevealCard._scaleCurve,
          child: widget.child,
        ),
      ),
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
