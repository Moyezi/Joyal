import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'cached_disk_image.dart';

/// Renders an album cover image with a soft diffuse shadow.
///
/// Uses [CachedDiskImage] with a stable [cacheKey] based on the coverArt ID
/// to prevent redundant network requests on every rebuild.
class AlbumCover extends StatelessWidget {
  /// The full authenticated URL for the cover art image.
  final String coverArtUrl;

  /// A stable identifier used as the image cache key (e.g. the coverArt ID).
  /// This ensures the image is cached even when the URL changes due to
  /// fresh authentication tokens.
  final String cacheKey;

  final double size;
  final double borderRadius;
  final bool showShadow;

  const AlbumCover({
    super.key,
    required this.coverArtUrl,
    required this.cacheKey,
    this.size = 280,
    this.borderRadius = AppTheme.radiusLarge,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow ? AppTheme.diffuseShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (coverArtUrl.isEmpty) {
      return _PlaceholderCover(borderRadius: borderRadius);
    }

    return CachedDiskImage(
      imageUrl: coverArtUrl,
      cacheKey: cacheKey,
      fit: BoxFit.cover,
      placeholderBuilder: (context) =>
          _PlaceholderCover(borderRadius: borderRadius),
      errorBuilder: (context, error) =>
          _PlaceholderCover(borderRadius: borderRadius),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 200),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final double borderRadius;
  const _PlaceholderCover({required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF2C2C2C), Color(0xFF1E1E1E)]
              : const [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note, size: 64, color: Colors.white70),
      ),
    );
  }
}
