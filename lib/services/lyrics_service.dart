import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import 'app_cache_service.dart';
import 'subsonic_api.dart';

enum LyricsSource {
  amll('amll', '自动优选歌词', '依次使用内嵌逐字、AMLL TTML，再回退到内嵌逐句歌词'),
  embedded('embedded', 'Navidrome 内嵌歌词', '仅使用当前服务器提供的逐字或逐句歌词');

  const LyricsSource(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;

  static LyricsSource fromStorageValue(String? value) {
    return LyricsSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => LyricsSource.amll,
    );
  }
}

class AmlLyricsReference {
  final String directory;
  final String lyricId;

  const AmlLyricsReference({required this.directory, required this.lyricId});
}

class AmlLyricsIndex {
  static const assetPath = 'raw-lyrics-index.jsonl';

  final Future<String> Function() _loadAsset;
  Future<List<_AmlLyricsIndexEntry>>? _entries;

  AmlLyricsIndex({Future<String> Function()? loadAsset})
    : _loadAsset = loadAsset ?? _loadBundledAsset;

  Future<AmlLyricsReference?> match(Song song) async {
    final songTitle = _normalizeLookupText(song.title);
    final songArtists = _artistKeys(song.artist);
    final songAlbum = _normalizeLookupText(song.album);
    if (songTitle.isEmpty || songArtists.isEmpty) return null;

    final candidates = <({int score, _AmlLyricsIndexEntry entry})>[];
    for (final entry in await _loadEntries()) {
      if (!entry.titles.contains(songTitle)) continue;

      final artistMatches = entry.artists.any(songArtists.contains);
      final albumMatches =
          songAlbum.isNotEmpty && entry.albums.contains(songAlbum);
      if (!artistMatches && !albumMatches) continue;

      candidates.add((
        score: 100 + (artistMatches ? 50 : 0) + (albumMatches ? 20 : 0),
        entry: entry,
      ));
    }
    if (candidates.isEmpty) return null;

    candidates.sort((left, right) => right.score.compareTo(left.score));
    final references = candidates.first.entry.references;
    return references.isEmpty ? null : references.first;
  }

  Future<List<_AmlLyricsIndexEntry>> _loadEntries() {
    return _entries ??= _load();
  }

  Future<List<_AmlLyricsIndexEntry>> _load() async {
    final contents = await _loadAsset();
    return compute(_parseAmlLyricsIndex, contents);
  }

  static Future<String> _loadBundledAsset() => rootBundle.loadString(assetPath);
}

class LyricsService {
  static const _freshCacheAge = Duration(days: 30);
  static const _emptyCacheAge = Duration(days: 7);
  static const _staleCacheAge = Duration(days: 90);
  static const _amllBaseUrl =
      'https://raw.githubusercontent.com/amll-dev/amll-ttml-db/refs/heads/main';

  static final AmlLyricsIndex _defaultAmlLyricsIndex = AmlLyricsIndex();

  final SubsonicApi api;
  final Dio dio;
  final AmlLyricsIndex amllIndex;

  LyricsService({
    required this.api,
    required this.dio,
    AmlLyricsIndex? amllIndex,
  }) : amllIndex = amllIndex ?? _defaultAmlLyricsIndex;

  Future<LyricsData> fetch(
    Song song, {
    bool forceRefresh = false,
    LyricsSource source = LyricsSource.amll,
  }) async {
    final cache = AppCacheService.instance;
    final cacheName = _cacheName(song, source);
    final saved = await cache.readJson(cacheName);
    final cached = _readCached(saved);
    if (!forceRefresh && cached != null && _isFresh(cached)) {
      return cached.data;
    }

    Object? lastError;
    _EmbeddedLyricsCandidates structured = const _EmbeddedLyricsCandidates();
    try {
      final response = await dio.get(
        api.getLyricsBySongIdUrl(song.id, enhanced: true),
      );
      structured = _parseStructured(response.data);
      if (structured.wordByWord case final wordByWord?) {
        await _save(cache, cacheName, wordByWord);
        return wordByWord;
      }
    } catch (error) {
      lastError = error;
    }

    LyricsData? legacy;
    try {
      final response = await dio.get(
        api.getLyricsUrl(artist: song.artist, title: song.title),
      );
      legacy = _parseLegacy(response.data);
      if (legacy.source == LyricsContentSource.embeddedWordByWord) {
        await _save(cache, cacheName, legacy);
        return legacy;
      }
    } catch (error) {
      lastError = error;
    }

    if (source == LyricsSource.amll) {
      final ttml = await _fetchAmlTtml(song);
      if (ttml != null && !ttml.isEmpty) {
        await _save(cache, cacheName, ttml);
        return ttml;
      }
    }

    final lineByLine = structured.lineByLine;
    if (lineByLine != null && !lineByLine.isEmpty) {
      await _save(cache, cacheName, lineByLine);
      return lineByLine;
    }
    if (legacy != null) {
      await _save(cache, cacheName, legacy);
      return legacy;
    }
    if (structured.returnedSuccessfully) {
      const empty = LyricsData(lines: [], synced: false);
      await _save(cache, cacheName, empty);
      return empty;
    }
    if (cached != null && _isUsableStale(cached)) return cached.data;
    if (lastError != null) throw lastError;
    const empty = LyricsData(lines: [], synced: false);
    await _save(cache, cacheName, empty);
    return empty;
  }

