import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/widgets/lyrics_stage/floating_name_lyrics_stage.dart';

void main() {
  test('floating name follows word timing across the printed prefix', () {
    const line = LyricLine(
      text: '浮名 effect',
      start: Duration(seconds: 1),
      end: Duration(seconds: 5),
      words: [
        LyricWord(
          text: '浮名',
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
        ),
        LyricWord(
          text: 'effect',
          start: Duration(seconds: 3),
          end: Duration(seconds: 5),
        ),
      ],
    );

    expect(
      floatingNamePrintedGraphemeProgress(
        line,
        const Duration(milliseconds: 1500),
      ),
      closeTo(1.5, 0.01),
    );
    expect(
      floatingNamePrintedGraphemeProgress(
        line,
        const Duration(milliseconds: 2500),
      ),
      closeTo(3, 0.01),
    );
    expect(
      floatingNamePrintedGraphemeProgress(line, const Duration(seconds: 5)),
      closeTo(9, 0.01),
    );
  });

  test(
    'floating name shows the complete line when word reveal is disabled',
    () {
      const line = LyricLine(
        text: '整句出现',
        start: Duration(seconds: 2),
        end: Duration(seconds: 4),
      );

      expect(
        floatingNamePrintedGraphemeProgress(
          line,
          const Duration(seconds: 1),
          wordByWordEnabled: false,
        ),
        0,
      );
      expect(
        floatingNamePrintedGraphemeProgress(
          line,
          const Duration(seconds: 2),
          wordByWordEnabled: false,
        ),
        4,
      );
    },
  );

  test('floating name hero choices are deterministic and sparse', () {
    final first = List.generate(
      18,
      (index) => floatingNameBlockVariantFor(index, '第$index句浮名歌词', 18),
    );
    final second = List.generate(
      18,
      (index) => floatingNameBlockVariantFor(index, '第$index句浮名歌词', 18),
    );

    expect(first, orderedEquals(second));
    expect(
      first.where((variant) => variant == FloatingNameBlockVariant.hero).length,
      inInclusiveRange(1, 5),
    );
  });
}
