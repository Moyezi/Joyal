import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'song.dart';
import 'lyrics.dart';

class LyricsAiKeywordColors {
  final String text;
  final int color;

  const LyricsAiKeywordColors({required this.text, required this.color});

  factory LyricsAiKeywordColors.fromJson(Map<String, dynamic> json) {
    return LyricsAiKeywordColors(
      text: json['text'] as String? ?? '',
      // Read the former dark-mode value so old local records remain
      // manageable until prompt-version invalidation regenerates them.
      color: _storedColor(json['color'] ?? json['dark']),
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'color': _hexColor(color)};

  @override
  bool operator ==(Object other) {
    return other is LyricsAiKeywordColors &&
        other.text == text &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(text, color);
}

class LyricsAiVisualScheme {
  final int backgroundTop;
  final int backgroundBottom;
  final int accent;

  const LyricsAiVisualScheme({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.accent,
  });

  List<int> get backgroundColors => [backgroundTop, backgroundBottom];

  Map<String, dynamic> toJson() => {
    'background_top': _hexColor(backgroundTop),
    'background_bottom': _hexColor(backgroundBottom),
    'accent': _hexColor(accent),
  };
}

class LyricsAiVisualContext {
  final LyricsAiVisualScheme scheme;

  const LyricsAiVisualContext({required this.scheme});

  Map<String, dynamic> toJson() => scheme.toJson();
}

class LyricsAiPalette {
  final List<LyricsAiKeywordColors> keywords;
  final String metadataHash;
  final String model;
  final int promptVersion;
  final DateTime generatedAt;

  const LyricsAiPalette({
    this.keywords = const [],
    required this.metadataHash,
    required this.model,
    required this.promptVersion,
    required this.generatedAt,
  });

  bool matches({
    required String currentMetadataHash,
    required String currentModel,
    required int currentPromptVersion,
  }) {
    return metadataHash == currentMetadataHash &&
        model == currentModel &&
        promptVersion == currentPromptVersion;
  }

  factory LyricsAiPalette.fromJson(Map<String, dynamic> json) {
    return LyricsAiPalette(
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                LyricsAiKeywordColors.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      metadataHash: json['metadataHash'] as String? ?? '',
      model: json['model'] as String? ?? '',
      promptVersion: (json['promptVersion'] as num?)?.toInt() ?? 0,
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'keywords': keywords.map((keyword) => keyword.toJson()).toList(),
    'metadataHash': metadataHash,
    'model': model,
    'promptVersion': promptVersion,
    'generatedAt': generatedAt.toIso8601String(),
  };
}

String lyricsAiPaletteMetadataHash(
  Song song,
  LyricsData lyrics, {
  LyricsAiVisualContext? visualContext,
}) {
  return sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'title': song.title.trim(),
            'album': song.album.trim(),
            'artist': song.artist.trim(),
            'lyrics': lyrics.lines
                .map((line) => line.text.trim())
                .where((line) => line.isNotEmpty)
                .toList(growable: false),
            if (visualContext != null) 'visualContext': visualContext.toJson(),
          }),
        ),
      )
      .toString();
}

int _storedColor(Object? value) {
  if (value is int) return 0xFF000000 | (value & 0xFFFFFF);
  if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    throw const FormatException('AI 歌词配色不是有效的十六进制颜色');
  }
  return 0xFF000000 | int.parse(value.substring(1), radix: 16);
}

String _hexColor(int value) {
  return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
