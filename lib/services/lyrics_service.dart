import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import 'app_cache_service.dart';
import 'subsonic_api.dart';

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

  Future<LyricsData> fetch(Song song, {bool forceRefresh = false}) async {
    final cache = AppCacheService.instance;
    final cacheName = _cacheName(song);
    final saved = await cache.readJson(cacheName);
    final cached = _readCached(saved);
    if (!forceRefresh && cached != null && _isFresh(cached)) {
      return cached.data;
    }

    final ttml = await _fetchAmlTtml(song);
    if (ttml != null && !ttml.isEmpty) {
      await _save(cache, cacheName, ttml);
      return ttml;
    }

    try {
      final embedded = await _fetchEmbeddedLyrics(song);
      await _save(cache, cacheName, embedded);
      return embedded;
    } catch (_) {
      if (cached != null && _isUsableStale(cached)) return cached.data;
      rethrow;
    }
  }

  Future<void> clearCachedLyrics(Song song) {
    return AppCacheService.instance.deleteJson(_cacheName(song));
  }

  String _cacheName(Song song) {
    return 'lyrics_${AppCacheService.instance.serverScope(api.baseUrl, '${api.username}|${song.id}')}';
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

  Future<LyricsData> _fetchEmbeddedLyrics(Song song) async {
    var structuredReturnedEmpty = false;
    try {
      final response = await dio.get(api.getLyricsBySongIdUrl(song.id));
      final parsed = _parseStructured(response.data);
      if (parsed != null && !parsed.isEmpty) return parsed;
      structuredReturnedEmpty = _isSuccessfulResponse(response.data);
    } catch (_) {
      // Older Subsonic servers may not implement getLyricsBySongId.
    }

    try {
      final response = await dio.get(
        api.getLyricsUrl(artist: song.artist, title: song.title),
      );
      return _parseLegacy(response.data);
    } catch (_) {
      if (structuredReturnedEmpty) {
        return const LyricsData(lines: [], synced: false);
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
  final match = RegExp(
    r'^(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
  final fraction = (match.group(4) ?? '').padRight(3, '0');
  final milliseconds = int.tryParse(fraction.isEmpty ? '0' : fraction) ?? 0;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}
