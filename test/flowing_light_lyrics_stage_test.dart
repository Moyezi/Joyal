import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/providers/player_provider.dart';
import 'package:joyal_music/providers/song_highlight_provider.dart';
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
      first.map(
        (item) => (
          item.row,
          item.rotationDegrees,
          item.horizontalJitter,
          item.verticalJitter,
          item.scale,
          item.gapAfter,
          item.rowShift,
        ),
      ),
      orderedEquals(
        second.map(
          (item) => (
            item.row,
            item.rotationDegrees,
            item.horizontalJitter,
            item.verticalJitter,
            item.scale,
            item.gapAfter,
            item.rowShift,
          ),
        ),
      ),
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

  test('flowing light reveal follows the original 520ms entrance window', () {
    const token = FlowingLightToken(
      text: '光',
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      isLatinWord: false,
    );

    expect(
      flowingLightTokenRevealProgress(token, const Duration(milliseconds: 999)),
      0,
    );
    expect(
      flowingLightTokenRevealProgress(
        token,
        const Duration(milliseconds: 1260),
      ),
      closeTo(0.5, 0.0001),
    );
    expect(
      flowingLightTokenRevealProgress(
        token,
        const Duration(milliseconds: 1520),
      ),
      1,
    );
  });

  test('flowing light classifies reusable token visual layers', () {
    const token = FlowingLightToken(
      text: '流',
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      isLatinWord: false,
    );
    const nextStart = Duration(seconds: 2);

    expect(
      flowingLightTokenVisualPhase(
        token: token,
        highlightEnd: nextStart,
        position: const Duration(milliseconds: 900),
        nextStart: nextStart,
        hasSemanticColor: false,
        keepBreathing: false,
      ),
      FlowingLightTokenVisualPhase.pending,
    );
    expect(
      flowingLightTokenVisualPhase(
        token: token,
        highlightEnd: nextStart,
        position: const Duration(milliseconds: 1750),
        nextStart: nextStart,
        hasSemanticColor: false,
        keepBreathing: false,
      ),
      FlowingLightTokenVisualPhase.holding,
    );
    expect(
      flowingLightTokenVisualPhase(
        token: token,
        highlightEnd: nextStart,
        position: const Duration(milliseconds: 2250),
        nextStart: nextStart,
        hasSemanticColor: false,
        keepBreathing: false,
      ),
      FlowingLightTokenVisualPhase.animating,
    );
    expect(
      flowingLightTokenVisualPhase(
        token: token,
        highlightEnd: nextStart,
        position: nextStart + flowingLightGlowFadeOutDuration,
        nextStart: nextStart,
        hasSemanticColor: false,
        keepBreathing: false,
      ),
      FlowingLightTokenVisualPhase.settled,
    );
    expect(
      flowingLightTokenVisualPhase(
        token: token,
        highlightEnd: nextStart,
        position: const Duration(seconds: 8),
        nextStart: null,
        hasSemanticColor: false,
        keepBreathing: true,
      ),
      FlowingLightTokenVisualPhase.animating,
    );
  });

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

  test('non-Latin token size follows the word-timing duration', () {
    const shortToken = FlowingLightToken(
      text: '光',
      start: Duration(seconds: 1),
      end: Duration(milliseconds: 1130),
      isLatinWord: false,
    );
    const referenceToken = FlowingLightToken(
      text: '流',
      start: Duration(seconds: 1),
      end: Duration(milliseconds: 1520),
      isLatinWord: false,
    );
    const longToken = FlowingLightToken(
      text: '影',
      start: Duration(seconds: 1),
      end: Duration(milliseconds: 3080),
      isLatinWord: false,
    );

    expect(flowingLightTimelineTokenScale(shortToken), 0.82);
    expect(flowingLightTimelineTokenScale(referenceToken), closeTo(1, 0.0001));
    expect(flowingLightTimelineTokenScale(longToken), 1.42);
  });

  test('Latin halo keeps its existing text-width sizing', () {
    const shortWord = FlowingLightToken(
      text: 'a',
      start: Duration(seconds: 1),
      end: Duration(milliseconds: 1100),
      isLatinWord: true,
    );
    const heldWord = FlowingLightToken(
      text: 'extraordinary',
      start: Duration(seconds: 1),
      end: Duration(seconds: 5),
      isLatinWord: true,
    );

    expect(flowingLightTimelineTokenScale(shortWord), 1);
    expect(flowingLightTimelineTokenScale(heldWord), 1);
  });

  test('flowing light effect color fades after the next token starts', () {
    const token = FlowingLightToken(
      text: '光',
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      isLatinWord: false,
    );
    expect(
      flowingLightTokenEffectColorIntensity(
        token,
        const Duration(milliseconds: 1900),
        nextStart: const Duration(seconds: 2),
      ),
      1,
    );
    expect(
      flowingLightTokenEffectColorIntensity(
        token,
        const Duration(milliseconds: 2140),
        nextStart: const Duration(seconds: 2),
      ),
      closeTo(0.5, 0.005),
    );
    expect(
      flowingLightTokenEffectColorIntensity(
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
      flowingLightTokenEffectColorIntensity(
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

  testWidgets('hidden flowing light stage leaves no active frame ticker', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final player = _FlowingLightTestPlayerNotifier();
    await tester.pumpWidget(_flowingLightTestApp(player));
    await tester.pumpAndSettle();

    expect(tester.binding.transientCallbackCount, 0);
    player.setPosition(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps flowing light stage frame-silent', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final player = _FlowingLightTestPlayerNotifier();
    await tester.pumpWidget(
      _flowingLightTestApp(
        player,
        positionUpdatesEnabled: true,
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.binding.transientCallbackCount, 0);
    expect(
      find.descendant(
        of: find.byType(FlowingLightLyricsStage),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity == 0,
        ),
      ),
      findsNothing,
    );
    expect(find.byKey(flowingLightStaticHighlightKey), findsOneWidget);
    player.setPosition(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      _flowingLightTestApp(
        player,
        activeIndex: 1,
        positionUpdatesEnabled: true,
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reusable token layers survive playback position frames', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final player = _FlowingLightTestPlayerNotifier(
      const Duration(milliseconds: 750),
    );
    await tester.pumpWidget(
      _flowingLightTestApp(player, positionUpdatesEnabled: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final holdingLayer = find.byKey(flowingLightHoldingTokenLayerKey(0));
    expect(holdingLayer, findsOneWidget);
    final originalHoldingElement = tester.element(holdingLayer);
    final originalHoldingWidget = tester.widget<RepaintBoundary>(holdingLayer);

    player.setPosition(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.element(holdingLayer), same(originalHoldingElement));
    expect(
      tester.widget<RepaintBoundary>(holdingLayer),
      same(originalHoldingWidget),
    );

    player.setPosition(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 16));

    final settledLayer = find.byKey(flowingLightSettledTokenLayerKey(0));
    expect(settledLayer, findsOneWidget);
    final originalElement = tester.element(settledLayer);
    final originalWidget = tester.widget<RepaintBoundary>(settledLayer);

    player.setPosition(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.element(settledLayer), same(originalElement));
    expect(tester.widget<RepaintBoundary>(settledLayer), same(originalWidget));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _noop() {}

Widget _flowingLightTestApp(
  _FlowingLightTestPlayerNotifier player, {
  int activeIndex = 0,
  bool positionUpdatesEnabled = false,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerServiceProvider.overrideWith((ref) => null),
      playerProvider.overrideWith((ref) => player),
      songHighlightProvider.overrideWith((ref, request) async => null),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: FlowingLightLyricsStage(
            data: const LyricsData(
              synced: true,
              lines: [
                LyricLine(
                  text: '流光',
                  start: Duration.zero,
                  end: Duration(seconds: 2),
                  words: [
                    LyricWord(
                      text: '流光',
                      start: Duration.zero,
                      end: Duration(seconds: 2),
                    ),
                  ],
                ),
                LyricLine(
                  text: '如昼',
                  start: Duration(seconds: 2),
                  end: Duration(seconds: 4),
                  words: [
                    LyricWord(
                      text: '如昼',
                      start: Duration(seconds: 2),
                      end: Duration(seconds: 4),
                    ),
                  ],
                ),
              ],
            ),
            song: const Song(
              id: 'flowing-light-test',
              parent: 'album',
              title: '流光',
              album: '测试专辑',
              artist: '测试歌手',
              duration: 2,
              coverArt: '',
              contentType: 'audio/flac',
              suffix: 'flac',
            ),
            activeIndex: activeIndex,
            title: '流光',
            artist: '测试歌手',
            activeColor: Colors.white,
            fontFamily: null,
            fontSize: 36,
            effectColor: Colors.cyan,
            wordByWordEnabled: true,
            stageVisible: false,
            positionUpdatesEnabled: positionUpdatesEnabled,
            onOpenSettings: _noop,
          ),
        ),
      ),
    ),
  );
}

class _FlowingLightTestPlayerNotifier extends PlayerNotifier {
  _FlowingLightTestPlayerNotifier([Duration position = Duration.zero])
    : super(null, const FlutterSecureStorage()) {
    state = PlaybackState(position: position);
  }

  void setPosition(Duration position) {
    state = state.copyWith(position: position);
  }
}
