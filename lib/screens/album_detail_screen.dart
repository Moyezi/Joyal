import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/artist_sheet.dart';
import '../widgets/cached_disk_image.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/song_tile.dart';

/// Album / playlist detail screen.
///
/// Displays album metadata (cover, name, artist, year, song count),
/// global Play/Shuffle buttons, and the full tracklist.
class AlbumDetailScreen extends ConsumerStatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(libraryProvider.notifier).fetchAlbumSongs(widget.album.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final currentSongId = ref.watch(
      playerProvider.select((state) => state.currentSong?.id),
    );
    final album = widget.album;

    return Scaffold(
      appBar: AppBar(title: const Text('专辑详情')),
      body: _buildContent(libraryState, currentSongId, album),
    );
  }

  Widget _buildContent(
    LibraryState libraryState,
    String? currentSongId,
    Album album,
  ) {
    if (libraryState.isLoading && libraryState.albumSongs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final songs = libraryState.albumSongs;

    return ListView(
      children: [
        // ── Album header ──
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: _buildCover(album.coverArt),
                ),
              ),
              const SizedBox(width: AppTheme.spacingLG),
              // Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        '专辑',
                        if (album.year != null) '${album.year}年',
                        '${album.songCount}首歌曲',
                      ].join('  •  '),
                      style: context.textCaption,
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      album.name,
                      style: context.textHeadlineLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    GestureDetector(
                      onTap: () {
                        if (album.artistId.isNotEmpty) {
                          showArtistSheet(
                            context,
                            artistId: album.artistId,
                            artistName: album.artist,
                          );
                        }
                      },
                      child: Text(
                        album.artist,
                        style: context.textTitleMedium.copyWith(
                          color: context.secondaryColor,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Play / Shuffle buttons ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.play_arrow,
                  label: '播放全部',
                  onTap: () {
                    ref.read(playerProvider.notifier).playPlaylist(songs);
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: _ActionButton(
                  icon: Icons.shuffle,
                  label: '随机播放',
                  light: true,
                  onTap: () {
                    final shuffled = List<Song>.from(songs)..shuffle();
                    ref.read(playerProvider.notifier).playPlaylist(shuffled);
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingLG),

        // ── Tracklist ──
        if (songs.isEmpty && !libraryState.isLoading)
          const Padding(
            padding: EdgeInsets.all(AppTheme.spacingXL),
            child: Center(child: Text('暂无曲目', style: TextStyle())),
          )
        else
          ...songs.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;
            final isCurrentSong = currentSongId == song.id;
            final isStarred = libraryState.starredSongs.any(
              (s) => s.id == song.id,
            );

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
          }),

        const SizedBox(height: 100), // Space for mini player
      ],
    );
  }

  Widget _buildCover(String coverArtId) {
    final api = ref.read(subsonicApiProvider);
    if (api == null || coverArtId.isEmpty) {
      return Container(
        color: context.surfaceColor,
        child: Icon(Icons.album, size: 48, color: context.secondaryColor),
      );
    }

    return CachedDiskImage(
      imageUrl: api.getCoverArtUrl(coverArtId),
      cacheKey: coverArtId,
      fit: BoxFit.cover,
      placeholderBuilder: (ctx) => Container(
        color: context.surfaceColor,
        child: Icon(Icons.album, size: 48, color: context.secondaryColor),
      ),
      errorBuilder: (ctx, error) => Container(
        color: context.surfaceColor,
        child: Icon(Icons.album, size: 48, color: context.secondaryColor),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool light;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? context.surfaceColor
              : (light ? context.surfaceColor : context.primaryColor),
          foregroundColor: isDark
              ? context.primaryColor
              : (light ? context.primaryColor : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
