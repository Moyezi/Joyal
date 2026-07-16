import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_context.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/glass_effect_provider.dart';
import '../services/cache_repository.dart';
import '../screens/artist_detail_screen.dart';
import '../widgets/album_cover.dart';
import '../widgets/cached_disk_image.dart';
import '../widgets/frosted_glass.dart';
import 'album_detail_screen.dart';
import 'now_playing_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final Animation<double>? transitionAnimation;
  final Rect? sourceRect;

  const SearchScreen({super.key, this.transitionAnimation, this.sourceRect})
    : assert(transitionAnimation == null || sourceRect != null);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic> _results = {};
  bool _isSearching = false;
  bool _hasSearched = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final cacheRepo = ref.read(cacheRepositoryProvider);
    final history = await cacheRepo.loadSearchHistory();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = {};
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 420), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    final cacheRepo = ref.read(cacheRepositoryProvider);
    unawaited(cacheRepo.addToSearchHistory(query));
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    // 1. Try disk cache first.
    final cached = await cacheRepo.loadSearchResult(query);
    if (cached != null && mounted && query == _controller.text.trim()) {
      setState(() {
        _results = _deserializeSearchResult(cached);
        _isSearching = false;
      });
      return;
    }

    // 2. Fetch from network.
    final results = await ref.read(libraryProvider.notifier).search(query);
    if (!mounted || query != _controller.text.trim()) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });

    // 3. Persist.
    unawaited(cacheRepo.saveSearchResult(query, _serializeResults(results)));
  }

  Map<String, dynamic> _serializeResults(Map<String, dynamic> results) => {
    'artists': results['artists'],
    'albums': (results['albums'] as List<dynamic>? ?? [])
        .map((a) => (a as dynamic).toJson())
        .toList(),
    'songs': (results['songs'] as List<dynamic>? ?? [])
        .map((s) => (s as dynamic).toJson())
        .toList(),
  };

  Map<String, dynamic> _deserializeSearchResult(Map<String, dynamic> json) => {
    'artists': json['artists'] ?? [],
    'albums': (json['albums'] as List<dynamic>? ?? [])
        .map((j) => Album.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList(),
    'songs': (json['songs'] as List<dynamic>? ?? [])
        .map((j) => Song.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList(),
  };

  void _useHistory(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _search();
  }

  Future<void> _clearHistory() async {
    final cacheRepo = ref.read(cacheRepositoryProvider);
    await cacheRepo.saveSearchHistory([]);
    setState(() => _history = []);
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final animation =
        widget.transitionAnimation ?? const AlwaysStoppedAnimation<double>(1);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final rawProgress = animation.value.clamp(0.0, 1.0);
          final isReversing = animation.status == AnimationStatus.reverse;
          final size = MediaQuery.sizeOf(context);
          final finalRect = Rect.fromLTWH(
            24,
            MediaQuery.viewPaddingOf(context).top + 10,
            math.max(0, size.width - 48),
            54,
          );
          final sourceRect = widget.sourceRect ?? finalRect;
          final fieldProgress = isReversing
              ? Curves.easeInOutCubic.transform(rawProgress)
              : Curves.easeOutCubic.transform(
                  (rawProgress / .74).clamp(0.0, 1.0),
                );
          final backgroundProgress = Curves.easeOutCubic.transform(
            ((rawProgress - .04) / .36).clamp(0.0, 1.0),
          );
          final chromeProgress = isReversing
              ? Curves.easeInCubic.transform(
                  ((rawProgress - .82) / .18).clamp(0.0, 1.0),
                )
              : Curves.easeOut.transform(
                  (rawProgress / .14).clamp(0.0, 1.0),
                );
          final contentProgress = Curves.easeOutCubic.transform(
            ((rawProgress - .56) / .44).clamp(0.0, 1.0),
          );
          final fieldRect = Rect.lerp(sourceRect, finalRect, fieldProgress)!;

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: context.backgroundColor.withValues(
                  alpha: backgroundProgress,
                ),
              ),
              Positioned(
                top: finalRect.bottom + 12,
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: contentProgress < .99,
                  child: Opacity(
                    opacity: contentProgress,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - contentProgress)),
                      child: _buildResults(),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: fieldRect,
                child: _buildSearchField(
                  rawProgress,
                  chromeOpacity: chromeProgress,
                  blurSigma: blurSigma,
                  tintOpacity: tintOpacity,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField(
    double transitionProgress, {
    required double chromeOpacity,
    required double blurSigma,
    required double tintOpacity,
  }) {
    final surfaceProgress = Curves.easeOut.transform(
      (transitionProgress / .24).clamp(0.0, 1.0),
    );

    return FrostedGlass(
      blurSigma: blurSigma * surfaceProgress,
      borderRadius: BorderRadius.circular(18),
      tintColor: context.surfaceColor,
      tintOpacity: tintOpacity * surfaceProgress,
      borderColor: context.primaryColor,
      borderOpacity: 0,
      liquidGlassIntensityScale: surfaceProgress,
      child: Opacity(
        opacity: chromeOpacity,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: context.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _search(),
                    style: context.textBodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: '搜索歌曲、专辑或艺人',
                      hintStyle: context.textBodyMedium,
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  SizedBox(
                    width: 40,
                    height: 54,
                    child: IconButton(
                      tooltip: '清空',
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
                SizedBox(
                  width: 44,
                  height: 54,
                  child: IconButton(
                    tooltip: '返回',
                    padding: EdgeInsets.zero,
                    onPressed: _closeSearch,
                    icon: Transform.rotate(
                      angle: math.pi * transitionProgress,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: context.secondaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!_hasSearched) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        children: [
          if (_history.isNotEmpty) ...[
            Row(
              children: [
                Expanded(child: Text('搜索历史', style: context.textTitleLarge)),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('清除'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.secondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _history
                  .map(
                    (query) => ActionChip(
                      onPressed: () => _useHistory(query),
                      avatar: const Icon(Icons.history_rounded, size: 17),
                      label: Text(query),
                      backgroundColor: context.surfaceColor,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 54),
          ],
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? context.surfaceColor
                        : context.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? context.primaryColor
                        : Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text('搜点什么吧', style: context.textHeadlineMedium),
                const SizedBox(height: 7),
                Text(
                  '从你的音乐库中寻找歌曲、专辑和艺人',
                  textAlign: TextAlign.center,
                  style: context.textBodyMedium,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final albums = (_results['albums'] as List<dynamic>?) ?? [];
    final songs = ((_results['songs'] as List<dynamic>?) ?? []).cast<Song>();
    final artists = (_results['artists'] as List<dynamic>?) ?? [];

    if (artists.isEmpty && albums.isEmpty && songs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: context.secondaryColor,
              ),
              SizedBox(height: 14),
              Text('没有找到相关音乐', style: context.textTitleMedium),
              SizedBox(height: 6),
              Text('换个关键词试试看', style: context.textBodyMedium),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (artists.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            sliver: SliverToBoxAdapter(child: _SectionHeader(title: '艺人')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ArtistResultRow(
                  artist: artists[index] as Map<String, dynamic>,
                ),
                childCount: artists.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        if (albums.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _SectionHeader(title: '专辑')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _AlbumResultRow(album: albums[index] as Album),
                childCount: albums.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        if (songs.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _SectionHeader(title: '歌曲')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SongResultRow(
                  song: songs[index],
                  queue: songs,
                  index: index,
                ),
                childCount: songs.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Text(title, style: context.textTitleLarge),
    );
  }
}

class _AlbumResultRow extends ConsumerWidget {
  final Album album;

  const _AlbumResultRow({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = api == null || album.coverArt.isEmpty
        ? ''
        : api.getCoverArtUrl(album.coverArt);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AlbumCover(
        coverArtUrl: coverUrl,
        cacheKey: album.coverArt,
        size: 52,
        borderRadius: 12,
        showShadow: false,
      ),
      title: Text(album.name, style: context.textTitleMedium),
      subtitle: Text(album.artist, style: context.textBodyMedium),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
      ),
    );
  }
}

class _SongResultRow extends ConsumerWidget {
  final Song song;
  final List<Song> queue;
  final int index;

  const _SongResultRow({
    required this.song,
    required this.queue,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = api == null || song.coverArt.isEmpty
        ? ''
        : api.getCoverArtUrl(song.coverArt);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipOval(
        child: AlbumCover(
          coverArtUrl: coverUrl,
          cacheKey: song.coverArt,
          size: 52,
          borderRadius: 26,
          showShadow: false,
        ),
      ),
      title: Text(song.title, style: context.textTitleMedium),
      subtitle: Text(
        '${song.artist}  ·  ${song.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textBodyMedium,
      ),
      trailing: Text(song.formattedDuration, style: context.textCaption),
      onTap: () async {
        await ref
            .read(playerProvider.notifier)
            .playPlaylist(queue, startIndex: index);
        if (!context.mounted) return;
        FocusScope.of(context).unfocus();
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
      },
    );
  }
}

class _ArtistResultRow extends ConsumerWidget {
  final Map<String, dynamic> artist;

  const _ArtistResultRow({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = artist['name'] as String? ?? '未知艺人';
    final initial = name.isNotEmpty ? name.characters.first : '?';
    final imageUrl = artist['artistImageUrl'] as String?;
    final coverArtId = artist['coverArt'] as String?;
    final api = ref.watch(subsonicApiProvider);

    // Build the avatar URL: prefer direct imageUrl, then coverArt via API.
    String? avatarUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarUrl = imageUrl;
    } else if (coverArtId != null && coverArtId.isNotEmpty && api != null) {
      avatarUrl = api.getCoverArtUrl(coverArtId);
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _SearchArtistAvatar(
        avatarUrl: avatarUrl,
        cacheKey: coverArtId != null && coverArtId.isNotEmpty
            ? 'artist_cover_$coverArtId'
            : avatarUrl == null
            ? null
            : stableImageCacheKey('search_artist', avatarUrl),
        initial: initial,
        size: 50,
      ),
      title: Text(name, style: context.textTitleMedium),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.secondaryColor,
      ),
      onTap: () {
        final id = artist['id'] as String?;
        if (id == null || id.isEmpty || name == '未知艺人') return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artistId: id, artistName: name),
          ),
        );
      },
    );
  }
}

class _SearchArtistAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? cacheKey;
  final String initial;
  final double size;

  const _SearchArtistAvatar({
    required this.avatarUrl,
    required this.cacheKey,
    required this.initial,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CachedDiskImage(
            imageUrl: avatarUrl!,
            cacheKey:
                cacheKey ?? stableImageCacheKey('search_artist', avatarUrl!),
            fit: BoxFit.cover,
            decodeWidth: size,
            placeholderBuilder: (ctx) => _buildInitial(ctx),
            errorBuilder: (ctx, error) => _buildInitial(ctx),
          ),
        ),
      );
    }
    return _buildInitial(context);
  }

  Widget _buildInitial(BuildContext ctx) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ctx.surfaceColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: ctx.primaryColor,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
