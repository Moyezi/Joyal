import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/lyrics_service.dart';
import '../services/subsonic_api.dart';
import 'player_provider.dart';

const _storage = FlutterSecureStorage();
const _sourceOverridesKey = 'lyrics_source_overrides_v1';

String lyricsSourceOverrideKeyFor(SubsonicApi api, Song song) {
  return AppCacheService.instance.serverScope(
    api.baseUrl,
    '${api.username}|${song.id}',
  );
}

class LyricsSourceOverridesNotifier
    extends StateNotifier<Map<String, LyricsSource>> {
  LyricsSourceOverridesNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _storage.read(key: _sourceOverridesKey);
      if (saved == null || saved.isEmpty) return;
      final decoded = jsonDecode(saved);
      if (decoded is! Map) return;
      final overrides = <String, LyricsSource>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final source = LyricsSource.fromStorageValue(entry.value as String);
        if (source != LyricsSource.amll) {
          overrides[entry.key as String] = source;
        }
      }
      state = overrides;
    } catch (_) {
      // A malformed preference must not prevent lyrics from loading.
    }
  }

  Future<void> setSourceFor(
    SubsonicApi api,
    Song song,
    LyricsSource source,
  ) async {
    final key = lyricsSourceOverrideKeyFor(api, song);
    final next = Map<String, LyricsSource>.from(state);
    if (source == LyricsSource.amll) {
      next.remove(key);
    } else {
      next[key] = source;
    }
    state = next;
    await _storage.write(
      key: _sourceOverridesKey,
      value: jsonEncode(
        next.map((key, source) => MapEntry(key, source.storageValue)),
      ),
    );
  }
}

final lyricsSourceOverridesProvider =
    StateNotifierProvider<
      LyricsSourceOverridesNotifier,
      Map<String, LyricsSource>
    >((ref) => LyricsSourceOverridesNotifier());

final lyricsSourceForSongProvider = Provider.family<LyricsSource, Song>((
  ref,
  song,
) {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return LyricsSource.amll;
  final key = lyricsSourceOverrideKeyFor(api, song);
  return ref.watch(
    lyricsSourceOverridesProvider.select(
      (overrides) => overrides[key] ?? LyricsSource.amll,
    ),
  );
});
