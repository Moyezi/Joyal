import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_context.dart';
import '../../providers/lyrics_personalization_provider.dart';
import '../album_visual_palette.dart';

const defaultLightLyricColor = Color(0xFF3F434A);

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

Color dynamicLyricColorFromPalette(
  AlbumVisualPalette palette,
  Brightness brightness,
) {
  final source = Color.lerp(
    palette.waveformAccentFor(brightness),
    palette.top,
    0.18,
  )!;
  final pastel = Color.lerp(
    source,
    Colors.white,
    brightness == Brightness.dark ? 0.50 : 0.28,
  )!;
  final minLuminance = brightness == Brightness.dark ? 0.58 : 0.30;
  final maxLuminance = brightness == Brightness.dark ? 0.86 : 0.58;
  return _withMaximumLuminance(
    _withMinimumLuminance(pastel, minLuminance),
    maxLuminance,
  );
}

Color _dynamicFallbackColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFE8EEFF)
      : const Color(0xFF6D7FA8);
}

Color resolvedActiveLyricColor(
  BuildContext context,
  LyricsPersonalizationState preferences,
  Color? dynamicColor,
) {
  return switch (preferences.colorMode) {
    LyricsColorMode.system =>
      Theme.of(context).brightness == Brightness.light
          ? defaultLightLyricColor
          : context.primaryColor,
    LyricsColorMode.black => Colors.black,
    LyricsColorMode.white => Colors.white,
    LyricsColorMode.dynamicLight =>
      dynamicColor ?? _dynamicFallbackColor(Theme.of(context).brightness),
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
