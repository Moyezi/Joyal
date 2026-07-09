import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_context.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../album_cover.dart';
import '../play_queue_sheet.dart';
import 'discovery_card_models.dart';

class DiscoveryPlaylistCard extends ConsumerStatefulWidget {
  final DiscoveryCardData data;

  const DiscoveryPlaylistCard({super.key, required this.data});

  @override
  ConsumerState<DiscoveryPlaylistCard> createState() =>
      _DiscoveryPlaylistCardState();
}

class _DiscoveryPlaylistCardState extends ConsumerState<DiscoveryPlaylistCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  void _openPlaylist() {
    final songs = widget.data.songs;
    if (songs.isEmpty) return;
    PlayQueueSheet.show(
      context,
      title: widget.data.title,
      songs: songs,
      onSongTap: (index) => ref
          .read(playerProvider.notifier)
          .playPlaylist(songs, startIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final style = data.style;
    final textColor = style.isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final subtleTextColor = style.isLight
        ? const Color(0xFF4F5665)
        : Colors.white.withValues(alpha: 0.72);
    final borderAlpha = _pressed ? 0.22 : 0.11;
    final borderColor = style.isLight
        ? style.accentColor.withValues(alpha: _pressed ? 0.34 : 0.2)
        : Colors.white.withValues(alpha: borderAlpha);
    final shadowAlpha = _pressed ? 0.24 : 0.14;
    final glowAlpha = _pressed ? 0.72 : 0.46;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openPlaylist,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 1.035 : 1,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          width: 248,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: style.gradientColors,
            ),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: shadowAlpha),
                blurRadius: _pressed ? 34 : 24,
                offset: Offset(0, _pressed ? 16 : 12),
              ),
              BoxShadow(
                color: style.glowColor.withValues(alpha: _pressed ? 0.18 : 0.1),
                blurRadius: _pressed ? 28 : 18,
                offset: const Offset(18, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: _pressed ? -22 : -32,
                  bottom: _pressed ? -24 : -34,
                  child: _DiscoveryAtmosphereLight(
                    color: style.glowColor,
                    opacity: glowAlpha,
                    size: _pressed ? 132 : 112,
                  ),
                ),
                Positioned(
                  left: -34,
                  top: -48,
                  child: _DiscoveryAtmosphereLight(
                    color: Colors.white,
                    opacity: style.isLight ? 0.38 : 0.12,
                    size: 116,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 10,
                  width: 126,
                  height: 98,
                  child: _DiscoveryAlbumStack(
                    songs: data.songs,
                    pressed: _pressed,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DiscoveryIconBadge(style: style),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTitleMedium.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textBodySmall.copyWith(
                          color: subtleTextColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryAtmosphereLight extends StatelessWidget {
  final Color color;
  final double opacity;
  final double size;

  const _DiscoveryAtmosphereLight({
    required this.color,
    required this.opacity,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.32),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.52, 1],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryIconBadge extends StatelessWidget {
  final DiscoveryCardStyle style;

  const _DiscoveryIconBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    final foreground = style.isLight
        ? const Color(0xFF1A1A1A)
        : Colors.white.withValues(alpha: 0.92);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: style.accentColor.withValues(alpha: style.isLight ? 0.16 : 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: style.isLight ? 0.34 : 0.12),
          width: 0.8,
        ),
      ),
      child: Icon(style.icon, color: foreground, size: 19),
    );
  }
}

class _DiscoveryAlbumStack extends ConsumerWidget {
  final List<Song> songs;
  final bool pressed;

  const _DiscoveryAlbumStack({required this.songs, required this.pressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final api = ref.watch(subsonicApiProvider);
    final frontSong = songs.first;
    final backSong = songs.length > 1 ? songs[1] : frontSong;
    final frontUrl = api == null || frontSong.coverArt.isEmpty
        ? ''
        : api.getCoverArtUrl(frontSong.coverArt);
    final backUrl = api == null || backSong.coverArt.isEmpty
        ? ''
        : api.getCoverArtUrl(backSong.coverArt);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          top: pressed ? 0 : 7,
          right: pressed ? 0 : 8,
          child: _StackedDiscoveryCover(
            coverArtUrl: backUrl,
            cacheKey: backSong.coverArt,
            size: 62,
            rotation: pressed ? 0.19 : 0.12,
            opacity: pressed ? 0.66 : 0.54,
            scale: pressed ? 0.93 : 0.88,
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          top: pressed ? 20 : 16,
          right: pressed ? 38 : 30,
          child: _StackedDiscoveryCover(
            coverArtUrl: frontUrl,
            cacheKey: frontSong.coverArt,
            size: 68,
            rotation: pressed ? -0.18 : -0.11,
            opacity: 1,
            scale: 1,
          ),
        ),
      ],
    );
  }
}

class _StackedDiscoveryCover extends StatelessWidget {
  final String coverArtUrl;
  final String cacheKey;
  final double size;
  final double rotation;
  final double opacity;
  final double scale;

  const _StackedDiscoveryCover({
    required this.coverArtUrl,
    required this.cacheKey,
    required this.size,
    required this.rotation,
    required this.opacity,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final cover = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AlbumCover(
        coverArtUrl: coverArtUrl,
        cacheKey: cacheKey,
        size: size,
        borderRadius: 18,
        showShadow: false,
      ),
    );

    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(scale: scale, child: cover),
      ),
    );
  }
}
