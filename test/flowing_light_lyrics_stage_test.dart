import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/widgets/lyrics_stage/flowing_light_lyrics_stage.dart';

void main() {
  test('flowing light splits Chinese into glyphs and English into words', () {
    const line = LyricLine(
      text: '陪伴 three 季节',
      start: Duration(seconds: 1),
      end: Duration(seconds: 10),
      words: [
        LyricWord(
          text: '陪伴 three 季节',
          start: Duration(seconds: 1),
          end: Duration(seconds: 10),
        ),
      ],
    );

    final tokens = flowingLightTokensForLine(line);

    expect(tokens.map((token) => token.text), ['陪', '伴', 'three', '季', '节']);
    expect(tokens.map((token) => token.isLatinWord), [
      false,
      false,
      true,
      false,
      false,
    ]);
    expect(tokens.first.start, const Duration(seconds: 1));
    expect(tokens.last.end, const Duration(seconds: 10));
  });

  test('flowing light keeps source word timestamps', () {
    const line = LyricLine(
      text: '放开 oh',
      words: [
        LyricWord(
          text: '放开',
          start: Duration(seconds: 2),
          end: Duration(seconds: 3),
        ),
        LyricWord(
          text: 'oh',
          start: Duration(seconds: 4),
          end: Duration(seconds: 5),
        ),
      ],
    );

    final tokens = flowingLightTokensForLine(line);

    expect(tokens.map((token) => token.text), ['放', '开', 'oh']);
    expect(tokens[2].start, const Duration(seconds: 4));
    expect(tokens[2].end, const Duration(seconds: 5));
  });

  test('flowing light returns no tokens without word timing', () {
    const line = LyricLine(
      text: '只有逐句歌词',
      start: Duration(seconds: 2),
      end: Duration(seconds: 5),
    );

    expect(flowingLightTokensForLine(line), isEmpty);
  });
}
