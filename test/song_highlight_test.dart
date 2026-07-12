import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/models/song_highlight.dart';

void main() {
  test('highlight segments are clamped, ordered, and merged', () {
    final segments = normalizeHighlightSegments([
      {'startMs': 18000, 'endMs': 26000},
      {'startMs': 5000, 'endMs': 12000},
      {'startMs': 11000, 'endMs': 20000},
      {'startMs': 29000, 'endMs': 40000},
    ], songDuration: const Duration(seconds: 30));

    expect(segments, hasLength(2));
    expect(segments.first.start, const Duration(seconds: 5));
    expect(segments.first.end, const Duration(seconds: 26));
    expect(segments.last.end, const Duration(seconds: 30));
  });

  test('timeline only includes positions inside a highlight', () {
    final timeline = SongHighlightTimeline(
      segments: const [
        SongHighlightSegment(
          start: Duration(seconds: 40),
          end: Duration(seconds: 60),
        ),
      ],
      lyricsHash: 'hash',
      model: 'deepseek-chat',
      analyzedAt: DateTime.utc(2026),
    );

    expect(timeline.contains(const Duration(seconds: 39)), isFalse);
    expect(timeline.contains(const Duration(seconds: 50)), isTrue);
    expect(timeline.contains(const Duration(seconds: 61)), isFalse);
  });

  test('lyrics analysis hash changes with timed lyric content', () {
    const song = Song(
      id: 'song-1',
      parent: 'album-1',
      title: 'Song',
      album: 'Album',
      artist: 'Artist',
      duration: 180,
      coverArt: '',
      contentType: 'audio/mpeg',
      suffix: 'mp3',
    );
    const first = LyricsData(
      synced: true,
      lines: [LyricLine(text: 'first', start: Duration(seconds: 10))],
    );
    const second = LyricsData(
      synced: true,
      lines: [LyricLine(text: 'first', start: Duration(seconds: 11))],
    );

    expect(
      lyricsAnalysisHash(song, first),
      isNot(lyricsAnalysisHash(song, second)),
    );
  });
}
