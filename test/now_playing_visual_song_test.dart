import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/providers/player_provider.dart';
import 'package:joyal_music/screens/now_playing_screen.dart';

void main() {
  test(
    'nowPlayingVisualSong follows the selection candidate while selecting',
    () {
      final songs = [
        _song('one', 'cover-one'),
        _song('two', 'cover-two'),
        _song('three', 'cover-three'),
      ];
      final state = PlaybackState(
        currentSong: songs.first,
        playlist: songs,
        currentIndex: 0,
      );

      final visualSong = nowPlayingVisualSong(
        state: state,
        isSelecting: true,
        candidateIndex: 2,
      );

      expect(visualSong, songs[2]);
      expect(visualSong?.coverArt, 'cover-three');
    },
  );

  test('nowPlayingVisualSong keeps current song outside selection mode', () {
    final songs = [_song('one', 'cover-one'), _song('two', 'cover-two')];
    final state = PlaybackState(
      currentSong: songs.first,
      playlist: songs,
      currentIndex: 0,
    );

    final visualSong = nowPlayingVisualSong(
      state: state,
      isSelecting: false,
      candidateIndex: 1,
    );

    expect(visualSong, songs.first);
  });

  test(
    'nowPlayingVisualSong falls back to current song for invalid candidates',
    () {
      final songs = [_song('one', 'cover-one'), _song('two', 'cover-two')];
      final state = PlaybackState(
        currentSong: songs.first,
        playlist: songs,
        currentIndex: 0,
      );

      expect(
        nowPlayingVisualSong(
          state: state,
          isSelecting: true,
          candidateIndex: 99,
        ),
        songs.first,
      );
    },
  );

  group('shouldShowLyricsAfterHorizontalDrag', () {
    test('uses fling direction before progress threshold', () {
      expect(
        shouldShowLyricsAfterHorizontalDrag(
          progress: 0.8,
          primaryVelocity: 900,
        ),
        isFalse,
      );
      expect(
        shouldShowLyricsAfterHorizontalDrag(
          progress: 0.1,
          primaryVelocity: -900,
        ),
        isTrue,
      );
    });

    test('uses progress threshold for slow releases', () {
      expect(
        shouldShowLyricsAfterHorizontalDrag(progress: 0.27, primaryVelocity: 0),
        isFalse,
      );
      expect(
        shouldShowLyricsAfterHorizontalDrag(progress: 0.28, primaryVelocity: 0),
        isTrue,
      );
    });
  });

  group('nowPlayingSurfaceVisibilityForLyricsProgress', () {
    test('keeps exact settled endpoints', () {
      expect(nowPlayingSurfaceVisibilityForLyricsProgress(0), 1);
      expect(nowPlayingSurfaceVisibilityForLyricsProgress(1), 0);
      expect(nowPlayingSurfaceVisibilityForLyricsProgress(-1), 1);
      expect(nowPlayingSurfaceVisibilityForLyricsProgress(2), 0);
    });

    test('fades monotonically through the interactive swipe', () {
      final start = nowPlayingSurfaceVisibilityForLyricsProgress(0.2);
      final middle = nowPlayingSurfaceVisibilityForLyricsProgress(0.5);
      final end = nowPlayingSurfaceVisibilityForLyricsProgress(0.8);

      expect(start, greaterThan(middle));
      expect(middle, greaterThan(end));
    });
  });
}

Song _song(String id, String coverArt) {
  return Song(
    id: id,
    parent: 'album-$id',
    title: 'Song $id',
    album: 'Album',
    artist: 'Artist',
    duration: 180,
    coverArt: coverArt,
    contentType: 'audio/mpeg',
    suffix: 'mp3',
  );
}
