import 'package:flutter/material.dart';
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

  test('flowing light highlight lasts until the next token appears', () {
    const line = LyricLine(
      text: '放开 oh',
      end: Duration(seconds: 7),
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

    expect(
      flowingLightHighlightEndForToken(tokens, 1, lineEnd: line.end),
      const Duration(seconds: 4),
    );
    expect(
      flowingLightHighlightEndForToken(tokens, 2, lineEnd: line.end),
      const Duration(seconds: 7),
    );
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
          expect(
            item.rotationDegrees,
            inInclusiveRange(
              -flowingLightMaximumRotationDegrees,
              flowingLightMaximumRotationDegrees,
            ),
          );
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

  test('flowing light glow fades after the next token appears', () {
    const hold = Duration(seconds: 1);
    expect(
      flowingLightAdaptiveGlowIntensity(
        elapsed: Duration.zero,
        holdUntilNext: hold,
      ),
      0,
    );
    expect(
      flowingLightAdaptiveGlowIntensity(elapsed: hold, holdUntilNext: hold),
      1,
    );
    final duringFade = flowingLightAdaptiveGlowIntensity(
      elapsed: hold + const Duration(milliseconds: 260),
      holdUntilNext: hold,
    );
    expect(duringFade, inExclusiveRange(0.4, 0.6));
    expect(
      flowingLightAdaptiveGlowIntensity(
        elapsed: hold + flowingLightGlowFadeOutDuration,
        holdUntilNext: hold,
      ),
      0,
    );
  });

  test('flowing light rotation uses a 7.2 second cycle', () {
    expect(
      flowingLightRotationCycleDuration,
      const Duration(milliseconds: 7200),
    );
    expect(flowingLightMaximumRotationDegrees, 20);
  });

  test('revealed flowing light tokens rock gently in both directions', () {
    expect(
      flowingLightTokenSwayDegrees(
        phase: 0.25,
        tokenIndex: 0,
        revealProgress: 0,
      ),
      0,
    );

    final evenRight = flowingLightTokenSwayDegrees(
      phase: 0.25,
      tokenIndex: 0,
      revealProgress: 1,
    );
    final evenLeft = flowingLightTokenSwayDegrees(
      phase: 0.75,
      tokenIndex: 0,
      revealProgress: 1,
    );
    final oddLeft = flowingLightTokenSwayDegrees(
      phase: 0.25,
      tokenIndex: 1,
      revealProgress: 1,
    );

    expect(evenRight, closeTo(1.8, 0.0001));
    expect(evenLeft, closeTo(-1.8, 0.0001));
    expect(oddLeft, closeTo(-2.1, 0.0001));
  });

  test('last flowing light token keeps a periodic breathing glow', () {
    expect(flowingLightBreathingGlowIntensity(0), closeTo(0.36, 0.0001));
    expect(flowingLightBreathingGlowIntensity(0.5), closeTo(0.64, 0.0001));
    expect(flowingLightBreathingGlowIntensity(1), closeTo(0.36, 0.0001));
  });

  test('flowing light AI token fades after the next token starts', () {
    const token = FlowingLightToken(
      text: '光',
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      isLatinWord: false,
    );
    expect(
      flowingLightTokenAiColorIntensity(
        token,
        const Duration(milliseconds: 1900),
        nextStart: const Duration(seconds: 2),
      ),
      1,
    );
    expect(
      flowingLightTokenAiColorIntensity(
        token,
        const Duration(milliseconds: 2140),
        nextStart: const Duration(seconds: 2),
      ),
      closeTo(0.5, 0.005),
    );
    expect(
      flowingLightTokenAiColorIntensity(
        token,
        const Duration(milliseconds: 2280),
        nextStart: const Duration(seconds: 2),
      ),
      0,
    );
  });

  test('flowing light keyword token keeps its semantic color', () {
    const token = FlowingLightToken(
      text: '光',
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      isLatinWord: false,
    );
    expect(
      flowingLightTokenAiColorIntensity(
        token,
        const Duration(seconds: 4),
        nextStart: const Duration(seconds: 2),
        persist: true,
      ),
      1,
    );
  });

  test('flowing light keyword entrance ring uses the keyword color', () {
    const fallback = Color(0xFF778899);
    const keyword = Color(0xFFCC6633);

    expect(
      flowingLightEntranceRingColor(
        fallbackColor: fallback,
        semanticColor: keyword,
      ),
      keyword,
    );
    expect(flowingLightEntranceRingColor(fallbackColor: fallback), fallback);
  });

  test('flowing light keywords keep the entrance ring outside climax', () {
    expect(
      flowingLightShouldShowEntranceRing(isClimax: false, isKeyword: true),
      isTrue,
    );
    expect(
      flowingLightShouldShowEntranceRing(isClimax: true, isKeyword: false),
      isTrue,
    );
    expect(
      flowingLightShouldShowEntranceRing(isClimax: false, isKeyword: false),
      isFalse,
    );
  });

  test('climax keywords use larger text and halo than other tokens', () {
    final keywordTextScale = flowingLightClimaxKeywordTextScale(
      isClimax: true,
      isKeyword: true,
    );
    final keywordHaloScale = flowingLightClimaxKeywordHaloScale(
      isClimax: true,
      isKeyword: true,
    );

    expect(keywordTextScale, greaterThan(1));
    expect(keywordHaloScale, greaterThan(keywordTextScale));
    expect(
      flowingLightClimaxKeywordTextScale(isClimax: true, isKeyword: false),
      1,
    );
    expect(
      flowingLightClimaxKeywordHaloScale(isClimax: false, isKeyword: true),
      1,
    );
  });
}
