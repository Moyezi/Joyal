import 'package:dio/dio.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import 'app_cache_service.dart';
import 'subsonic_api.dart';

class LyricsService {
  final SubsonicApi api;
  final Dio dio;

  const LyricsService({required this.api, required this.dio});

  Future<LyricsData> fetch(Song song) async {
    final cache = AppCacheService.instance;
    final cacheName =
        'lyrics_${cache.serverScope(api.baseUrl, '${api.username}|${song.id}')}';
    final saved = await cache.readJson(cacheName);
    if (saved != null) {
      final savedAt = DateTime.tryParse(saved['savedAt'] as String? ?? '');
      if (savedAt != null &&
          DateTime.now().toUtc().difference(savedAt) <
              const Duration(days: 30)) {
        try {
          return LyricsData.fromJson(
            Map<String, dynamic>.from(saved['data'] as Map),
          );
        } catch (_) {
          // Fall through and replace malformed cache data from the server.
        }
      }
    }

    LyricsData result;
    try {
      final response = await dio.get(api.getLyricsBySongIdUrl(song.id));
      final parsed = _parseStructured(response.data);
      if (parsed != null && !parsed.isEmpty) {
        result = parsed;
        await _save(cache, cacheName, result);
        return result;
      }
    } catch (_) {
      // Older Subsonic servers may not implement getLyricsBySongId.
    }

    final response = await dio.get(
      api.getLyricsUrl(artist: song.artist, title: song.title),
    );
    result = _parseLegacy(response.data);
    if (!result.isEmpty) await _save(cache, cacheName, result);
    return result;
  }

  Future<void> _save(
    AppCacheService cache,
    String name,
    LyricsData data,
  ) async {
    await cache.writeJson(name, {
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'data': data.toJson(),
    });
    await cache.prune(
      prefix: 'lyrics_',
      maxFiles: 300,
      maxAge: const Duration(days: 90),
    );
  }

  LyricsData? _parseStructured(dynamic data) {
    if (data is! Map) return null;
    final root = data['subsonic-response'];
    if (root is! Map) return null;
    final lyricsList = root['lyricsList'];
    if (lyricsList is! Map) return null;
    dynamic entries = lyricsList['structuredLyrics'];
    if (entries is Map) entries = [entries];
    if (entries is! List || entries.isEmpty) return null;

    final selected = entries.firstWhere(
      (item) => item is Map && item['synced'] == true,
      orElse: () => entries.first,
    );
    if (selected is! Map) return null;
    dynamic rawLines = selected['line'];
    if (rawLines is Map) rawLines = [rawLines];
    if (rawLines is! List) return null;
    final lines = <LyricLine>[];
    for (final raw in rawLines) {
      if (raw is! Map) continue;
      final value = raw['value'];
      final text = value is List ? value.join('') : value?.toString() ?? '';
      final start = raw['start'];
      lines.add(
        LyricLine(
          text: text,
          start: start is num ? Duration(milliseconds: start.round()) : null,
        ),
      );
    }
    return LyricsData(lines: lines, synced: selected['synced'] == true);
  }

  LyricsData _parseLegacy(dynamic data) {
    if (data is! Map) return const LyricsData(lines: [], synced: false);
    final root = data['subsonic-response'];
    final lyrics = root is Map ? root['lyrics'] : null;
    final value = lyrics is Map ? lyrics['value'] : null;
    final text = value?.toString() ?? '';
    return LyricsData(
      lines: text
          .split(RegExp(r'\r?\n'))
          .map((line) => LyricLine(text: line))
          .toList(),
      synced: false,
    );
  }
}
