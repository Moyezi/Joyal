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
}
