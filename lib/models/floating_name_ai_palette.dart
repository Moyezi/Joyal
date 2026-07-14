import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'song.dart';

const int floatingNameAiPalettePromptVersion = 4;

class FloatingNameAiColors {
  final int primary;
  final int stamp;

  const FloatingNameAiColors({required this.primary, required this.stamp});

  factory FloatingNameAiColors.fromJson(Map<String, dynamic> json) {
    return FloatingNameAiColors(
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
    return other is FloatingNameAiColors &&
        other.primary == primary &&
        other.stamp == stamp;
  }

  @override
  int get hashCode => Object.hash(primary, stamp);
}

class FloatingNameAiPalette {
  final FloatingNameAiColors light;
  final FloatingNameAiColors dark;
  final String metadataHash;
  final String model;
  final int promptVersion;
  final DateTime generatedAt;

  const FloatingNameAiPalette({
    required this.light,
    required this.dark,
    required this.metadataHash,
    required this.model,
    required this.promptVersion,
    required this.generatedAt,
  });

  bool matches({
    required String currentMetadataHash,
    required String currentModel,
  }) {
    return metadataHash == currentMetadataHash &&
        model == currentModel &&
        promptVersion == floatingNameAiPalettePromptVersion;
  }

  factory FloatingNameAiPalette.fromJson(Map<String, dynamic> json) {
    final light = json['light'];
    final dark = json['dark'];
    if (light is! Map || dark is! Map) {
      throw const FormatException('AI 歌词配色缓存格式异常');
    }
    return FloatingNameAiPalette(
      light: FloatingNameAiColors.fromJson(Map<String, dynamic>.from(light)),
      dark: FloatingNameAiColors.fromJson(Map<String, dynamic>.from(dark)),
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
    'metadataHash': metadataHash,
    'model': model,
    'promptVersion': promptVersion,
    'generatedAt': generatedAt.toIso8601String(),
  };
}

String floatingNameAiPaletteMetadataHash(Song song) {
  return sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'title': song.title.trim(),
            'album': song.album.trim(),
            'artist': song.artist.trim(),
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
