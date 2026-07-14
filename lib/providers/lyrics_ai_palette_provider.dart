import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../models/lyrics_ai_palette.dart';
import '../models/lyrics.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/deepseek_lyrics_ai_palette_service.dart';
import '../services/lyrics_ai_palette_protocol.dart';
import '../services/lyrics_ai_palette_repository.dart';
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
  final bool forceRefresh;

  LyricsAiPaletteRequest(this.song, this.lyrics, {this.forceRefresh = false})
    : metadataHash = lyricsAiPaletteMetadataHash(song, lyrics);

  @override
  bool operator ==(Object other) {
    return other is LyricsAiPaletteRequest &&
        other.song.id == song.id &&
        other.metadataHash == metadataHash &&
        other.forceRefresh == forceRefresh;
  }

  @override
  int get hashCode => Object.hash(song.id, metadataHash, forceRefresh);
}

final lyricsAiPaletteRepositoryProvider = Provider<LyricsAiPaletteRepository>((
  ref,
) {
  return LyricsAiPaletteRepository(AppCacheService.instance);
});

/// Scans only the current library's local palette cache. Opening the
/// management screen must never start a DeepSeek request.
final recognizedLyricsAiPalettesProvider =
    FutureProvider.autoDispose<List<RecognizedLyricsAiPalette>>((ref) async {
      final api = ref.watch(subsonicApiProvider);
      final songs = ref.watch(libraryProvider.select((state) => state.songs));
      if (api == null || songs.isEmpty) return const [];

      final scope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      final repository = ref.read(lyricsAiPaletteRepositoryProvider);
      final palettes = await Future.wait(
        songs.map((song) => repository.load(scope, song.id)),
      );
      final recognized = <RecognizedLyricsAiPalette>[];
      for (var index = 0; index < songs.length; index++) {
        final palette = palettes[index];
        if (palette != null) {
          recognized.add(
            RecognizedLyricsAiPalette(song: songs[index], palette: palette),
          );
        }
      }
      recognized.sort(
        (left, right) =>
            right.palette.generatedAt.compareTo(left.palette.generatedAt),
      );
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

final lyricsAiPaletteProvider = FutureProvider.autoDispose
    .family<LyricsAiPalette?, LyricsAiPaletteRequest>((ref, request) async {
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
      if (!request.forceRefresh) {
        final cached = await repository.load(scope, request.song.id);
        if (cached != null &&
            cached.matches(
              currentMetadataHash: request.metadataHash,
              currentModel: classification.settings.model,
              currentPromptVersion: lyricsAiPalettePromptVersion,
            )) {
          return cached;
        }
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
          );
      await repository.save(scope, request.song.id, palette);
      return palette;
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

      final forcedRequest = LyricsAiPaletteRequest(
        song,
        lyrics,
        forceRefresh: true,
      );
      _ref.invalidate(lyricsAiPaletteProvider(forcedRequest));
      final palette = await _ref.read(
        lyricsAiPaletteProvider(forcedRequest).future,
      );
      if (palette == null) {
        throw StateError('AI palette generation returned no palette');
      }
      _ref.invalidate(
        lyricsAiPaletteProvider(LyricsAiPaletteRequest(song, lyrics)),
      );
      _ref.invalidate(recognizedLyricsAiPalettesProvider);
      return LyricsAiPaletteActivationResult.applied;
    } catch (_) {
      if (cacheDeleted && previousPalette != null) {
        await repository!.save(scope!, song.id, previousPalette);
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
