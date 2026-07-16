import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'song.dart';
import 'lyrics.dart';

class LyricsAiColors {
  final int primary;
  final int stamp;

  const LyricsAiColors({required this.primary, required this.stamp});

  factory LyricsAiColors.fromJson(Map<String, dynamic> json) {
    return LyricsAiColors(
      primary: _storedColor(json['primary']),
      stamp: _storedColor(json['stamp']),
    );
  }

  Map<String, dynamic> toJson() => {
    'primary': _hexColor(primary),
    'stamp': _hexColor(stamp),
  };

  @override
  bool operator ==(Object other) {
    return other is LyricsAiColors &&
        other.primary == primary &&
        other.stamp == stamp;
  }

  @override
  int get hashCode => Object.hash(primary, stamp);
}

class LyricsAiKeywordColors {
  final String text;
  final int light;
  final int dark;

  const LyricsAiKeywordColors({
    required this.text,
    required this.light,
    required this.dark,
  });

  factory LyricsAiKeywordColors.fromJson(Map<String, dynamic> json) {
    return LyricsAiKeywordColors(
      text: json['text'] as String? ?? '',
      light: _storedColor(json['light']),
      dark: _storedColor(json['dark']),
    );
  }

  int colorFor({required bool darkMode}) => darkMode ? dark : light;

  Map<String, dynamic> toJson() => {
    'text': text,
    'light': _hexColor(light),
    'dark': _hexColor(dark),
  };

  @override
  bool operator ==(Object other) {
    return other is LyricsAiKeywordColors &&
        other.text == text &&
        other.light == light &&
        other.dark == dark;
  }

  @override
  int get hashCode => Object.hash(text, light, dark);
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
  final LyricsAiVisualScheme light;
  final LyricsAiVisualScheme dark;

  const LyricsAiVisualContext({required this.light, required this.dark});

  LyricsAiVisualScheme schemeFor({required bool darkMode}) {
    return darkMode ? dark : light;
  }

  Map<String, dynamic> toJson() => {
    'light': light.toJson(),
    'dark': dark.toJson(),
  };
}

class LyricsAiPalette {
  final LyricsAiColors light;
  final LyricsAiColors dark;
  final List<LyricsAiKeywordColors> keywords;
  final String metadataHash;
  final String model;
  final int promptVersion;
  final DateTime generatedAt;

  const LyricsAiPalette({
    required this.light,
    required this.dark,
    this.keywords = const [],
    required this.metadataHash,
    required this.model,
    required this.promptVersion,
    required this.generatedAt,
  });

  LyricsAiColors colorsFor({required bool darkMode}) {
    return darkMode ? dark : light;
  }

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
    final light = json['light'];
    final dark = json['dark'];
    if (light is! Map || dark is! Map) {
      throw const FormatException('AI 歌词配色缓存格式异常');
    }
    return LyricsAiPalette(
      light: LyricsAiColors.fromJson(Map<String, dynamic>.from(light)),
      dark: LyricsAiColors.fromJson(Map<String, dynamic>.from(dark)),
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
    'light': light.toJson(),
    'dark': dark.toJson(),
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
