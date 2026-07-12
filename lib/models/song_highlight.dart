import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'lyrics.dart';
import 'song.dart';

class SongHighlightSegment {
  final Duration start;
  final Duration end;

  const SongHighlightSegment({required this.start, required this.end});

  bool contains(Duration position) => position >= start && position <= end;

  Map<String, dynamic> toJson() => {
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };
}

class SongHighlightTimeline {
  final List<SongHighlightSegment> segments;
  final String lyricsHash;
  final String model;
  final DateTime analyzedAt;

  const SongHighlightTimeline({
    required this.segments,
    required this.lyricsHash,
    required this.model,
    required this.analyzedAt,
  });

  bool contains(Duration position) =>
      segments.any((segment) => segment.contains(position));

  bool matches({
    required String currentLyricsHash,
    required String currentModel,
  }) {
    return lyricsHash == currentLyricsHash && model == currentModel;
  }

  factory SongHighlightTimeline.fromJson(Map<String, dynamic> json) {
    return SongHighlightTimeline(
      segments: normalizeHighlightSegments(json['segments']),
      lyricsHash: json['lyricsHash'] as String? ?? '',
      model: json['model'] as String? ?? '',
      analyzedAt:
          DateTime.tryParse(json['analyzedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'segments': segments.map((segment) => segment.toJson()).toList(),
    'lyricsHash': lyricsHash,
    'model': model,
    'analyzedAt': analyzedAt.toUtc().toIso8601String(),
  };
}

List<SongHighlightSegment> normalizeHighlightSegments(
  Object? value, {
  Duration? songDuration,
}) {
  final maximumMs = songDuration?.inMilliseconds;
  final parsed =
      (value as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final json = Map<String, dynamic>.from(raw);
            var startMs = (json['startMs'] as num?)?.round() ?? -1;
            var endMs = (json['endMs'] as num?)?.round() ?? -1;
            if (maximumMs != null && maximumMs > 0) {
              startMs = startMs.clamp(0, maximumMs);
              endMs = endMs.clamp(0, maximumMs);
            }
            if (startMs < 0 || endMs <= startMs) return null;
            return SongHighlightSegment(
              start: Duration(milliseconds: startMs),
              end: Duration(milliseconds: endMs),
            );
          })
          .whereType<SongHighlightSegment>()
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  final merged = <SongHighlightSegment>[];
  for (final segment in parsed) {
    if (merged.isEmpty || segment.start > merged.last.end) {
      merged.add(segment);
      continue;
    }
    final previous = merged.removeLast();
    merged.add(
      SongHighlightSegment(
        start: previous.start,
        end: segment.end > previous.end ? segment.end : previous.end,
      ),
    );
  }
  return merged.take(3).toList(growable: false);
}

String lyricsAnalysisHash(Song song, LyricsData lyrics) {
  final normalized = jsonEncode({
    'title': song.title.trim(),
    'artist': song.artist.trim(),
    'album': song.album.trim(),
    'duration': song.duration,
    'lines': lyrics.lines
        .map(
          (line) => {
            'startMs': line.start?.inMilliseconds,
            'endMs': line.end?.inMilliseconds,
            'text': line.text.trim(),
          },
        )
        .toList(),
  });
  return sha256.convert(utf8.encode(normalized)).toString();
}
