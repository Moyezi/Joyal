import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/lyrics_service.dart';
import 'library_provider.dart';
import 'player_provider.dart';

final Map<String, Future<LyricsData>> _lyricsCache = {};

final lyricsProvider = FutureProvider.family<LyricsData, Song>((ref, song) {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) {
    return Future.value(const LyricsData(lines: [], synced: false));
  }

  final key =
      '${AppCacheService.instance.serverScope(api.baseUrl, api.username)}_${song.id}';
  return _lyricsCache.putIfAbsent(key, () {
    return LyricsService(
      api: api,
      dio: ref.read(dioProvider),
    ).fetch(song).catchError((Object error) {
      _lyricsCache.remove(key);
      throw error;
    });
  });
});

int activeLyricIndex(LyricsData data, Duration position) {
  if (!data.synced) return -1;
  var active = -1;
  for (var index = 0; index < data.lines.length; index++) {
    final start = data.lines[index].start;
    if (start != null && start <= position) active = index;
  }
  return active;
}

({String current, String next, int index}) lyricPairForPosition(
  LyricsData data,
  Duration position,
) {
  final lines = data.lines
      .map((line) => line.text.trim())
      .where((text) => text.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return (current: '\u6682\u65e0\u6b4c\u8bcd', next: '', index: -1);
  }

  if (!data.synced) {
    return (
      current: lines.first,
      next: lines.length > 1 ? lines[1] : '',
      index: 0,
    );
  }

  final active = activeLyricIndex(data, position);
  if (active < 0) {
    final first = data.lines.indexWhere((line) => line.text.trim().isNotEmpty);
    if (first < 0) {
      return (current: '\u6682\u65e0\u6b4c\u8bcd', next: '', index: -1);
    }
    final next = _nextNonEmptyLine(data, first);
    return (
      current: data.lines[first].text.trim(),
      next: next?.text.trim() ?? '',
      index: first,
    );
  }

  var current = active;
  while (current >= 0 && data.lines[current].text.trim().isEmpty) {
    current--;
  }
  if (current < 0) {
    current = data.lines.indexWhere((line) => line.text.trim().isNotEmpty);
  }
  if (current < 0) {
    return (current: '\u6682\u65e0\u6b4c\u8bcd', next: '', index: -1);
  }

  final next = _nextNonEmptyLine(data, current);
  return (
    current: data.lines[current].text.trim(),
    next: next?.text.trim() ?? '',
    index: current,
  );
}

LyricLine? _nextNonEmptyLine(LyricsData data, int current) {
  for (var index = current + 1; index < data.lines.length; index++) {
    if (data.lines[index].text.trim().isNotEmpty) return data.lines[index];
  }
  return null;
}
