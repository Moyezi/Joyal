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

class LyricsData {
  final List<LyricLine> lines;
  final bool synced;

  const LyricsData({required this.lines, required this.synced});

  factory LyricsData.fromJson(Map<String, dynamic> json) => LyricsData(
    lines: (json['lines'] as List<dynamic>? ?? [])
        .map(
          (item) => LyricLine.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    synced: json['synced'] == true,
  );

  Map<String, dynamic> toJson() => {
    'lines': lines.map((line) => line.toJson()).toList(),
    'synced': synced,
  };

  bool get isEmpty => lines.every((line) => line.text.trim().isEmpty);
}