  Future<void> clearCachedLyrics(
    Song song, {
    LyricsSource source = LyricsSource.amll,
  }) {
    return AppCacheService.instance.deleteJson(_cacheName(song, source));
  }

  String _cacheName(Song song, LyricsSource source) {
    return 'lyrics_v2_${AppCacheService.instance.serverScope(api.baseUrl, '${api.username}|${song.id}')}_${source.storageValue}';
  }

  Future<LyricsData?> _fetchAmlTtml(Song song) async {
    try {
      final reference = await amllIndex.match(song);
      if (reference == null) return null;
      final url =
          '$_amllBaseUrl/${reference.directory}/'
          '${Uri.encodeComponent(reference.lyricId)}.ttml';
      final response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return _parseTtml(response.data ?? '');
    } catch (_) {
      // The public index and lyric files are optional. Embedded lyrics remain
      // available when matching, downloading, or parsing is unsuccessful.
      return null;
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

  _EmbeddedLyricsCandidates _parseStructured(dynamic data) {
    final returnedSuccessfully = _isSuccessfulResponse(data);
    if (data is! Map) {
      return _EmbeddedLyricsCandidates(
        returnedSuccessfully: returnedSuccessfully,
      );
    }
    final root = data['subsonic-response'];
    if (root is! Map) {
      return _EmbeddedLyricsCandidates(
        returnedSuccessfully: returnedSuccessfully,
      );
    }
    final lyricsList = root['lyricsList'];
    if (lyricsList is! Map) {
      return _EmbeddedLyricsCandidates(
        returnedSuccessfully: returnedSuccessfully,
      );
    }
    dynamic entries = lyricsList['structuredLyrics'];
    if (entries is Map) entries = [entries];
    if (entries is! List || entries.isEmpty) {
      return _EmbeddedLyricsCandidates(
        returnedSuccessfully: returnedSuccessfully,
      );
    }

    LyricsData? wordByWord;
    final lineCandidates = <LyricsData>[];
    for (final entry in entries.whereType<Map>()) {
      final kind = entry['kind']?.toString();
      if (kind != null && kind.isNotEmpty && kind != 'main') continue;
      wordByWord ??= _parseCueLines(entry);
      final lineByLine = _parseStructuredLines(entry);
      if (lineByLine != null && !lineByLine.isEmpty) {
        if (lineByLine.source == LyricsContentSource.embeddedWordByWord) {
          wordByWord ??= lineByLine;
        } else {
          lineCandidates.add(lineByLine);
        }
      }
    }
    lineCandidates.sort(
      (left, right) =>
          _lineCandidateScore(right).compareTo(_lineCandidateScore(left)),
    );
    return _EmbeddedLyricsCandidates(
      wordByWord: wordByWord,
      lineByLine: lineCandidates.isEmpty ? null : lineCandidates.first,
      returnedSuccessfully: returnedSuccessfully,
    );
  }

  LyricsData? _parseStructuredLines(Map<dynamic, dynamic> selected) {
    dynamic rawLines = selected['line'];
    if (rawLines is Map) rawLines = [rawLines];
    if (rawLines is! List) return null;
    final rawText = rawLines
        .whereType<Map>()
        .map((raw) {
          final value = raw['value'];
          return value is List ? value.join('') : value?.toString() ?? '';
        })
        .join('\n');
    final lrc = _parseLrc(rawText);
    if (lrc != null && !lrc.isEmpty) return lrc;

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
    if (_looksLikeFragmentedWordLines(lines)) return null;
    final synced = selected['synced'] == true;
    return LyricsData(
      lines: lines,
      synced: synced,
      source: synced
          ? LyricsContentSource.embeddedSynced
          : LyricsContentSource.embeddedUnsynced,
    );
  }

  LyricsData _parseLegacy(dynamic data) {
    if (data is! Map) return const LyricsData(lines: [], synced: false);
    final root = data['subsonic-response'];
    final lyrics = root is Map ? root['lyrics'] : null;
    final value = lyrics is Map ? lyrics['value'] : null;
    final text = value?.toString() ?? '';
    final lrc = _parseLrc(text);
    if (lrc != null && !lrc.isEmpty) return lrc;
    return LyricsData(
      lines: text
          .split(RegExp(r'\r?\n'))
          .map((line) => LyricLine(text: line))
          .toList(),
      synced: false,
      source: text.trim().isEmpty
          ? LyricsContentSource.none
          : LyricsContentSource.embeddedUnsynced,
    );
  }
}

LyricsData? _parseCueLines(Map<dynamic, dynamic> entry) {
  if (entry['synced'] != true) return null;
  dynamic rawCueLines = entry['cueLine'];
  if (rawCueLines is Map) rawCueLines = [rawCueLines];
  if (rawCueLines is! List || rawCueLines.isEmpty) return null;

  dynamic rawFallbackLines = entry['line'];
  if (rawFallbackLines is Map) rawFallbackLines = [rawFallbackLines];
  final fallbackLines = rawFallbackLines is List
      ? rawFallbackLines.whereType<Map>().toList(growable: false)
      : const <Map>[];

  final lines = <LyricLine>[];
  final seenIndexes = <int>{};
  for (var position = 0; position < rawCueLines.length; position++) {
    final raw = rawCueLines[position];
    if (raw is! Map) continue;
    final index = raw['index'] is num
        ? (raw['index'] as num).toInt()
        : position;
    // Multiple vocal agents can share one line index. OpenSubsonic guarantees
    // that the main agent is first, so rendering only the first avoids duplicate
    // lyric rows while keeping the combined `line` value as fallback text.
    if (!seenIndexes.add(index)) continue;

    final fallback = index >= 0 && index < fallbackLines.length
        ? fallbackLines[index]
        : null;
    final value = raw['value']?.toString();
    final fallbackValue = fallback?['value'];
    final text = value != null && value.isNotEmpty
        ? value
        : fallbackValue is List
        ? fallbackValue.join('')
        : fallbackValue?.toString() ?? '';
    final start =
        _durationFromMilliseconds(raw['start']) ??
        _durationFromMilliseconds(fallback?['start']);
    final end = _durationFromMilliseconds(raw['end']);
    final words = _parseCueWords(raw['cue'], text, lineEnd: end);
    if (text.trim().isEmpty || words.every((word) => word.start == null)) {
      continue;
    }
    lines.add(LyricLine(text: text, start: start, end: end, words: words));
  }
  if (lines.isEmpty) return null;
  lines.sort((left, right) {
    final leftStart = left.start ?? Duration.zero;
    final rightStart = right.start ?? Duration.zero;
    return leftStart.compareTo(rightStart);
  });
  return LyricsData(
    lines: lines,
    synced: true,
    source: LyricsContentSource.embeddedWordByWord,
  );
}

List<LyricWord> _parseCueWords(
  dynamic rawCues,
  String lineText, {
  Duration? lineEnd,
}) {
  if (rawCues is Map) rawCues = [rawCues];
  if (rawCues is! List) return const [];
  final cues = rawCues.whereType<Map>().toList(growable: false);
  if (cues.isEmpty) return const [];

  final textBytes = utf8.encode(lineText);
  final hasByteRanges = cues.every(
    (cue) => cue['byteStart'] is num && cue['byteEnd'] is num,
  );
  if (!hasByteRanges) {
    return cues
        .map(
          (cue) => LyricWord(
            text: cue['value']?.toString() ?? '',
            start: _durationFromMilliseconds(cue['start']),
            end: _durationFromMilliseconds(cue['end']),
          ),
        )
        .where((word) => word.text.isNotEmpty)
        .toList(growable: false);
  }

  final words = <LyricWord>[];
  var cursor = 0;
  Duration? previousEnd;
  for (final cue in cues) {
    final byteStart = (cue['byteStart'] as num).toInt().clamp(
      0,
      textBytes.length,
    );
    final byteEndExclusive = ((cue['byteEnd'] as num).toInt() + 1).clamp(
      byteStart,
      textBytes.length,
    );
    final start = _durationFromMilliseconds(cue['start']);
    final end = _durationFromMilliseconds(cue['end']);
    if (byteStart > cursor) {
      final gap = utf8.decode(textBytes.sublist(cursor, byteStart));
      if (gap.isNotEmpty) {
        words.add(LyricWord(text: gap, start: previousEnd, end: start));
      }
    }
    final exactText = byteEndExclusive > byteStart
        ? utf8.decode(textBytes.sublist(byteStart, byteEndExclusive))
        : cue['value']?.toString() ?? '';
    if (exactText.isNotEmpty) {
      words.add(LyricWord(text: exactText, start: start, end: end));
    }
    cursor = byteEndExclusive;
    previousEnd = end ?? start ?? previousEnd;
  }
  if (cursor < textBytes.length) {
    words.add(
      LyricWord(
        text: utf8.decode(textBytes.sublist(cursor)),
        start: previousEnd,
        end: lineEnd,
      ),
    );
  }
  return words;
}

Duration? _durationFromMilliseconds(dynamic value) {
  return value is num ? Duration(milliseconds: value.round()) : null;
}

int _lineCandidateScore(LyricsData data) {
  final textLength = data.lines.fold<int>(
    0,
    (sum, line) => sum + line.text.trim().runes.length,
  );
  return (data.synced ? 100000 : 0) + textLength;
}

bool _looksLikeFragmentedWordLines(List<LyricLine> lines) {
  final nonEmpty = lines.where((line) => line.text.trim().isNotEmpty).toList();
  if (nonEmpty.length < 8) return false;
  final singleCharacterLines = nonEmpty.where(
    (line) => line.text.trim().runes.length <= 1,
  );
  return singleCharacterLines.length / nonEmpty.length >= 0.65;
}

LyricsData? _parseLrc(String source) {
  if (!source.contains('[')) return null;
  final physicalLines = const LineSplitter().convert(source);
  var offset = Duration.zero;
  final offsetPattern = RegExp(
    r'^\s*\[offset:([+-]?\d+)\]\s*$',
    caseSensitive: false,
  );
  for (final rawLine in physicalLines) {
    final match = offsetPattern.firstMatch(rawLine);
    if (match != null) {
      offset = Duration(milliseconds: int.tryParse(match.group(1)!) ?? 0);
    }
  }

  final linePattern = RegExp(
    r'^\s*\[((?:\d+:)?\d{1,2}:\d{2}(?:[.,]\d+)?)\](.*)$',
  );
  final wordPattern = RegExp(r'<((?:\d+:)?\d{1,2}:\d{2}(?:[.,]\d+)?)>');
  final lines = <LyricLine>[];
  var hasWordTiming = false;
  for (final rawLine in physicalLines) {
    final lineMatch = linePattern.firstMatch(rawLine);
    if (lineMatch == null) continue;
    final lineStart = _withOffset(_parseLrcTime(lineMatch.group(1)), offset);
    final content = lineMatch.group(2) ?? '';
    final markers = wordPattern.allMatches(content).toList(growable: false);
    if (markers.isEmpty) {
      lines.add(LyricLine(text: content, start: lineStart));
      continue;
    }

    final words = <LyricWord>[];
    for (var index = 0; index < markers.length; index++) {
      final marker = markers[index];
      final nextStart = index + 1 < markers.length
          ? markers[index + 1].start
          : content.length;
      final text = content.substring(marker.end, nextStart);
      if (text.isEmpty) continue;
      final start = _withOffset(_parseLrcTime(marker.group(1)), offset);
      final end = index + 1 < markers.length
          ? _withOffset(_parseLrcTime(markers[index + 1].group(1)), offset)
          : null;
      words.add(LyricWord(text: text, start: start, end: end));
    }
    final text = words.map((word) => word.text).join();
    if (text.trim().isEmpty) continue;
    hasWordTiming = hasWordTiming || words.any((word) => word.start != null);
    final lineEnd = markers.isEmpty
        ? null
        : _withOffset(_parseLrcTime(markers.last.group(1)), offset);
    lines.add(
      LyricLine(text: text, start: lineStart, end: lineEnd, words: words),
    );
  }
  if (lines.isEmpty) return null;
  lines.sort((left, right) {
    final leftStart = left.start ?? Duration.zero;
    final rightStart = right.start ?? Duration.zero;
    return leftStart.compareTo(rightStart);
  });
  return LyricsData(
    lines: lines,
    synced: lines.any((line) => line.start != null),
    source: hasWordTiming
        ? LyricsContentSource.embeddedWordByWord
        : LyricsContentSource.embeddedSynced,
  );
}

Duration? _parseLrcTime(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d+))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: _fractionalMilliseconds(match.group(4)),
  );
}

