import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/mini_player_color_provider.dart';
import 'album_visual_palette.dart';

class MiniPlayerPaletteRequest {
  final String coverArtId;
  final String coverSourceId;
  final String coverUrl;
  final Brightness brightness;

  const MiniPlayerPaletteRequest({
    required this.coverArtId,
    required this.coverSourceId,
    required this.coverUrl,
    required this.brightness,
  });

  @override
  bool operator ==(Object other) {
    return other is MiniPlayerPaletteRequest &&
        other.coverArtId == coverArtId &&
        other.coverSourceId == coverSourceId &&
        other.brightness == brightness;
  }

  @override
  int get hashCode => Object.hash(coverArtId, coverSourceId, brightness);
}

final miniPlayerPaletteProvider = FutureProvider.autoDispose
    .family<AlbumVisualPalette, MiniPlayerPaletteRequest>((ref, request) {
      return AlbumVisualPalette.resolve(
        coverArtId: request.coverArtId,
        coverUrl: request.coverUrl,
        brightness: request.brightness,
        fallbackOnError: false,
      );
    });

class MiniPlayerChrome {
  final Color tintColor;
  final double tintOpacity;
  final Color borderColor;
  final double borderOpacity;
  final Color playButtonForeground;
  final Color collapsedFrameColor;

  const MiniPlayerChrome({
    required this.tintColor,
    required this.tintOpacity,
    required this.borderColor,
    required this.borderOpacity,
    required this.playButtonForeground,
    required this.collapsedFrameColor,
  });

  static MiniPlayerChrome resolve({
    required MiniPlayerColorMode mode,
    required AlbumVisualPalette? palette,
    required Brightness brightness,
  }) {
    if (mode != MiniPlayerColorMode.dynamicAlbum) {
      return const MiniPlayerChrome(
        tintColor: AppTheme.miniPlayerBg,
        tintOpacity: 0.78,
        borderColor: Colors.white,
        borderOpacity: 0.08,
        playButtonForeground: AppTheme.miniPlayerBg,
        collapsedFrameColor: AppTheme.miniPlayerBg,
      );
    }

    final effectivePalette =
        palette ?? AlbumVisualPalette.fallbackFor(brightness);
    final accent = effectivePalette.waveformAccentFor(brightness);
    final source = Color.lerp(
      Color.lerp(effectivePalette.top, effectivePalette.bottom, 0.42)!,
      accent,
      brightness == Brightness.dark ? 0.38 : 0.28,
    )!;
    final tint = _withMaximumLuminance(
      Color.lerp(
        source,
        Colors.black,
        brightness == Brightness.dark ? 0.14 : 0.28,
      )!,
      brightness == Brightness.dark ? 0.40 : 0.46,
    );
    final border = Color.lerp(accent, Colors.white, 0.22)!;

    return MiniPlayerChrome(
      tintColor: tint,
      tintOpacity: brightness == Brightness.dark ? 0.86 : 0.80,
      borderColor: border,
      borderOpacity: 0.20,
      playButtonForeground: tint,
      collapsedFrameColor: tint,
    );
  }

  static Color _withMaximumLuminance(Color color, double target) {
    if (color.computeLuminance() <= target) return color;
    for (var step = 1; step <= 12; step++) {
      final adjusted = Color.lerp(color, Colors.black, step / 12)!;
      if (adjusted.computeLuminance() <= target) return adjusted;
    }
    return Colors.black;
  }
}
