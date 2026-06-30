import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/app_cache_service.dart';

class AlbumVisualPalette {
  final Color top;
  final Color bottom;
  final Color waveformAccent;
  final Color waveformAccentSoft;
  final Color waveformTrack;

  const AlbumVisualPalette({
    required this.top,
    required this.bottom,
    required this.waveformAccent,
    required this.waveformAccentSoft,
    required this.waveformTrack,
  });

  static const fallback = AlbumVisualPalette(
    top: AppTheme.background,
    bottom: AppTheme.background,
    waveformAccent: AppTheme.waveformPlayed,
    waveformAccentSoft: Color(0xFF5F6368),
    waveformTrack: AppTheme.waveformUnplayed,
  );

  static AlbumVisualPalette fallbackFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const AlbumVisualPalette(
        top: AppTheme.darkBackground,
        bottom: AppTheme.darkBackground,
        waveformAccent: Color(0xFFDEDEDE),
        waveformAccentSoft: Color(0xFF616161),
        waveformTrack: AppTheme.darkSurfaceVariant,
      );
    }
    return fallback;
  }

  static final Map<String, Future<AlbumVisualPalette>> _paletteCache = {};
  static Future<Map<String, dynamic>>? _diskPaletteCache;

  static AlbumVisualPalette fromScheme(
    ColorScheme scheme,
    Brightness brightness,
  ) {
    if (brightness == Brightness.dark) {
      final top = Color.lerp(scheme.primaryContainer, Colors.black, 0.50)!;
      final bottom = Color.lerp(scheme.secondaryContainer, Colors.black, 0.50)!;
      final accent = Color.lerp(scheme.primary, Colors.white, 0.24)!;
      final accentSoft = Color.lerp(accent, Colors.black, 0.38)!;
      final track = Color.lerp(AppTheme.darkSurfaceVariant, top, 0.16)!;
      return AlbumVisualPalette(
        top: top,
        bottom: bottom,
        waveformAccent: accent,
        waveformAccentSoft: accentSoft,
        waveformTrack: track,
      );
    }

    final top = Color.lerp(scheme.primaryContainer, Colors.white, 0.28)!;
    final bottom = Color.lerp(scheme.secondaryContainer, Colors.white, 0.58)!;
    final accent = Color.lerp(scheme.primary, AppTheme.primaryText, 0.24)!;
    final accentSoft = Color.lerp(accent, Colors.white, 0.52)!;
    final track = Color.lerp(AppTheme.waveformUnplayed, top, 0.16)!;

    return AlbumVisualPalette(
      top: top,
      bottom: bottom,
      waveformAccent: accent,
      waveformAccentSoft: accentSoft,
      waveformTrack: track,
    );
  }

  Color waveformAccentFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _withMinimumLuminance(waveformAccent, 0.34);
    }
    return _withMaximumLuminance(waveformAccent, 0.30);
  }

  Color waveformTrackFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _withMaximumLuminance(
        _withMinimumLuminance(waveformTrack, 0.08),
        0.20,
      );
    }
    return _withMaximumLuminance(
      _withMinimumLuminance(waveformTrack, 0.54),
      0.76,
    );
  }

  static Color _withMinimumLuminance(Color color, double target) {
    if (color.computeLuminance() >= target) return color;
    for (var step = 1; step <= 12; step++) {
      final adjusted = Color.lerp(color, Colors.white, step / 12)!;
      if (adjusted.computeLuminance() >= target) return adjusted;
    }
    return Colors.white;
  }

  static Color _withMaximumLuminance(Color color, double target) {
    if (color.computeLuminance() <= target) return color;
    for (var step = 1; step <= 12; step++) {
      final adjusted = Color.lerp(color, Colors.black, step / 12)!;
      if (adjusted.computeLuminance() <= target) return adjusted;
    }
    return Colors.black;
  }

  static Future<AlbumVisualPalette> resolve({
    required String coverArtId,
    required String coverUrl,
    Brightness brightness = Brightness.light,
  }) async {
    if (coverArtId.isEmpty || coverUrl.isEmpty) {
      return fallbackFor(brightness);
    }

    final cacheKey = '${coverArtId}_${brightness.name}';
    final provider = CachedNetworkImageProvider(
      coverUrl,
      cacheKey: coverArtId,
      maxWidth: 112,
      maxHeight: 112,
    );

    try {
      return await _paletteCache.putIfAbsent(
        cacheKey,
        () => _resolveUncached(
          coverArtId: coverArtId,
          cacheKey: cacheKey,
          provider: provider,
          brightness: brightness,
        ),
      );
    } catch (_) {
      _paletteCache.remove(cacheKey);
      await provider.evict();
      return fallbackFor(brightness);
    }
  }

  static Future<AlbumVisualPalette> _resolveUncached({
    required String coverArtId,
    required String cacheKey,
    required CachedNetworkImageProvider provider,
    required Brightness brightness,
  }) async {
    final diskCache = await (_diskPaletteCache ??= AppCacheService.instance
        .readJson('visual_palettes')
        .then((value) => value ?? <String, dynamic>{}));
    final saved = diskCache[cacheKey];
    final savedPalette = _paletteFromJson(saved);
    if (savedPalette != null) {
      return savedPalette;
    }

    final scheme = await ColorScheme.fromImageProvider(
      provider: provider,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final palette = fromScheme(scheme, brightness);

    diskCache[cacheKey] = {
      'top': palette.top.toARGB32(),
      'bottom': palette.bottom.toARGB32(),
      'waveformAccent': palette.waveformAccent.toARGB32(),
      'waveformAccentSoft': palette.waveformAccentSoft.toARGB32(),
      'waveformTrack': palette.waveformTrack.toARGB32(),
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (diskCache.length > 100) {
      final oldest = diskCache.entries.reduce((a, b) {
        final aTime = (a.value as Map?)?['savedAt'] as num? ?? 0;
        final bTime = (b.value as Map?)?['savedAt'] as num? ?? 0;
        return aTime <= bTime ? a : b;
      });
      diskCache.remove(oldest.key);
    }
    await AppCacheService.instance.writeJson('visual_palettes', diskCache);

    return palette;
  }

  static AlbumVisualPalette? _paletteFromJson(Object? value) {
    if (value is! Map) return null;

    final top = value['top'];
    final bottom = value['bottom'];
    final waveformAccent = value['waveformAccent'];
    final waveformAccentSoft = value['waveformAccentSoft'];
    final waveformTrack = value['waveformTrack'];
    if (top is! num ||
        bottom is! num ||
        waveformAccent is! num ||
        waveformAccentSoft is! num ||
        waveformTrack is! num) {
      return null;
    }

    return AlbumVisualPalette(
      top: Color(top.toInt()),
      bottom: Color(bottom.toInt()),
      waveformAccent: Color(waveformAccent.toInt()),
      waveformAccentSoft: Color(waveformAccentSoft.toInt()),
      waveformTrack: Color(waveformTrack.toInt()),
    );
  }
}
