import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/providers/player_provider.dart';
import 'package:joyal_music/widgets/lyrics/default_lyrics_view.dart';
import 'package:joyal_music/widgets/lyrics/lyric_print_effect.dart';

void main() {
  test('print glyph bounce peaks at ten percent and settles each glyph', () {
    expect(lyricPrintGlyphBounceOffset(0, 40), 0);
    expect(lyricPrintGlyphBounceOffset(0.5, 40), closeTo(-4, 0.001));
    expect(lyricPrintGlyphBounceOffset(1, 40), 0);
    expect(lyricPrintGlyphBounceOffset(1.5, 40), closeTo(-4, 0.001));
  });

  test('print stamp appears only during the active glyph', () {
    expect(lyricPrintStampPulse(0), 0);
    expect(lyricPrintStampPulse(0.1), greaterThan(0));
    expect(lyricPrintStampPulse(0.9), greaterThan(0));
    expect(lyricPrintStampPulse(1), 0);
  });

  testWidgets('default timed lyrics render glyph effects inline', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith((ref) => _TestPlayerNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DefaultLyricsView(
              data: const LyricsData(
                synced: true,
                lines: [
                  LyricLine(
                    text: '默认滚动',
                    start: Duration.zero,
                    end: Duration(seconds: 1),
                    words: [
                      LyricWord(
                        text: '默认滚动',
                        start: Duration.zero,
                        end: Duration(seconds: 1),
                      ),
                    ],
                  ),
                ],
              ),
              activeIndex: 0,
              title: '测试歌曲',
              artist: '测试歌手',
              dynamicColor: null,
              stageVisible: true,
              positionUpdatesEnabled: true,
              onSeek: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(richTexts.any((widget) => _containsWidgetSpan(widget.text)), isTrue);
    expect(tester.takeException(), isNull);
  });
}

bool _containsWidgetSpan(InlineSpan span) {
  if (span is WidgetSpan) return true;
  if (span is! TextSpan) return false;
  return span.children?.any(_containsWidgetSpan) ?? false;
}

class _TestPlayerNotifier extends PlayerNotifier {
  _TestPlayerNotifier() : super(null, const FlutterSecureStorage()) {
    state = const PlaybackState(position: Duration(milliseconds: 500));
  }
}
