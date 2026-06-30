import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'download_service.dart';
import 'subsonic_api.dart';

/// Wraps [AudioPlayer] from `just_audio` with Subsonic stream URL resolution.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final SubsonicApi? _api;
  ConcatenatingAudioSource? _playlistSource;

  AudioPlayerService(this._api);

  Future<AudioSource> _sourceFor(String songId) async {
    final localUri = await DownloadService.localUriForSong(songId);
    if (localUri != null) return AudioSource.uri(Uri.parse(localUri));
    final api = _api;
    if (api == null) {
      throw StateError('此歌曲尚未下载，请连接 Navidrome 后播放');
    }
    return AudioSource.uri(Uri.parse(api.getStreamUrl(songId)));
  }

  Future<List<AudioSource>> _sourcesFor(List<String> songIds) =>
      Future.wait(songIds.map(_sourceFor));

  // ━━━ Exposed streams ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// The current playback position, updated continuously.
  Stream<Duration> get positionStream => _player.positionStream;

  /// The total duration of the loaded audio (may change for live streams).
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Combined player state (playing, paused, buffering, etc.).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// The current playback mode (shuffle / loop).
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;

  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  /// Whether the player is currently playing.
  bool get isPlaying => _player.playing;

  /// The current loop mode.
  LoopMode get loopMode => _player.loopMode;

  /// Whether shuffle is enabled.
  bool get shuffleModeEnabled => _player.shuffleModeEnabled;

  /// Current position as a [Duration].
  Duration get position => _player.position;

  /// Total duration of the current audio.
  Duration? get duration => _player.duration;

  /// The effective adjacent indexes, including shuffle and loop mode.
  int? get nextIndex => _player.nextIndex;

  int? get previousIndex => _player.previousIndex;

  // ━━━ Playback control ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Plays a song by its Subsonic [songId].
  ///
  /// Automatically resolves the secure stream URL via the API.
  Future<void> playSong(String songId) async {
    await playPlaylist([songId]);
  }

  /// Loads a real multi-item audio sequence and starts at [startIndex].
  Future<void> playPlaylist(List<String> songIds, {int startIndex = 0}) async {
    final source = ConcatenatingAudioSource(
      children: await _sourcesFor(songIds),
    );
    _playlistSource = source;
    await _player.setAudioSource(source, initialIndex: startIndex);
    // AudioPlayer.play() completes when playback finishes. Do not await it here,
    // otherwise callers cannot publish the current song while it is playing.
    unawaited(_player.play());
  }

  /// Rebuilds a saved queue without starting playback.
  Future<void> restorePlaylist(
    List<String> songIds, {
    required int startIndex,
    required Duration position,
  }) async {
    final source = ConcatenatingAudioSource(
      children: await _sourcesFor(songIds),
    );
    _playlistSource = source;
    await _player.setAudioSource(
      source,
      initialIndex: startIndex,
      initialPosition: position,
    );
  }

  /// Inserts an item into the loaded sequence without rebuilding playback.
  Future<void> insertIntoPlaylist(int index, String songId) async {
    final source = _playlistSource;
    if (source == null) {
      await playPlaylist([songId]);
      return;
    }
    await source.insert(index, await _sourceFor(songId));
  }

  /// Plays or resumes playback.
  Future<void> play() => _player.play();

  /// Pauses playback.
  Future<void> pause() => _player.pause();

  /// Stops playback and releases resources.
  Future<void> stop() => _player.stop();

  /// Seeks to a specific [position].
  Future<void> seek(Duration position) => _player.seek(position);

  /// Seeks relative to the current position.
  Future<void> seekBy(Duration offset) async {
    final target = _player.position + offset;
    final duration = _player.duration;
    if (duration != null && target > duration) {
      await _player.seek(duration);
    } else if (target < Duration.zero) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seek(target);
    }
  }

  /// Plays the next item in the sequence.
  Future<void> skipToNext() => _player.seekToNext();

  /// Plays the previous item in the sequence.
  Future<void> skipToPrevious() => _player.seekToPrevious();

  /// Jumps to an item in the currently loaded sequence.
  Future<void> seekToIndex(int index) =>
      _player.seek(Duration.zero, index: index);

  /// Jumps to a specific item and position in one operation.
  Future<void> seekToIndexAndPosition(int index, Duration position) =>
      _player.seek(position, index: index);

  /// Toggles shuffle mode.
  Future<void> toggleShuffle() async {
    await _player.setShuffleModeEnabled(!_player.shuffleModeEnabled);
  }

  Future<void> setShuffleModeEnabled(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);

  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  /// Cycles through loop modes: off → all → one.
  Future<void> cycleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        await _player.setLoopMode(LoopMode.all);
      case LoopMode.all:
        await _player.setLoopMode(LoopMode.one);
      case LoopMode.one:
        await _player.setLoopMode(LoopMode.off);
    }
  }

  /// Sets the volume (0.0 – 1.0).
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// Configures the playback speed.
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // ━━━ Resource management ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Disposes of the underlying player and releases system resources.
  Future<void> dispose() => _player.dispose();
}
