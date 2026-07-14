import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lyrics_ai_palette.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/deepseek_lyrics_ai_palette_service.dart';
import '../services/lyrics_ai_palette_protocol.dart';
import '../services/lyrics_ai_palette_repository.dart';
import 'lyrics_personalization_provider.dart';
import 'music_classification_provider.dart';
import 'player_provider.dart';

class LyricsAiPaletteRequest {
  final Song song;
  final String metadataHash;

  LyricsAiPaletteRequest(this.song)
    : metadataHash = lyricsAiPaletteMetadataHash(song);

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
      final cached = await repository.load(scope, request.song.id);
      if (cached != null &&
          cached.matches(
            currentMetadataHash: request.metadataHash,
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
      final palette = await _ref.read(
        lyricsAiPaletteProvider(LyricsAiPaletteRequest(song)).future,
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
}

final lyricsAiPaletteControllerProvider = Provider<LyricsAiPaletteController>((
  ref,
) {
  return LyricsAiPaletteController(ref);
});
