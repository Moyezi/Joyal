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

  test(
    'flowing light scatters common Chinese lines across three to four rows',
    () {
      final shortLayout = flowingLightPlacementsForTokens('陪伴三个季节'.split(''));
      final longLayout = flowingLightPlacementsForTokens(
        '陪伴三个季节还是承受'.split(''),
      );

      expect(shortLayout.map((item) => item.row).toSet().length, 3);
      expect(longLayout.map((item) => item.row).toSet().length, 4);
      for (final layout in [shortLayout, longLayout]) {
        final rowCounts = <int, int>{};
        for (final item in layout) {
          rowCounts.update(item.row, (count) => count + 1, ifAbsent: () => 1);
          expect(item.rotationDegrees, inInclusiveRange(-25, 25));
        }
        expect(
          rowCounts.values.every((count) => count >= 2 && count <= 3),
          isTrue,
        );
      }
    },
  );

  test('flowing light scattered layout is stable for the same lyric', () {
    final first = flowingLightPlacementsForTokens('陪伴三个季节'.split(''));
    final second = flowingLightPlacementsForTokens('陪伴三个季节'.split(''));

    expect(
      first.map((item) => item.rotationDegrees),
      orderedEquals(second.map((item) => item.rotationDegrees)),
    );
    expect(
      first.map((item) => item.rowShift),
      orderedEquals(second.map((item) => item.rowShift)),
    );
  });

  test(
    'flowing light token enters slightly large and settles at full size',
    () {
      expect(flowingLightEntranceScale(0), closeTo(1.16, 0.0001));
      expect(flowingLightEntranceScale(0.5), greaterThan(1));
      expect(flowingLightEntranceScale(1), 1);
    },
  );

  test('flowing light glow is brief and ambient float returns to origin', () {
    expect(flowingLightGlowIntensity(0), 0);
    expect(flowingLightGlowIntensity(0.41), closeTo(1, 0.0001));
    expect(flowingLightGlowIntensity(1), closeTo(0, 0.0001));
    expect(flowingLightFloatFactor(0), 0);
    expect(flowingLightFloatFactor(0.5), closeTo(-0.1, 0.0001));
    expect(flowingLightFloatFactor(1), closeTo(0, 0.0001));
  });

  test('last flowing light token keeps a periodic breathing glow', () {
    expect(flowingLightBreathingGlowIntensity(0), closeTo(0.36, 0.0001));
    expect(flowingLightBreathingGlowIntensity(0.5), closeTo(0.64, 0.0001));
    expect(flowingLightBreathingGlowIntensity(1), closeTo(0.36, 0.0001));
  });
}
