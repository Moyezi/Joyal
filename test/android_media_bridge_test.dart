import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/providers/player_provider.dart';
import 'package:joyal_music/services/android_media_bridge.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  test('snapshotPayload returns inactive payload when no song is loaded', () {
    final payload = AndroidMediaBridge.snapshotPayload(const PlaybackState());

    expect(payload, {
      'hasSong': false,
      'isPlaying': false,
      'positionMs': 0,
      'durationMs': null,
      'currentIndex': -1,
      'playlistLength': 0,
    });
  });

  test(
    'snapshotPayload serializes current song artwork without credentials or URLs',
    () {
      const song = Song(
        id: 'song-1',
        parent: 'album-1',
        title: 'Night Drive',
        artist: 'Joyal',
        album: 'Cold Lights',
        coverArt: 'cover-1',
        duration: 245,
        contentType: 'audio/flac',
        suffix: 'flac',
      );
      const state = PlaybackState(
        currentSong: song,
        isPlaying: true,
        position: Duration(seconds: 12),
        duration: Duration(seconds: 245),
        loopMode: LoopMode.off,
        shuffleEnabled: false,
        playlist: [song],
        currentIndex: 0,
      );

      final payload = AndroidMediaBridge.snapshotPayload(
        state,
        coverArtPath: '/data/user/0/com.example.joyal_music/cache/cover-1.jpg',
      );

      expect(payload['hasSong'], true);
      expect(payload['songId'], 'song-1');
      expect(payload['title'], 'Night Drive');
      expect(payload['artist'], 'Joyal');
      expect(payload['album'], 'Cold Lights');
      expect(payload['isPlaying'], true);
      expect(payload['positionMs'], 12000);
      expect(payload['durationMs'], 245000);
      expect(payload['currentIndex'], 0);
      expect(payload['playlistLength'], 1);
      expect(payload['coverArtId'], 'cover-1');
      expect(
        payload['coverArtPath'],
        '/data/user/0/com.example.joyal_music/cache/cover-1.jpg',
      );
      expect(payload, isNot(contains('coverArtUrl')));
      expect(payload, isNot(contains('streamUrl')));
      expect(payload, isNot(contains('password')));
      expect(payload, isNot(contains('token')));
      expect(payload, isNot(contains('baseUrl')));
    },
  );

  test('shouldSync immediately syncs song and play state changes', () {
    const song = Song(
      id: 'song-1',
      parent: 'album-1',
      title: 'Night Drive',
      artist: 'Joyal',
      album: 'Cold Lights',
      duration: 245,
      coverArt: 'cover-1',
      contentType: 'audio/flac',
      suffix: 'flac',
    );
    const previous = PlaybackState(
      currentSong: song,
      isPlaying: false,
      position: Duration(seconds: 1),
      duration: Duration(seconds: 245),
      playlist: [song],
      currentIndex: 0,
    );
    const next = PlaybackState(
      currentSong: song,
      isPlaying: true,
      position: Duration(seconds: 1),
      duration: Duration(seconds: 245),
      playlist: [song],
      currentIndex: 0,
    );

    expect(
      AndroidMediaBridge.shouldSync(
        previous: previous,
        next: next,
        elapsedSinceLastSync: Duration.zero,
      ),
      true,
    );
  });

  test('shouldSync throttles position-only changes', () {
    const song = Song(
      id: 'song-1',
      parent: 'album-1',
      title: 'Night Drive',
      artist: 'Joyal',
      album: 'Cold Lights',
      duration: 245,
      coverArt: 'cover-1',
      contentType: 'audio/flac',
      suffix: 'flac',
    );
    const previous = PlaybackState(
      currentSong: song,
      isPlaying: true,
      position: Duration(seconds: 1),
      duration: Duration(seconds: 245),
      playlist: [song],
      currentIndex: 0,
    );
    const next = PlaybackState(
      currentSong: song,
      isPlaying: true,
      position: Duration(seconds: 2),
      duration: Duration(seconds: 245),
      playlist: [song],
      currentIndex: 0,
    );

    expect(
      AndroidMediaBridge.shouldSync(
        previous: previous,
        next: next,
        elapsedSinceLastSync: const Duration(milliseconds: 500),
      ),
      false,
    );
    expect(
      AndroidMediaBridge.shouldSync(
        previous: previous,
        next: next,
        elapsedSinceLastSync: const Duration(seconds: 2),
      ),
      true,
    );
  });
}
