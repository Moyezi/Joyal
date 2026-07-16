import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../models/lyrics_ai_palette.dart';
import '../models/lyrics.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/deepseek_lyrics_ai_palette_service.dart';
import '../services/lyrics_ai_palette_protocol.dart';
import '../services/lyrics_ai_palette_repository.dart';
import '../services/subsonic_api.dart';
import '../widgets/album_visual_palette.dart';
import 'lyrics_personalization_provider.dart';
import 'lyrics_provider.dart';
import 'library_provider.dart';
import 'music_classification_provider.dart';
import 'player_provider.dart';

class RecognizedLyricsAiPalette {
  final Song song;
  final LyricsAiPalette palette;

  const RecognizedLyricsAiPalette({required this.song, required this.palette});
}

class LyricsAiPaletteRequest {
  final Song song;
  final LyricsData lyrics;
  final String metadataHash;

  LyricsAiPaletteRequest(this.song, this.lyrics)
    : metadataHash = lyricsAiPaletteMetadataHash(song, lyrics);

  @override
  bool operator ==(Object other) {
    return other is LyricsAiPaletteRequest &&
        other.song.id == song.id &&
        other.metadataHash == metadataHash;
  }

  @override
  int get hashCode => Object.hash(song.id, metadataHash);
}

final lyricsAiPaletteRepositoryProvider = Provider<LyricsAiPaletteRepository>((
  ref,
) {
  return LyricsAiPaletteRepository(AppCacheService.instance);
});

/// Reads the last completed management scan count without scanning the library.
final cachedRecognizedLyricsAiPaletteCountProvider =
    FutureProvider.autoDispose<int?>((ref) async {
      final api = ref.watch(subsonicApiProvider);
      if (api == null) return null;
      final scope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      return ref
          .read(lyricsAiPaletteRepositoryProvider)
          .loadRecognizedCount(scope);
    });

/// Scans only the current library's local palette cache. Opening the
/// management screen must never start a DeepSeek request.
final recognizedLyricsAiPalettesProvider =
    FutureProvider.autoDispose<List<RecognizedLyricsAiPalette>>((ref) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final api = ref.watch(subsonicApiProvider);
      final songs = ref.watch(libraryProvider.select((state) => state.songs));
      if (api == null || songs.isEmpty) return const [];

      final scope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      final repository = ref.read(lyricsAiPaletteRepositoryProvider);
      final recognized = <RecognizedLyricsAiPalette>[];
      // Keep local file reads bounded so opening this view does not flood the
      // event loop on large libraries.
      const batchSize = 24;
      for (var start = 0; start < songs.length; start += batchSize) {
        final end = (start + batchSize).clamp(0, songs.length);
        final batch = songs.sublist(start, end);
        final palettes = await Future.wait(
          batch.map((song) => repository.load(scope, song.id)),
        );
        for (var index = 0; index < batch.length; index++) {
          final palette = palettes[index];
          if (palette != null) {
            recognized.add(
              RecognizedLyricsAiPalette(song: batch[index], palette: palette),
            );
          }
        }
        if (disposed) return const [];
        if (end < songs.length) await Future<void>.delayed(Duration.zero);
      }
      recognized.sort(
        (left, right) =>
            right.palette.generatedAt.compareTo(left.palette.generatedAt),
      );
      await repository.saveRecognizedCount(scope, recognized.length);
      if (!disposed) {
        ref.invalidate(cachedRecognizedLyricsAiPaletteCountProvider);
      }
      return recognized;
    });

final deepSeekLyricsAiPaletteServiceProvider =
    Provider<DeepSeekLyricsAiPaletteService>((ref) {
      return DeepSeekLyricsAiPaletteService(
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 60),
          ),
        ),
      );
    });

