import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/song_highlight.dart';
import 'app_cache_service.dart';

class SongHighlightRepository {
  final AppCacheService _cache;

  const SongHighlightRepository(this._cache);

  String _cacheName(String serverScope, String songId) {
    final id = sha1.convert(utf8.encode('$serverScope|$songId'));
    return 'song_highlight_$id';
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
}
