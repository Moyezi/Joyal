class LyricWord {
  final String text;
  final Duration? start;
  final Duration? end;

  const LyricWord({required this.text, this.start, this.end});

  factory LyricWord.fromJson(Map<String, dynamic> json) => LyricWord(
    text: json['text'] as String? ?? '',
    start: json['startMs'] is num
        ? Duration(milliseconds: (json['startMs'] as num).toInt())
        : null,
    end: json['endMs'] is num
        ? Duration(milliseconds: (json['endMs'] as num).toInt())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': start?.inMilliseconds,
    'endMs': end?.inMilliseconds,
  };
}

class LyricLine {
  final Duration? start;
  final Duration? end;
  final String text;
  final List<LyricWord> words;

  const LyricLine({
    required this.text,
    this.start,
    this.end,
    this.words = const [],
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    text: json['text'] as String? ?? '',
    start: json['startMs'] is num
        ? Duration(milliseconds: (json['startMs'] as num).toInt())
        : null,
    end: json['endMs'] is num
        ? Duration(milliseconds: (json['endMs'] as num).toInt())
        : null,
    words: (json['words'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => LyricWord.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': start?.inMilliseconds,
    'endMs': end?.inMilliseconds,
    if (words.isNotEmpty) 'words': words.map((word) => word.toJson()).toList(),
  };
}

enum LyricsContentSource {
  none('none', '暂无歌词'),
  embeddedWordByWord('embeddedWordByWord', '内嵌逐字歌词'),
  ttml('ttml', 'AMLL TTML 逐字歌词'),
  embeddedSynced('embeddedSynced', '内嵌逐句歌词'),
  embeddedUnsynced('embeddedUnsynced', '内嵌纯文本歌词');

  const LyricsContentSource(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static LyricsContentSource fromStorageValue(String? value) {
    return LyricsContentSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => LyricsContentSource.none,
    );
  }
}

class LyricsData {
  final List<LyricLine> lines;
  final bool synced;
  final LyricsContentSource source;

  const LyricsData({
    required this.lines,
    required this.synced,
    this.source = LyricsContentSource.none,
  });

  factory LyricsData.fromJson(Map<String, dynamic> json) => LyricsData(
    lines: (json['lines'] as List<dynamic>? ?? [])
        .map(
          (item) => LyricLine.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    synced: json['synced'] == true,
    source: LyricsContentSource.fromStorageValue(json['source'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'lines': lines.map((line) => line.toJson()).toList(),
    'synced': synced,
    'source': source.storageValue,
  };

  bool get isEmpty => lines.every((line) => line.text.trim().isEmpty);
}
