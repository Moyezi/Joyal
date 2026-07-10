import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/providers/lyrics_provider.dart';

void main() {
  test('lyricPairForPosition returns current and next synced lines', () {
    const data = LyricsData(
      synced: true,
      lines: [
        LyricLine(text: 'first', start: Duration(seconds: 1)),
        LyricLine(text: 'second', start: Duration(seconds: 4)),
        LyricLine(text: 'third', start: Duration(seconds: 8)),
      ],
    );

    final pair = lyricPairForPosition(data, const Duration(seconds: 5));

    expect(pair.current, 'second');
    expect(pair.next, 'third');
    expect(pair.index, 1);
  });

  test('lyricPairForPosition skips empty lines around the active line', () {
    const data = LyricsData(
      synced: true,
      lines: [
        LyricLine(text: 'first', start: Duration(seconds: 1)),
        LyricLine(text: '', start: Duration(seconds: 4)),
        LyricLine(text: 'third', start: Duration(seconds: 8)),
      ],
    );

    final pair = lyricPairForPosition(data, const Duration(seconds: 5));

    expect(pair.current, 'first');
    expect(pair.next, 'third');
    expect(pair.index, 0);
  });

  test('activeLyricIndex finds the last started line in a long timeline', () {
    final data = LyricsData(
      synced: true,
      lines: List.generate(
        2000,
        (index) => LyricLine(
          text: 'line $index',
          start: Duration(milliseconds: index * 250),
        ),
      ),
    );

    expect(activeLyricIndex(data, const Duration(milliseconds: 123375)), 493);
    expect(activeLyricIndex(data, Duration.zero), 0);
  });

  test('activeLyricIndex preserves behavior for unordered timestamps', () {
    const data = LyricsData(
      synced: true,
      lines: [
        LyricLine(text: 'late', start: Duration(seconds: 8)),
        LyricLine(text: 'early', start: Duration(seconds: 2)),
        LyricLine(text: 'future', start: Duration(seconds: 12)),
      ],
    );

    expect(activeLyricIndex(data, const Duration(seconds: 9)), 1);
  });

  test('unsynced lyric pairs skip blank lines without temporary filtering', () {
    const data = LyricsData(
      synced: false,
      lines: [
        LyricLine(text: '  '),
        LyricLine(text: 'first'),
        LyricLine(text: ''),
        LyricLine(text: 'second'),
      ],
    );

    final pair = lyricPairForPosition(data, Duration.zero);

    expect(pair.current, 'first');
    expect(pair.next, 'second');
    expect(pair.index, 0);
  });
}