Future<LyricsAiVisualContext?> _resolveLyricsAiVisualContext(
  SubsonicApi api,
  Song song,
) async {
  if (song.coverArt.isEmpty) return null;
  final coverUrl = api.getCoverArtUrl(song.coverArt);
  try {
    final palettes = await Future.wait([
      AlbumVisualPalette.resolve(
        coverArtId: song.coverArt,
        coverUrl: coverUrl,
        brightness: Brightness.light,
        fallbackOnError: false,
      ),
      AlbumVisualPalette.resolve(
        coverArtId: song.coverArt,
        coverUrl: coverUrl,
        brightness: Brightness.dark,
        fallbackOnError: false,
      ),
    ]);
    final light = palettes[0];
    final dark = palettes[1];
    return LyricsAiVisualContext(
      light: LyricsAiVisualScheme(
        backgroundTop: light.top.toARGB32(),
        backgroundBottom: light.bottom.toARGB32(),
        accent: light.waveformAccentFor(Brightness.light).toARGB32(),
      ),
      dark: LyricsAiVisualScheme(
        backgroundTop: dark.top.toARGB32(),
        backgroundBottom: dark.bottom.toARGB32(),
        accent: dark.waveformAccentFor(Brightness.dark).toARGB32(),
      ),
    );
  } catch (_) {
    // Keep AI coloring available when the cover is not cached and cannot be
    // fetched. The protocol's canonical light/dark backgrounds remain safe.
    return null;
  }
}

final lyricsAiVisualContextProvider = FutureProvider.autoDispose
    .family<LyricsAiVisualContext?, Song>((ref, song) async {
      final api = ref.watch(subsonicApiProvider);
      if (api == null) return null;
      return _resolveLyricsAiVisualContext(api, song);
    });

final lyricsAiPaletteProvider = FutureProvider.autoDispose
    .family<LyricsAiPalette?, LyricsAiPaletteRequest>((ref, request) async {
      final keepAliveLink = ref.keepAlive();
      try {
        final api = ref.watch(subsonicApiProvider);
        final classification = ref.watch(
          musicClassificationProvider.select(
            (state) => (
              settings: state.settings,
              isLoading: state.isLoading,
              hasApiKey: state.hasApiKey,
            ),
          ),
        );
        if (api == null || classification.isLoading) return null;

        final scope = AppCacheService.instance.serverScope(
          api.baseUrl,
          api.username,
        );
        final repository = ref.read(lyricsAiPaletteRepositoryProvider);
        final cached = await repository.load(scope, request.song.id);
        final visualContext = await ref.watch(
          lyricsAiVisualContextProvider(request.song).future,
        );
        final currentMetadataHash = lyricsAiPaletteMetadataHash(
          request.song,
          request.lyrics,
          visualContext: visualContext,
        );
        if (cached != null &&
            cached.matches(
              currentMetadataHash: currentMetadataHash,
              currentModel: classification.settings.model,
              currentPromptVersion: lyricsAiPalettePromptVersion,
            )) {
          return cached;
        }

        if (!classification.hasApiKey) return null;
        final apiKey = await ref
            .read(musicClassificationRepositoryProvider)
            .readApiKey();
        if (apiKey == null || apiKey.isEmpty) return null;

        final palette = await ref
            .read(deepSeekLyricsAiPaletteServiceProvider)
            .generate(
              apiKey: apiKey,
              settings: classification.settings,
              song: request.song,
              lyrics: request.lyrics,
              visualContext: visualContext,
            );
        await repository.save(scope, request.song.id, palette);
        return palette;
      } finally {
        keepAliveLink.close();
      }
    });

enum LyricsAiPaletteActivationResult {
  applied,
  noServer,
  configurationLoading,
  missingApiKey,
  generationFailed,
}

final lyricsAiPaletteRefreshInProgressProvider =
    StateProvider.family<bool, String>((ref, songId) => false);

class LyricsAiPaletteController {
  final Ref _ref;

  const LyricsAiPaletteController(this._ref);

  Future<void> disable() {
    return _ref
        .read(lyricsPersonalizationProvider.notifier)
        .setAiColorEnabled(false);
  }

