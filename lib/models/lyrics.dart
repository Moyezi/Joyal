class LyricLine {
  final Duration? start;
  final String text;

  const LyricLine({required this.text, this.start});

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    text: json['text'] as String? ?? '',
    start: json['startMs'] is num
        ? Duration(milliseconds: (json['startMs'] as num).toInt())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': start?.inMilliseconds,
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
