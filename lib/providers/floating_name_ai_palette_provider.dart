import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/floating_name_ai_palette.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/deepseek_floating_name_palette_service.dart';
import '../services/floating_name_ai_palette_repository.dart';
import 'music_classification_provider.dart';
import 'player_provider.dart';

class FloatingNameAiPaletteRequest {
  final Song song;
  final String metadataHash;

  FloatingNameAiPaletteRequest(this.song)
    : metadataHash = floatingNameAiPaletteMetadataHash(song);

  @override
  bool operator ==(Object other) {
    return other is FloatingNameAiPaletteRequest &&
        other.song.id == song.id &&
        other.metadataHash == metadataHash;
  }

  @override
  int get hashCode => Object.hash(song.id, metadataHash);
}

final floatingNameAiPaletteRepositoryProvider =
    Provider<FloatingNameAiPaletteRepository>((ref) {
      return FloatingNameAiPaletteRepository(AppCacheService.instance);
    });

final deepSeekFloatingNamePaletteServiceProvider =
    Provider<DeepSeekFloatingNamePaletteService>((ref) {
      return DeepSeekFloatingNamePaletteService(
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 60),
          ),
        ),
      );
    });

final floatingNameAiPaletteProvider = FutureProvider.autoDispose
    .family<FloatingNameAiPalette?, FloatingNameAiPaletteRequest>((
      ref,
      request,
    ) async {
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
      final repository = ref.read(floatingNameAiPaletteRepositoryProvider);
      final cached = await repository.load(scope, request.song.id);
      if (cached != null &&
          cached.matches(
            currentMetadataHash: request.metadataHash,
            currentModel: classification.settings.model,
          )) {
        return cached;
      }

      if (!classification.hasApiKey) return null;
      final apiKey = await ref
          .read(musicClassificationRepositoryProvider)
          .readApiKey();
      if (apiKey == null || apiKey.isEmpty) return null;

      final palette = await ref
          .read(deepSeekFloatingNamePaletteServiceProvider)
          .generate(
            apiKey: apiKey,
            settings: classification.settings,
            song: request.song,
          );
      await repository.save(scope, request.song.id, palette);
      return palette;
    });
