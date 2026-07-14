import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import '../models/song_highlight.dart';
import '../services/app_cache_service.dart';
import '../services/deepseek_highlight_service.dart';
import '../services/song_highlight_repository.dart';
import 'library_provider.dart';
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

class RecognizedSongHighlight {
  final Song song;
  final SongHighlightTimeline timeline;

  const RecognizedSongHighlight({required this.song, required this.timeline});
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

/// Reads only locally cached climax results. It never starts a DeepSeek request.
final cachedSongHighlightProvider = FutureProvider.autoDispose
    .family<SongHighlightTimeline?, Song>((ref, song) async {
      final api = ref.watch(subsonicApiProvider);
      if (api == null) return null;
      final scope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      return ref.read(songHighlightRepositoryProvider).load(scope, song.id);
    });

/// Reads the last completed management scan count without scanning the library.
final cachedRecognizedSongHighlightCountProvider =
    FutureProvider.autoDispose<int?>((ref) async {
      final api = ref.watch(subsonicApiProvider);
      if (api == null) return null;
      final scope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      return ref
          .read(songHighlightRepositoryProvider)
          .loadRecognizedCount(scope);
    });

/// Scans the current library for locally cached climax timelines so records
/// created before the management screen was introduced remain visible.
final recognizedSongHighlightsProvider =
    FutureProvider.autoDispose<List<RecognizedSongHighlight>>((ref) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final api = ref.watch(subsonicApiProvider);
      final songs = ref.watch(libraryProvider.select((state) => state.songs));
      if (api == null || songs.isEmpty) return const [];

      final scope = AppCacheService.instance.serverScope(
        api.baseUrl,
        api.username,
      );
      final repository = ref.read(songHighlightRepositoryProvider);
      final recognized = <RecognizedSongHighlight>[];
      // Keep local file reads bounded so opening this view does not flood the
      // event loop on large libraries.
      const batchSize = 24;
      for (var start = 0; start < songs.length; start += batchSize) {
        final end = (start + batchSize).clamp(0, songs.length);
        final batch = songs.sublist(start, end);
        final timelines = await Future.wait(
          batch.map((song) => repository.load(scope, song.id)),
        );
        for (var index = 0; index < batch.length; index++) {
          final timeline = timelines[index];
          if (timeline != null && timeline.segments.isNotEmpty) {
            recognized.add(
              RecognizedSongHighlight(song: batch[index], timeline: timeline),
            );
          }
        }
        if (disposed) return const [];
        if (end < songs.length) await Future<void>.delayed(Duration.zero);
      }
      recognized.sort(
        (left, right) =>
            right.timeline.analyzedAt.compareTo(left.timeline.analyzedAt),
      );
      await repository.saveRecognizedCount(scope, recognized.length);
      if (!disposed) {
        ref.invalidate(cachedRecognizedSongHighlightCountProvider);
      }
      return recognized;
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