Duration? _withOffset(Duration? value, Duration offset) {
  if (value == null) return null;
  final result = value + offset;
  return result.isNegative ? Duration.zero : result;
}

class _EmbeddedLyricsCandidates {
  final LyricsData? wordByWord;
  final LyricsData? lineByLine;
  final bool returnedSuccessfully;

  const _EmbeddedLyricsCandidates({
    this.wordByWord,
    this.lineByLine,
    this.returnedSuccessfully = false,
  });
}

class _AmlLyricsIndexEntry {
  final Set<String> titles;
  final Set<String> artists;
  final Set<String> albums;
  final List<AmlLyricsReference> references;

  const _AmlLyricsIndexEntry({
    required this.titles,
    required this.artists,
    required this.albums,
    required this.references,
  });
}

List<_AmlLyricsIndexEntry> _parseAmlLyricsIndex(String source) {
  const sourceDirectories = <String, String>{
    'qqMusicId': 'qq-lyrics',
    'ncmMusicId': 'ncm-lyrics',
    'spotifyId': 'spotify-lyrics',
    'appleMusicId': 'am-lyrics',
  };

  final entries = <_AmlLyricsIndexEntry>[];
  for (final line in const LineSplitter().convert(source)) {
    if (line.trim().isEmpty) continue;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) continue;
      final metadata = _parseMetadata(decoded['metadata']);
      final titles = _normalizedValues(metadata['musicName']);
      final artists = _artistValues(metadata['artists']);
      if (titles.isEmpty || artists.isEmpty) continue;

      final references = <AmlLyricsReference>[];
      for (final entry in sourceDirectories.entries) {
        for (final id in metadata[entry.key] ?? const <String>[]) {
          final lyricId = id.trim();
          if (lyricId.isEmpty) continue;
          references.add(
            AmlLyricsReference(directory: entry.value, lyricId: lyricId),
          );
        }
      }
      if (references.isEmpty) continue;

      entries.add(
        _AmlLyricsIndexEntry(
          titles: titles,
          artists: artists,
          albums: _normalizedValues(metadata['album']),
          references: references,
        ),
      );
    } catch (_) {
      // A malformed index row must not make the rest of the bundled index
      // unavailable.
    }
  }
  return entries;
}

