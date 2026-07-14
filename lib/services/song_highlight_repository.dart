import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/song_highlight.dart';
import 'app_cache_service.dart';

class SongHighlightRepository {
  static const _recognizedCountPrefix = 'song_highlight_count_';

  final AppCacheService _cache;

  const SongHighlightRepository(this._cache);

  String _cacheName(String serverScope, String songId) {
    final id = sha1.convert(utf8.encode('$serverScope|$songId'));
    return 'song_highlight_$id';
  }

  String _countCacheName(String serverScope) {
    return '$_recognizedCountPrefix$serverScope';
  }

  Future<int?> loadRecognizedCount(String serverScope) async {
    final json = await _cache.readJson(_countCacheName(serverScope));
    final count = json?['count'];
    return count is int && count >= 0 ? count : null;
  }

  Future<void> saveRecognizedCount(String serverScope, int count) {
    return _cache.writeJson(_countCacheName(serverScope), {
      'count': count.clamp(0, 0x7fffffff),
    });
  }

  Future<SongHighlightTimeline?> load(String serverScope, String songId) async {
    final json = await _cache.readJson(_cacheName(serverScope, songId));
    return json == null ? null : SongHighlightTimeline.fromJson(json);
  }

  Future<void> save(
    String serverScope,
    String songId,
    SongHighlightTimeline timeline,
  ) {
    return _cache.writeJson(_cacheName(serverScope, songId), timeline.toJson());
  }

  Future<void> delete(String serverScope, String songId) {
    return _cache.deleteJson(_cacheName(serverScope, songId));
  }

  Future<void> deleteAll(String serverScope, Iterable<String> songIds) {
    return Future.wait(
      songIds.map((songId) => delete(serverScope, songId)),
    ).then((_) {});
  }
}
