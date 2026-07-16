import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lyrics_personalization_provider.dart';
import '../album_visual_palette.dart';

class LyricsPaletteRequest {
  final String coverArtId;
  final String coverSourceId;
  final String coverUrl;
  final Brightness brightness;

  const LyricsPaletteRequest({
    required this.coverArtId,
    required this.coverSourceId,
    required this.coverUrl,
    required this.brightness,
  });

  @override
  bool operator ==(Object other) {
    return other is LyricsPaletteRequest &&
        other.coverArtId == coverArtId &&
        other.coverSourceId == coverSourceId &&
        other.brightness == brightness;
  }

  @override
  int get hashCode => Object.hash(coverArtId, coverSourceId, brightness);
}

final lyricsPaletteProvider = FutureProvider.autoDispose
    .family<AlbumVisualPalette, LyricsPaletteRequest>((ref, request) {
      return AlbumVisualPalette.resolve(
        coverArtId: request.coverArtId,
        coverUrl: request.coverUrl,
        brightness: request.brightness,
      );
    });

Color dynamicLyricColorFromPalette(AlbumVisualPalette palette) {
  final source = Color.lerp(
    palette.waveformAccentFor(Brightness.dark),
    palette.top,
    0.18,
  )!;
  final pastel = Color.lerp(source, Colors.white, 0.50)!;
  return _withMaximumLuminance(_withMinimumLuminance(pastel, 0.58), 0.86);
}

const _dynamicFallbackColor = Color(0xFFE8EEFF);

Color resolvedActiveLyricColor(
  BuildContext context,
  LyricsPersonalizationState preferences,
  Color? dynamicColor,
) {
  return switch (preferences.colorMode) {
    LyricsColorMode.white => Colors.white,
    LyricsColorMode.dynamicLight => dynamicColor ?? _dynamicFallbackColor,
  };
}

Color _withMinimumLuminance(Color color, double target) {
  if (color.computeLuminance() >= target) return color;
  for (var step = 1; step <= 12; step++) {
    final adjusted = Color.lerp(color, Colors.white, step / 12)!;
    if (adjusted.computeLuminance() >= target) return adjusted;
  }
  return Colors.white;
}

Color _withMaximumLuminance(Color color, double target) {
  if (color.computeLuminance() <= target) return color;
  for (var step = 1; step <= 12; step++) {
    final adjusted = Color.lerp(color, Colors.black, step / 12)!;
    if (adjusted.computeLuminance() <= target) return adjusted;
  }
  return Colors.black;
}