Map<String, List<String>> _parseMetadata(dynamic rawMetadata) {
  final metadata = <String, List<String>>{};
  if (rawMetadata is! List) return metadata;
  for (final pair in rawMetadata) {
    if (pair is! List || pair.length < 2) continue;
    final key = pair.first?.toString();
    if (key == null || key.isEmpty) continue;
    final rawValues = pair[1];
    final values = rawValues is List ? rawValues : [rawValues];
    metadata[key] = values
        .whereType<Object>()
        .map((value) => value.toString())
        .toList(growable: false);
  }
  return metadata;
}

Set<String> _normalizedValues(Iterable<String>? values) {
  if (values == null) return const {};
  return values
      .map(_normalizeLookupText)
      .where((value) => value.isNotEmpty)
      .toSet();
}

Set<String> _artistValues(Iterable<String>? values) {
  if (values == null) return const {};
  return values.expand(_artistKeys).toSet();
}

Set<String> _artistKeys(String value) {
  final keys = <String>{};
  final entire = _normalizeLookupText(value);
  if (entire.isNotEmpty) keys.add(entire);
  for (final part in value.split(
    RegExp(
      r'\s*(?:,|，|/|、|&|＆|;|；|\bfeat\.?\b|\bft\.?\b|\bfeaturing\b)\s*',
      caseSensitive: false,
    ),
  )) {
    final normalized = _normalizeLookupText(part);
    if (normalized.isNotEmpty) keys.add(normalized);
  }
  return keys;
}

