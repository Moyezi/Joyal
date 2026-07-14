import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/floating_name_ai_palette.dart';
import 'package:joyal_music/models/music_classification.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/services/deepseek_floating_name_palette_service.dart';

void main() {
  const song = Song(
    id: 'song-1',
    parent: 'album-1',
    title: '浮名',
    album: '远方',
    artist: '小 Jo',
    duration: 240,
    coverArt: 'cover-1',
    contentType: 'audio/mpeg',
    suffix: 'mp3',
  );

  test('DeepSeek palette payload sends only textual song metadata', () {
    final body = floatingNameAiPaletteRequestBody(
      settings: const AiClassificationSettings(
        apiBaseUrl: 'https://private.example.test',
      ),
      song: song,
    );
    final messages = body['messages'] as List<dynamic>;
    final system = messages.first as Map<String, dynamic>;
    final user = messages.last as Map<String, dynamic>;
    final payload = jsonDecode(user['content'] as String) as Map;

    expect(payload.keys, ['song']);
    expect(payload['song'], {'title': '浮名', 'album': '远方', 'artist': '小 Jo'});
    expect(user['content'], isNot(contains('private.example.test')));
    expect(user['content'], isNot(contains('song-1')));
    expect(user['content'], isNot(contains('cover-1')));
    expect(user['content'], isNot(contains('duration')));
    expect(system['content'], isNot(contains('ornament')));
    expect(system['content'], contains('文字色和高光光晕色'));
    expect(system['content'], contains('圆形光环颜色'));
  });

  test('valid AI palette is parsed into opaque ARGB colors', () {
    final palette = parseFloatingNameAiPaletteContent(
      jsonEncode({
        'light': {'primary': '#3F5F8A', 'stamp': '#4B6F9F'},
        'dark': {'primary': '#AFCBFF', 'stamp': '#BED5FF'},
      }),
    );

    expect(palette.light.primary, 0xFF3F5F8A);
    expect(palette.dark.stamp, 0xFFBED5FF);
  });

  test('invalid AI response uses the restrained fallback palette', () {
    final palette = parseFloatingNameAiPaletteContent('not-json');

    expect(palette.light.primary, 0xFF3F5F8A);
    expect(palette.dark.primary, 0xFFAFCBFF);
  });

  test('cached palette matches metadata, model, and prompt version', () {
    final metadataHash = floatingNameAiPaletteMetadataHash(song);
    final palette = FloatingNameAiPalette(
      light: const FloatingNameAiColors(primary: 0xFF3F5F8A, stamp: 0xFF4B6F9F),
      dark: const FloatingNameAiColors(primary: 0xFFAFCBFF, stamp: 0xFFBED5FF),
      metadataHash: metadataHash,
      model: 'deepseek-chat',
      promptVersion: floatingNameAiPalettePromptVersion,
      generatedAt: DateTime.utc(2026, 7, 14),
    );
    final restored = FloatingNameAiPalette.fromJson(palette.toJson());

    expect((palette.toJson()['light'] as Map).keys, ['primary', 'stamp']);

    expect(
      restored.matches(
        currentMetadataHash: metadataHash,
        currentModel: 'deepseek-chat',
      ),
      isTrue,
    );
    expect(
      restored.matches(
        currentMetadataHash: metadataHash,
        currentModel: 'deepseek-reasoner',
      ),
      isFalse,
    );
  });
}
