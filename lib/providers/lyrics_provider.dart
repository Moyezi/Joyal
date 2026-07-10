import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/lyrics_service.dart';
import '../services/subsonic_api.dart';
import 'library_provider.dart';
import 'lyrics_source_provider.dart';
import 'player_provider.dart';

final Map<String, Future<LyricsData>> _lyricsCache = {};
final Expando<_LyricTimeline> _lyricTimelines = Expando<_LyricTimeline>();

String lyricsCacheKeyFor(
  SubsonicApi api,
  Song song, [
  LyricsSource source = LyricsSource.amll,
]) {
  return '${AppCacheService.instance.serverScope(api.baseUrl, api.username)}_'
      '${song.id}_${source.storageValue}';
}

void invalidateLyricsMemoryCache(
  SubsonicApi api,
  Song song, {
  LyricsSource? source,
}) {
  if (source != null) {
    _lyricsCache.remove(lyricsCacheKeyFor(api, song, source));
    return;
  }
  for (final value in LyricsSource.values) {
    _lyricsCache.remove(lyricsCacheKeyFor(api, song, value));
  }
}

final lyricsProvider = FutureProvider.family<LyricsData, Song>((ref, song) {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) {
    return Future.value(const LyricsData(lines: [], synced: false));
  }

  final source = ref.watch(lyricsSourceForSongProvider(song));
  final key = lyricsCacheKeyFor(api, song, source);
  return _lyricsCache.putIfAbsent(key, () {
    return LyricsService(
      api: api,
      dio: ref.read(dioProvider),
    ).fetch(song, source: source).catchError((Object error) {
      _lyricsCache.remove(key);
      throw error;
    });
  });
});

double lyricWordProgress(LyricWord word, Duration position) {
  final start = word.start;
  if (start == null) return 1;
  if (position < start) return 0;
  final end = word.end;
  if (end == null || end <= start) return 1;
  return ((position - start).inMicroseconds / (end - start).inMicroseconds)
      .clamp(0.0, 1.0)
      .toDouble();
}

int activeLyricIndex(LyricsData data, Duration position) {
  if (!data.synced) return -1;
  final timeline = _lyricTimelines[data] ??= _LyricTimeline(data);
  return timeline.activeIndexAt(position);
}

({String current, String next, int index}) lyricPairForPosition(
  LyricsData data,
  Duration position,
) {
  final first = _firstNonEmptyLineIndex(data);
  if (first < 0) {
    return (current: '\u6682\u65e0\u6b4c\u8bcd', next: '', index: -1);
  }

  if (!data.synced) {
    final next = _nextNonEmptyLine(data, first);
    return (
      current: data.lines[first].text.trim(),
      next: next?.text.trim() ?? '',
      index: 0,
    );
  }

  final active = activeLyricIndex(data, position);
  if (active < 0) {
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
    current = first;
  }

  final next = _nextNonEmptyLine(data, current);
  return (
    current: data.lines[current].text.trim(),
    next: next?.text.trim() ?? '',
    index: current,
  );
}

int _firstNonEmptyLineIndex(LyricsData data) {
  for (var index = 0; index < data.lines.length; index++) {
    if (data.lines[index].text.trim().isNotEmpty) return index;
  }
  return -1;
}

LyricLine? _nextNonEmptyLine(LyricsData data, int current) {
  for (var index = current + 1; index < data.lines.length; index++) {
    if (data.lines[index].text.trim().isNotEmpty) return data.lines[index];
  }
  return null;
}

class _LyricTimeline {
  final LyricsData data;
  final List<int> indexes;
  final List<int> startsInMicroseconds;
  final bool isOrdered;

  const _LyricTimeline._({
    required this.data,
    required this.indexes,
    required this.startsInMicroseconds,
    required this.isOrdered,
  });

  factory _LyricTimeline(LyricsData data) {
    final indexes = <int>[];
    final starts = <int>[];
    final ordered = _populateTimeline(data, indexes: indexes, starts: starts);
    return _LyricTimeline._(
      data: data,
      indexes: indexes,
      startsInMicroseconds: starts,
      isOrdered: ordered,
    );
  }

  int activeIndexAt(Duration position) {
    if (!isOrdered) return _linearActiveIndex(position);
    if (indexes.isEmpty) return -1;

    final target = position.inMicroseconds;
    var low = 0;
    var high = startsInMicroseconds.length - 1;
    var match = -1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (startsInMicroseconds[middle] <= target) {
        match = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return match < 0 ? -1 : indexes[match];
  }

  int _linearActiveIndex(Duration position) {
    var active = -1;
    for (var index = 0; index < data.lines.length; index++) {
      final start = data.lines[index].start;
      if (start != null && start <= position) active = index;
    }
    return active;
  }

  static bool _populateTimeline(
    LyricsData data, {
    required List<int> indexes,
    required List<int> starts,
  }) {
    var ordered = true;
    int? previous;
    for (var index = 0; index < data.lines.length; index++) {
      final start = data.lines[index].start;
      if (start == null) continue;
      final value = start.inMicroseconds;
      if (previous != null && value < previous) ordered = false;
      previous = value;
      indexes.add(index);
      starts.add(value);
    }
    return ordered;
  }
}