String _normalizeLookupText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'（[^）]*）|\([^)]*\)|\[[^\]]*\]|【[^】]*】'), '')
      .replaceAll(RegExp(r'[\s\-_.,!！?？:：;；/\\|&＋+*~`"“”‘’·•]'), '');
}

LyricsData _parseTtml(String source) {
  final document = XmlDocument.parse(source);
  final lines = <LyricLine>[];
  for (final paragraph in document.descendants.whereType<XmlElement>().where(
    (element) => element.name.local == 'p',
  )) {
    final words = _parseTtmlWords(paragraph);
    final text = words.map((word) => word.text).join().trim();
    if (text.isEmpty) continue;
    lines.add(
      LyricLine(
        text: text,
        start: _parseTtmlTime(_attributeValue(paragraph, 'begin')),
        end: _parseTtmlTime(_attributeValue(paragraph, 'end')),
        words: words,
      ),
    );
  }
  return LyricsData(
    lines: lines,
    synced: lines.any((line) => line.start != null),
    source: LyricsContentSource.ttml,
  );
}

List<LyricWord> _parseTtmlWords(XmlElement paragraph) {
  final words = <LyricWord>[];
  Duration? previousEnd;

  void appendText(String text) {
    if (text.isEmpty) return;
    if (text.trim().isEmpty) {
      if (!text.contains('\n') && words.isNotEmpty) {
        final previous = words.removeLast();
        words.add(
          LyricWord(
            text: '${previous.text} ',
            start: previous.start,
            end: previous.end,
          ),
        );
      }
      return;
    }
    words.add(LyricWord(text: text, start: previousEnd, end: previousEnd));
  }

  void visit(Iterable<XmlNode> nodes) {
    for (final node in nodes) {
      if (node is XmlText) {
        appendText(node.value);
        continue;
      }
      if (node is! XmlElement) continue;
      final role = _attributeValue(node, 'role')?.toLowerCase();
      if (role == 'x-bg' || role == 'x-translation' || role == 'x-roman') {
        continue;
      }

      final childElements = node.children.whereType<XmlElement>().toList();
      final isTimedSpan =
          node.name.local == 'span' &&
          _parseTtmlTime(_attributeValue(node, 'begin')) != null &&
          childElements.isEmpty;
      if (isTimedSpan) {
        final text = node.innerText;
        if (text.trim().isEmpty) continue;
        final start = _parseTtmlTime(_attributeValue(node, 'begin'));
        final end = _parseTtmlTime(_attributeValue(node, 'end'));
        words.add(LyricWord(text: text, start: start, end: end));
        previousEnd = end ?? start ?? previousEnd;
      } else {
        visit(node.children);
      }
    }
  }

  visit(paragraph.children);
  while (words.isNotEmpty && words.first.text.trim().isEmpty) {
    words.removeAt(0);
  }
  while (words.isNotEmpty && words.last.text.trim().isEmpty) {
    words.removeLast();
  }
  return words;
}

