import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'download_service.dart';
import 'subsonic_api.dart';

/// Wraps [AudioPlayer] from `just_audio` with Subsonic stream URL resolution.
class AudioPlayerService {
  static const _volumeFadeDuration = Duration(milliseconds: 220);
  static const _volumeFadeStep = Duration(milliseconds: 16);

  final AudioPlayer _player = AudioPlayer();
  final SubsonicApi? _api;
  bool _hasPlaylist = false;
  double _targetVolume = 1.0;
  int _volumeFadeGeneration = 0;

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
    await _cancelVolumeFade();
    final sources = await _sourcesFor(songIds);
    _hasPlaylist = sources.isNotEmpty;
    await _player.setAudioSources(sources, initialIndex: startIndex);
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
    await _cancelVolumeFade();
    final sources = await _sourcesFor(songIds);
    _hasPlaylist = sources.isNotEmpty;
    await _player.setAudioSources(
      sources,
      initialIndex: startIndex,
      initialPosition: position,
    );
  }

  /// Inserts an item into the loaded sequence without rebuilding playback.
  Future<void> insertIntoPlaylist(int index, String songId) async {
    if (!_hasPlaylist) {
      await playPlaylist([songId]);
      return;
    }
    await _player.insertAudioSource(index, await _sourceFor(songId));
  }

  /// Plays or resumes playback.
  Future<void> play() async {
    final generation = ++_volumeFadeGeneration;
    if (_player.playing) {
      await _fadeVolume(to: _targetVolume, generation: generation);
      return;
    }
    await _player.setVolume(0);
    unawaited(_player.play());
    await _fadeVolume(to: _targetVolume, generation: generation);
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (!_player.playing) {
      await _player.pause();
      return;
    }
    final generation = ++_volumeFadeGeneration;
    await _fadeVolume(to: 0, generation: generation);
    if (generation != _volumeFadeGeneration) return;
    await _player.pause();
    await _player.setVolume(_targetVolume);
  }

  /// Stops playback and releases resources.
  Future<void> stop() async {
    await _cancelVolumeFade();
    await _player.stop();
  }

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
  Future<void> skipToNext() async {
    await _cancelVolumeFade();
    await _player.seekToNext();
  }

  /// Plays the previous item in the sequence.
  Future<void> skipToPrevious() async {
    await _cancelVolumeFade();
    await _player.seekToPrevious();
  }

  /// Jumps to an item in the currently loaded sequence.
  Future<void> seekToIndex(int index) async {
    await _cancelVolumeFade();
    await _player.seek(Duration.zero, index: index);
  }

  /// Jumps to a specific item and position in one operation.
  Future<void> seekToIndexAndPosition(int index, Duration position) async {
    await _cancelVolumeFade();
    await _player.seek(position, index: index);
  }

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
  Future<void> setVolume(double volume) {
    _targetVolume = volume.clamp(0.0, 1.0);
    return _player.setVolume(_targetVolume);
  }

  /// Configures the playback speed.
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // ━━━ Resource management ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Disposes of the underlying player and releases system resources.
  Future<void> dispose() => _player.dispose();

  Future<void> _fadeVolume({
    required double to,
    required int generation,
  }) async {
    final from = _player.volume;
    final target = to.clamp(0.0, 1.0);
    final stepCount =
        (_volumeFadeDuration.inMilliseconds / _volumeFadeStep.inMilliseconds)
            .ceil();

    for (var step = 1; step <= stepCount; step++) {
      if (generation != _volumeFadeGeneration) return;
      final progress = step / stepCount;
      final eased = 1 - (1 - progress) * (1 - progress);
      await _player.setVolume(from + (target - from) * eased);
      if (step < stepCount) {
        await Future<void>.delayed(_volumeFadeStep);
      }
    }
  }

  Future<void> _cancelVolumeFade() async {
    _volumeFadeGeneration++;
    await _player.setVolume(_targetVolume);
  }
}
