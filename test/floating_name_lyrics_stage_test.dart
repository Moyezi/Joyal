import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/models/song_highlight.dart';
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

  test('floating name camera interpolates continuously between glyphs', () {
    final boxes = [
      const Rect.fromLTWH(0, 0, 20, 20),
      const Rect.fromLTWH(40, 0, 20, 20),
    ];

    expect(floatingNameInterpolatedGlyphCenter(boxes, 0), const Offset(10, 10));
    final halfway = floatingNameInterpolatedGlyphCenter(boxes, 0.5)!;
    expect(halfway.dx, inExclusiveRange(10, 50));
    expect(halfway.dy, 10);
    expect(floatingNameInterpolatedGlyphCenter(boxes, 1), const Offset(50, 10));
  });

  test('floating name camera eases vertically across a visual-line wrap', () {
    final boxes = [
      const Rect.fromLTWH(0, 0, 20, 20),
      const Rect.fromLTWH(24, 0, 20, 20),
      const Rect.fromLTWH(0, 40, 20, 20),
      const Rect.fromLTWH(24, 40, 20, 20),
    ];

    final beforeWrap = floatingNameCameraGlyphFrontier(
      boxes,
      0.5,
      glyphs: const ['上', '行', '下', '行'],
      hasMultipleVisualLines: true,
    )!;
    final enteringWrap = floatingNameCameraGlyphFrontier(
      boxes,
      1,
      glyphs: const ['上', '行', '下', '行'],
      hasMultipleVisualLines: true,
    )!;
    final middleOfWrap = floatingNameCameraGlyphFrontier(
      boxes,
      1.5,
      glyphs: const ['上', '行', '下', '行'],
      hasMultipleVisualLines: true,
    )!;
    final leavingWrap = floatingNameCameraGlyphFrontier(
      boxes,
      2,
      glyphs: const ['上', '行', '下', '行'],
      hasMultipleVisualLines: true,
    )!;
    final afterWrap = floatingNameCameraGlyphFrontier(
      boxes,
      2.5,
      glyphs: const ['上', '行', '下', '行'],
      hasMultipleVisualLines: true,
    )!;

    expect(beforeWrap.dy, 10);
    expect(enteringWrap.dy, inExclusiveRange(10, 30));
    expect(middleOfWrap.dy, inExclusiveRange(enteringWrap.dy, 40));
    expect(leavingWrap.dy, inExclusiveRange(middleOfWrap.dy, 50));
    expect(afterWrap.dy, 50);
  });

  test('floating name camera spans several English words at a wrap', () {
    final glyphs = 'one two three four'.characters.toList(growable: false);
    final boxes = <Rect>[
      for (var index = 0; index < glyphs.length; index++)
        glyphs[index].trim().isEmpty
            ? Rect.zero
            : Rect.fromLTWH(index * 12, index < 8 ? 0 : 40, 10, 20),
    ];

    Offset focusAt(double progress) => floatingNameCameraGlyphFrontier(
      boxes,
      progress,
      glyphs: glyphs,
      hasMultipleVisualLines: true,
    )!;

    expect(focusAt(0).dy, 10);
    expect(focusAt(4).dy, inExclusiveRange(10, 30));
    expect(focusAt(9).dy, inExclusiveRange(focusAt(4).dy, 50));
    expect(focusAt(14).dy, inExclusiveRange(focusAt(9).dy, 50));
    expect(focusAt(glyphs.length.toDouble()).dy, 50);
  });

  test(
    'floating name camera does not move sideways inside a wrapped lyric',
    () {
      const center = Offset(100, 80);
      final firstRowFocus = floatingNameCameraFocus(
        blockCenter: center,
        glyphFrontier: const Offset(40, 40),
        hasMultipleVisualLines: true,
      );
      final nextRowFocus = floatingNameCameraFocus(
        blockCenter: center,
        glyphFrontier: const Offset(160, 120),
        hasMultipleVisualLines: true,
      );

      expect(firstRowFocus.dx, center.dx);
      expect(nextRowFocus.dx, center.dx);
      expect(firstRowFocus.dy, isNot(nextRowFocus.dy));
    },
  );

  test(
    'floating name camera keeps horizontal follow for a single-line lyric',
    () {
      final focus = floatingNameCameraFocus(
        blockCenter: const Offset(100, 80),
        glyphFrontier: const Offset(160, 80),
        hasMultipleVisualLines: false,
      );

      expect(focus.dx, greaterThan(100));
    },
  );

  test(
    'floating name types whole graphemes while camera progress stays smooth',
    () {
      expect(floatingNameTypedGraphemeCount(0, 6), 0);
      expect(floatingNameTypedGraphemeCount(0.01, 6), 1);
      expect(floatingNameTypedGraphemeCount(1.4, 6), 2);
      expect(floatingNameTypedGraphemeCount(5.8, 6), 6);
    },
  );

  test('floating name lifts each highlighted glyph by ten percent', () {
    expect(floatingNameGlyphBounceOffset(0, 40), 0);
    expect(floatingNameGlyphBounceOffset(0.5, 40), closeTo(-4, 0.001));
    expect(floatingNameGlyphBounceOffset(1, 40), 0);
    expect(floatingNameGlyphBounceOffset(1.5, 40), closeTo(-4, 0.001));
  });

  test('floating name skips print stamps for spaces and punctuation', () {
    for (final grapheme in [
      ' ',
      '\n',
      ',',
      '.',
      '，',
      '。',
      '！',
      '？',
      '—',
      '“',
      '”',
      '…',
    ]) {
      expect(
        floatingNameGraphemeGetsPrintStamp(grapheme),
        isFalse,
        reason: 'Unexpected stamp for "$grapheme"',
      );
    }
    for (final grapheme in ['浮', 'A', 'é', '7', '♥']) {
      expect(
        floatingNameGraphemeGetsPrintStamp(grapheme),
        isTrue,
        reason: 'Expected stamp for "$grapheme"',
      );
    }
  });

  test('floating name handheld drift only appears during a long lyric gap', () {
    const current = LyricLine(
      text: '上一句',
      start: Duration(seconds: 1),
      end: Duration(seconds: 4),
    );
    const nearNext = LyricLine(text: '下一句', start: Duration(seconds: 7));
    const farNext = LyricLine(text: '下一句', start: Duration(seconds: 12));

    expect(
      floatingNameWaitingCameraStrength(
        line: current,
        nextLine: nearNext,
        position: const Duration(seconds: 6),
      ),
      0,
    );
    expect(
      floatingNameWaitingCameraStrength(
        line: current,
        nextLine: farNext,
        position: const Duration(seconds: 4, milliseconds: 500),
      ),
      0,
    );
    expect(
      floatingNameWaitingCameraStrength(
        line: current,
        nextLine: farNext,
        position: const Duration(seconds: 7),
      ),
      closeTo(1, 0.001),
    );
    expect(
      floatingNameWaitingCameraStrength(
        line: current,
        nextLine: farNext,
        position: const Duration(milliseconds: 11700),
      ),
      inExclusiveRange(0, 1),
    );
    expect(
      floatingNameWaitingCameraStrength(
        line: current,
        nextLine: null,
        position: const Duration(seconds: 20),
      ),
      0,
    );
  });

  test('floating name reveal colors glyphs without rectangular clipping', () {
    const revealed = Color(0xFFFFFFFF);
    const pending = Color(0x1CFFFFFF);
    final span = floatingNameRevealSpan(
      glyphs: const ['上', '一', '行', '\n', '下', '一', '行'],
      style: const TextStyle(fontSize: 42, height: 1.03),
      typedCount: 3,
      revealedColor: revealed,
      pendingColor: pending,
    );
    final children = span.children!.cast<TextSpan>().toList(growable: false);

    expect(children.take(3).map((child) => child.style!.color), [
      revealed,
      revealed,
      revealed,
    ]);
    expect(
      children.skip(3).map((child) => child.style!.color),
      everyElement(pending),
    );
  });

  test('floating name lays out every visual row of a long lyric', () {
    final painter = layoutFloatingNameText(
      text: const TextSpan(
        text: '第一段很长的歌词第二段很长的歌词第三段很长的歌词第四段仍然需要完整显示',
        style: TextStyle(fontSize: 24, height: 1.12),
      ),
      maxWidth: 120,
    );

    expect(painter.computeLineMetrics().length, greaterThan(3));
    expect(painter.didExceedMaxLines, isFalse);
    final finalGlyphBoxes = painter.getBoxesForSelection(
      const TextSelection(baseOffset: 34, extentOffset: 35),
    );
    expect(finalGlyphBoxes, isNotEmpty);
  });

  test('floating name article expands sideways in a snake', () {
    const spacing = 300.0;
    expect(
      floatingNameArticleCellForIndex(0, columnSpacing: spacing, rowOffset: 0),
      const Offset(-spacing, 0),
    );
    expect(
      floatingNameArticleCellForIndex(2, columnSpacing: spacing, rowOffset: 0),
      const Offset(spacing, 0),
    );
    expect(
      floatingNameArticleCellForIndex(
        3,
        columnSpacing: spacing,
        rowOffset: 180,
      ),
      const Offset(spacing, 180),
    );
  });

  test('floating name detects highlighted lyric intervals', () {
    const line = LyricLine(
      text: '高潮段落',
      start: Duration(seconds: 10),
      end: Duration(seconds: 14),
    );

    expect(
      floatingNameLineIsHighlighted(line, const [
        SongHighlightSegment(
          start: Duration(seconds: 11),
          end: Duration(seconds: 13),
        ),
      ]),
      isTrue,
    );
  });
}
