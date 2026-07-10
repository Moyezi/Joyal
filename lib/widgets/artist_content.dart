import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../screens/album_detail_screen.dart';
import '../services/subsonic_api.dart';
import 'album_cover.dart';
import 'cached_disk_image.dart';
import 'song_actions_sheet.dart';
import 'song_tile.dart';

class ArtistContent extends ConsumerStatefulWidget {
  final Artist? artist;
  final List<Album> albums;
  final List<Song> songs;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const ArtistContent({
    super.key,
    this.artist,
    this.albums = const [],
    this.songs = const [],
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  @override
  ConsumerState<ArtistContent> createState() => _ArtistContentState();
}

class _ArtistContentState extends ConsumerState<ArtistContent>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artistName = widget.artist?.name ?? '';
    final avatarUrl = widget.artist?.avatarUrl;
    final api = ref.watch(subsonicApiProvider);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(child: _buildHeader(artistName, avatarUrl)),
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(tabController: _tabController),
            ),
          ),
        ];
      },
      body: _buildTabContent(api),
    );
  }

  Widget _buildHeader(String artistName, String? avatarUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          // Avatar
          _ArtistAvatar(
            avatarUrl: avatarUrl,
            initial: widget.artist?.initial ?? '?',
          ),
          const SizedBox(height: 16),
          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              artistName.isNotEmpty ? artistName : '未知艺人',
              style: context.textHeadlineMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTabContent(SubsonicApi? api) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.secondaryText,
            ),
            const SizedBox(height: 12),
            const Text('加载失败，请重试', style: TextStyle()),
            const SizedBox(height: 16),
            if (widget.onRetry != null)
              ElevatedButton(
                onPressed: widget.onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: const Text('重试'),
              ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _AlbumsTab(albums: widget.albums, api: api),
        _SongsTab(songs: widget.songs),
      ],
    );
  }
}

// ── Avatar ──

class _ArtistAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;

  const _ArtistAvatar({required this.avatarUrl, required this.initial});

  @override
  Widget build(BuildContext context) {
    const double size = 120;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CachedDiskImage(
            imageUrl: avatarUrl!,
            cacheKey: stableImageCacheKey('artist_avatar', avatarUrl!),
            fit: BoxFit.cover,
            decodeWidth: size,
            placeholderBuilder: (ctx) => _buildInitial(initial, size, ctx),
            errorBuilder: (ctx, error) => _buildInitial(initial, size, ctx),
          ),
        ),
      );
    }

    return _buildInitial(initial, size, context);
  }

  Widget _buildInitial(String initial, double size, BuildContext ctx) {
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
          fontSize: 42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Tab Bar Delegate ──

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;

  const _TabBarDelegate({required this.tabController});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: context.backgroundColor,
      child: TabBar(
        controller: tabController,
        labelColor: context.primaryColor,
        unselectedLabelColor: context.secondaryColor,
        indicatorColor: context.primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        labelStyle: context.textTitleMedium,
        unselectedLabelStyle: context.textTitleMedium.copyWith(
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: '专辑'),
          Tab(text: '歌曲'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 46;

  @override
  double get minExtent => 46;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabController != oldDelegate.tabController;
  }
}

// ── Albums Tab ──

class _AlbumsTab extends StatelessWidget {
  final List<Album> albums;
  final SubsonicApi? api;

  const _AlbumsTab({required this.albums, required this.api});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return Center(child: Text('暂无专辑', style: context.textBodyLarge));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    const crossAxisCount = 2;
    const padding = 16.0;
    const spacing = 12.0;
    final availableWidth =
        screenWidth - padding * 2 - spacing * (crossAxisCount - 1);
    final itemWidth = availableWidth / crossAxisCount;
    final itemHeight = itemWidth * 1.3;

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: spacing,
              childAspectRatio: itemWidth / itemHeight,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final album = albums[index];
              final coverUrl = api == null || album.coverArt.isEmpty
                  ? ''
                  : api!.getCoverArtUrl(album.coverArt);

              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlbumDetailScreen(album: album),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        child: AlbumCover(
                          coverArtUrl: coverUrl,
                          cacheKey: album.coverArt,
                          size: itemWidth,
                          borderRadius: AppTheme.radiusMedium,
                          showShadow: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      album.name,
                      style: context.textBodyMedium.copyWith(
                        color: context.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album.year != null)
                      Text('${album.year}', style: context.textCaption),
                  ],
                ),
              );
            }, childCount: albums.length),
          ),
        ),
      ],
    );
  }
}

// ── Songs Tab ──

class _SongsTab extends ConsumerWidget {
  final List<Song> songs;

  const _SongsTab({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return Center(child: Text('暂无歌曲', style: context.textBodyLarge));
    }

    final currentSongId = ref.watch(
      playerProvider.select((state) => state.currentSong?.id),
    );
    final starredIds = ref.watch(
      libraryProvider.select(
        (value) => value.starredSongs.map((s) => s.id).toSet(),
      ),
    );
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(8, 12, 8, bottomPadding),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = songs[index];
              final isCurrentSong = currentSongId == song.id;
              final isStarred = starredIds.contains(song.id);

              return SongTile(
                song: song,
                index: index,
                isPlaying: isCurrentSong,
                onTap: () {
                  ref
                      .read(playerProvider.notifier)
                      .playPlaylist(songs, startIndex: index);
                },
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
            }, childCount: songs.length),
          ),
        ),
      ],
    );
  }
}
