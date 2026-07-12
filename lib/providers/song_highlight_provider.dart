import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import '../models/song_highlight.dart';
import '../services/app_cache_service.dart';
import '../services/deepseek_highlight_service.dart';
import '../services/song_highlight_repository.dart';
import 'music_classification_provider.dart';
import 'player_provider.dart';

class SongHighlightRequest {
  final Song song;
  final LyricsData lyrics;
  final String lyricsHash;

  SongHighlightRequest({required this.song, required this.lyrics})
    : lyricsHash = lyricsAnalysisHash(song, lyrics);

  @override
  bool operator ==(Object other) {
    return other is SongHighlightRequest &&
        other.song.id == song.id &&
        other.lyricsHash == lyricsHash;
  }

  @override
  int get hashCode => Object.hash(song.id, lyricsHash);
}

final songHighlightRepositoryProvider = Provider<SongHighlightRepository>((
  ref,
) {
  return SongHighlightRepository(AppCacheService.instance);
});

final deepSeekHighlightServiceProvider = Provider<DeepSeekHighlightService>((
  ref,
) {
  return DeepSeekHighlightService(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
  );
});

final songHighlightProvider = FutureProvider.autoDispose
    .family<SongHighlightTimeline?, SongHighlightRequest>((ref, request) async {
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
      if (api == null ||
          classification.isLoading ||
          !request.lyrics.synced ||
          request.lyrics.lines.every((line) => line.start == null)) {
        return null;
      }

      final settings = classification.settings;
      final scope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      final repository = ref.read(songHighlightRepositoryProvider);
      final cached = await repository.load(scope, request.song.id);
      if (cached != null &&
          cached.matches(
            currentLyricsHash: request.lyricsHash,
            currentModel: settings.model,
          )) {
        return cached;
      }

      if (!classification.hasApiKey) return null;

      final apiKey = await ref
          .read(musicClassificationRepositoryProvider)
          .readApiKey();
      if (apiKey == null || apiKey.isEmpty) return null;
      final segments = await ref
          .read(deepSeekHighlightServiceProvider)
          .analyze(
            apiKey: apiKey,
            settings: settings,
            song: request.song,
            lyrics: request.lyrics,
          );
      final timeline = SongHighlightTimeline(
        segments: segments,
        lyricsHash: request.lyricsHash,
        model: settings.model,
        analyzedAt: DateTime.now(),
      );
      await repository.save(scope, request.song.id, timeline);
      return timeline;
    });