  Future<LyricsAiPaletteActivationResult> enable(Song? song) async {
    if (song == null || _ref.read(subsonicApiProvider) == null) {
      return LyricsAiPaletteActivationResult.noServer;
    }

    final classification = _ref.read(musicClassificationProvider);
    if (classification.isLoading) {
      return LyricsAiPaletteActivationResult.configurationLoading;
    }

    final personalization = _ref.read(lyricsPersonalizationProvider.notifier);
    await personalization.setAiColorEnabled(true);
    try {
      final lyrics = await _ref.read(lyricsProvider(song).future);
      if (lyrics.isEmpty) {
        await personalization.setAiColorEnabled(false);
        return LyricsAiPaletteActivationResult.generationFailed;
      }
      final palette = await _ref.read(
        lyricsAiPaletteProvider(LyricsAiPaletteRequest(song, lyrics)).future,
      );
      if (palette != null) return LyricsAiPaletteActivationResult.applied;

      await personalization.setAiColorEnabled(false);
      return classification.hasApiKey
          ? LyricsAiPaletteActivationResult.generationFailed
          : LyricsAiPaletteActivationResult.missingApiKey;
    } catch (_) {
      await personalization.setAiColorEnabled(false);
      return LyricsAiPaletteActivationResult.generationFailed;
    }
  }

  Future<LyricsAiPaletteActivationResult> refresh(Song? song) async {
    final api = _ref.read(subsonicApiProvider);
    if (song == null || api == null) {
      return LyricsAiPaletteActivationResult.noServer;
    }

    final classification = _ref.read(musicClassificationProvider);
    if (classification.isLoading) {
      return LyricsAiPaletteActivationResult.configurationLoading;
    }
    if (!classification.hasApiKey) {
      return LyricsAiPaletteActivationResult.missingApiKey;
    }

    final refreshing = _ref.read(
      lyricsAiPaletteRefreshInProgressProvider(song.id).notifier,
    );
    if (refreshing.state) return LyricsAiPaletteActivationResult.applied;
    refreshing.state = true;
    LyricsAiPalette? previousPalette;
    LyricsAiPaletteRepository? repository;
    LyricsAiPaletteRequest? refreshRequest;
    String? scope;
    var cacheDeleted = false;
    try {
      final lyrics = await _ref.read(lyricsProvider(song).future);
      if (lyrics.isEmpty) {
        return LyricsAiPaletteActivationResult.generationFailed;
      }
      final currentScope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      final currentRepository = _ref.read(lyricsAiPaletteRepositoryProvider);
      scope = currentScope;
      repository = currentRepository;
      previousPalette = await currentRepository.load(currentScope, song.id);

      // Reuse the palette management screen's known-good deletion path before
      // generating the replacement, including cleanup of the legacy cache.
      await currentRepository.delete(currentScope, song.id);
      cacheDeleted = true;

      final request = LyricsAiPaletteRequest(song, lyrics);
      refreshRequest = request;
      _ref.invalidate(lyricsAiPaletteProvider(request));
      final palette = await _ref.read(lyricsAiPaletteProvider(request).future);
      if (palette == null) {
        throw StateError('AI palette generation returned no palette');
      }
      _ref.invalidate(recognizedLyricsAiPalettesProvider);
      return LyricsAiPaletteActivationResult.applied;
    } catch (_) {
      if (cacheDeleted && previousPalette != null) {
        await repository!.save(scope!, song.id, previousPalette);
        _ref.invalidate(lyricsAiPaletteProvider(refreshRequest!));
        _ref.invalidate(recognizedLyricsAiPalettesProvider);
      }
      return LyricsAiPaletteActivationResult.generationFailed;
    } finally {
      refreshing.state = false;
    }
  }
}

final lyricsAiPaletteControllerProvider = Provider<LyricsAiPaletteController>((
  ref,
) {
  return LyricsAiPaletteController(ref);
});
