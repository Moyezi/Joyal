import 'package:dio/dio.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import 'app_cache_service.dart';
import 'subsonic_api.dart';

class LyricsService {
  static const _freshCacheAge = Duration(days: 30);
  static const _emptyCacheAge = Duration(days: 7);
  static const _staleCacheAge = Duration(days: 90);

  final SubsonicApi api;
  final Dio dio;

  const LyricsService({required this.api, required this.dio});

  Future<LyricsData> fetch(Song song) async {
    final cache = AppCacheService.instance;
    final cacheName =
        'lyrics_${cache.serverScope(api.baseUrl, '${api.username}|${song.id}')}';
    final saved = await cache.readJson(cacheName);
    final cached = _readCached(saved);
    if (cached != null && _isFresh(cached)) {
      return cached.data;
    }

    var structuredReturnedEmpty = false;
    try {
      final response = await dio.get(api.getLyricsBySongIdUrl(song.id));
      final parsed = _parseStructured(response.data);
      if (parsed != null && !parsed.isEmpty) {
        await _save(cache, cacheName, parsed);
        return parsed;
      }
      structuredReturnedEmpty = _isSuccessfulResponse(response.data);
    } catch (_) {
      // Older Subsonic servers may not implement getLyricsBySongId.
    }

    try {
      final response = await dio.get(
        api.getLyricsUrl(artist: song.artist, title: song.title),
      );
      final result = _parseLegacy(response.data);
      await _save(cache, cacheName, result);
      return result;
    } catch (_) {
      if (structuredReturnedEmpty) {
        const result = LyricsData(lines: [], synced: false);
        await _save(cache, cacheName, result);
        return result;
      }
      if (cached != null && _isUsableStale(cached)) {
        return cached.data;
      }
      rethrow;
    }
  }

  Future<void> _save(
    AppCacheService cache,
    String name,
    LyricsData data,
  ) async {
    await cache.writeJson(name, {
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'isEmpty': data.isEmpty,
      'data': data.toJson(),
    });
    await cache.prune(
      prefix: 'lyrics_',
      maxFiles: 300,
      maxAge: const Duration(days: 90),
    );
  }

  ({LyricsData data, DateTime savedAt, bool isEmpty})? _readCached(
    Map<String, dynamic>? saved,
  ) {
    if (saved == null) return null;
    final savedAt = DateTime.tryParse(saved['savedAt'] as String? ?? '');
    if (savedAt == null) return null;
    try {
      final data = LyricsData.fromJson(
        Map<String, dynamic>.from(saved['data'] as Map),
      );
      return (
        data: data,
        savedAt: savedAt,
        isEmpty: saved['isEmpty'] == true || data.isEmpty,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isFresh(({LyricsData data, DateTime savedAt, bool isEmpty}) cached) {
    final maxAge = cached.isEmpty ? _emptyCacheAge : _freshCacheAge;
    return DateTime.now().toUtc().difference(cached.savedAt) < maxAge;
  }

  bool _isUsableStale(
    ({LyricsData data, DateTime savedAt, bool isEmpty}) cached,
  ) {
    return DateTime.now().toUtc().difference(cached.savedAt) < _staleCacheAge;
  }

  bool _isSuccessfulResponse(dynamic data) {
    if (data is! Map) return false;
    final root = data['subsonic-response'];
    return root is Map && root['status'] != 'failed';
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