String? _attributeValue(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) return attribute.value;
  }
  return null;
}

Duration? _parseTtmlTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final text = value.trim();
  final clockMatch = RegExp(
    r'^(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d+))?$',
  ).firstMatch(text);
  if (clockMatch != null) {
    final hours = int.tryParse(clockMatch.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(clockMatch.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(clockMatch.group(3) ?? '') ?? 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: _fractionalMilliseconds(clockMatch.group(4)),
    );
  }

  // AMLL commonly uses offset time (for example `15.865`) until the first
  // minute, then switches to the clock-time form (`1:00.186`). Supporting
  // both forms keeps the full timeline seekable and synchronized.
  final offsetMatch = RegExp(
    r'^(\d+)(?:[.,](\d+))?(ms|h|m|s)?$',
  ).firstMatch(text);
  if (offsetMatch == null) return null;

  final whole = int.tryParse(offsetMatch.group(1) ?? '');
  if (whole == null) return null;
  final fraction = _fractionalMilliseconds(offsetMatch.group(2));
  final unit = offsetMatch.group(3) ?? 's';
  return switch (unit) {
    'ms' => Duration(milliseconds: whole),
    'm' => Duration(minutes: whole, milliseconds: fraction * 60),
    'h' => Duration(hours: whole, milliseconds: fraction * 60 * 60),
    _ => Duration(seconds: whole, milliseconds: fraction),
  };
}

int _fractionalMilliseconds(String? fraction) {
  if (fraction == null || fraction.isEmpty) return 0;
  final normalized = fraction.padRight(3, '0');
  return int.tryParse(normalized.substring(0, 3)) ?? 0;
}
