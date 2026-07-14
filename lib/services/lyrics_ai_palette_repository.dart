import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/lyrics_ai_palette.dart';
import 'app_cache_service.dart';

class LyricsAiPaletteRepository {
  static const _cachePrefix = 'lyrics_ai_palette_';
  static const _legacyCachePrefix = 'floating_name_palette_';
  static const _recognizedCountPrefix = 'lyrics_ai_palette_count_';

  final AppCacheService _cache;

  const LyricsAiPaletteRepository(this._cache);

  String _cacheName(String prefix, String serverScope, String songId) {
    final id = sha1.convert(utf8.encode('$serverScope|$songId'));
    return '$prefix$id';
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

  Future<LyricsAiPalette?> load(String serverScope, String songId) async {
    final currentName = _cacheName(_cachePrefix, serverScope, songId);
    final current = await _read(currentName);
    if (current != null) return current;

    final legacy = await _read(
      _cacheName(_legacyCachePrefix, serverScope, songId),
    );
    if (legacy == null) return null;

    await _cache.writeJson(currentName, legacy.toJson());
    return legacy;
  }

  Future<void> save(
    String serverScope,
    String songId,
    LyricsAiPalette palette,
  ) async {
    await _cache.writeJson(
      _cacheName(_cachePrefix, serverScope, songId),
      palette.toJson(),
    );
    await _cache.prune(
      prefix: _cachePrefix,
      maxFiles: 400,
      maxAge: const Duration(days: 365),
    );
  }

  Future<void> delete(String serverScope, String songId) {
    return Future.wait([
      _cache.deleteJson(_cacheName(_cachePrefix, serverScope, songId)),
      _cache.deleteJson(_cacheName(_legacyCachePrefix, serverScope, songId)),
    ]).then((_) {});
  }

  Future<void> deleteAll(String serverScope, Iterable<String> songIds) {
    return Future.wait(
      songIds.map((songId) => delete(serverScope, songId)),
    ).then((_) {});
  }

  Future<LyricsAiPalette?> _read(String cacheName) async {
    final json = await _cache.readJson(cacheName);
    if (json == null) return null;
    try {
      return LyricsAiPalette.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
