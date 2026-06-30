import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/subsonic_api.dart';
import 'auth_provider.dart';

enum PlaybackMode { sequential, shuffle, repeatAll, repeatOne }

/// Immutable snapshot of the audio player state.
class PlaybackState {
  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final LoopMode loopMode;
  final bool shuffleEnabled;
  final List<Song> playlist;
  final int currentIndex;
  final bool isRestoringSession;

  const PlaybackState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.loopMode = LoopMode.off,
    this.shuffleEnabled = false,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isRestoringSession = false,
  });

  PlaybackState copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    LoopMode? loopMode,
    bool? shuffleEnabled,
    List<Song>? playlist,
    int? currentIndex,
    bool? isRestoringSession,
  }) {
    return PlaybackState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      loopMode: loopMode ?? this.loopMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
    );
  }

  /// Whether there is a song currently loaded.
  bool get hasSong => currentSong != null;

  /// Progress as a fraction (0.0 – 1.0).
  double get progressFraction {
    if (duration == null || duration == Duration.zero) return 0.0;
    return (position.inMilliseconds / duration!.inMilliseconds).clamp(0.0, 1.0);
  }

  PlaybackMode get playbackMode {
    if (shuffleEnabled) return PlaybackMode.shuffle;
    return switch (loopMode) {
      LoopMode.all => PlaybackMode.repeatAll,
      LoopMode.one => PlaybackMode.repeatOne,
      LoopMode.off => PlaybackMode.sequential,
    };
  }
}

/// Manages audio playback state, playlist, and player controls.
class PlayerNotifier extends StateNotifier<PlaybackState> {
  static const _legacyStorageKey = 'player_session_v1';
  static const _queueStorageKey = 'player_queue_v2';
  static const _progressStorageKey = 'player_progress_v2';
  final AudioPlayerService? _audioService;
  final FlutterSecureStorage _storage;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _saveTimer;
  bool _restoring = false;
  int _queueSaveGeneration = 0;
  int _progressSaveGeneration = 0;

  PlayerNotifier(this._audioService, this._storage)
    : super(const PlaybackState());

  /// Sets the audio service reference (called after auth establishes the API).
  void setAudioService(AudioPlayerService service) {
    _listenToPlayer(service);
    state = state.copyWith(isRestoringSession: true);
    unawaited(_restoreSession(service));
  }

  Future<void> _restoreSession(AudioPlayerService service) async {
    _restoring = true;
    try {
      final rawQueue =
          await _storage.read(key: _queueStorageKey) ??
          await _storage.read(key: _legacyStorageKey);
      if (rawQueue == null) return;
      final queueJson =
          await Isolate.run(() => jsonDecode(rawQueue)) as Map<String, dynamic>;
      final rawProgress = await _storage.read(key: _progressStorageKey);
      final progressJson = rawProgress == null
          ? queueJson
          : await Isolate.run(() => jsonDecode(rawProgress))
                as Map<String, dynamic>;
      final songs = (queueJson['playlist'] as List<dynamic>)
          .map((item) => Song.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      if (songs.isEmpty) return;
      final index = ((progressJson['currentIndex'] as num?)?.toInt() ?? 0)
          .clamp(0, songs.length - 1);
      final position = Duration(
        milliseconds: (progressJson['positionMs'] as num?)?.toInt() ?? 0,
      );
      await service.restorePlaylist(
        songs.map((song) => song.id).toList(),
        startIndex: index,
        position: position,
      );
      final loopMode =
          LoopMode.values[((progressJson['loopMode'] as num?)?.toInt() ?? 0)
              .clamp(0, LoopMode.values.length - 1)];
      final shuffle = progressJson['shuffleEnabled'] == true;
      await service.setLoopMode(loopMode);
      await service.setShuffleModeEnabled(shuffle);
      state = PlaybackState(
        currentSong: songs[index],
        playlist: songs,
        currentIndex: index,
        position: position,
        duration: service.duration,
        loopMode: loopMode,
        shuffleEnabled: shuffle,
        isRestoringSession: false,
      );
    } catch (_) {
      // Ignore stale snapshots so they never prevent a clean player startup.
    } finally {
      _restoring = false;
      if (mounted && state.isRestoringSession) {
        state = state.copyWith(isRestoringSession: false);
      }
    }
  }

  void _scheduleSave() {
    if (_restoring || state.playlist.isEmpty) return;
    if (_saveTimer?.isActive == true) return;
    // Throttle instead of debounce: the position stream is continuous, so a
    // debounced write might never happen before the process is terminated.
    _saveTimer = Timer(const Duration(seconds: 3), () {
      _saveTimer = null;
      unawaited(_saveProgress());
    });
  }

  Future<void> _saveQueue() async {
    if (state.playlist.isEmpty) return;
    final generation = ++_queueSaveGeneration;
    try {
      final playlist = state.playlist.map((song) => song.toJson()).toList();
      final encoded = await Isolate.run(
        () => jsonEncode({'playlist': playlist}),
      );
      if (generation != _queueSaveGeneration) return;
      await _storage.write(key: _queueStorageKey, value: encoded);
    } catch (_) {
      // Playback must remain usable when persistence is unavailable.
    }
  }

  Future<void> _saveProgress() async {
    if (state.playlist.isEmpty) return;
    final generation = ++_progressSaveGeneration;
    final currentIndex = state.currentIndex;
    final positionMs = state.position.inMilliseconds;
    final loopMode = state.loopMode.index;
    final shuffleEnabled = state.shuffleEnabled;
    try {
      if (generation != _progressSaveGeneration) return;
      await _storage.write(
        key: _progressStorageKey,
        value: jsonEncode({
          'currentIndex': currentIndex,
          'positionMs': positionMs,
          'loopMode': loopMode,
          'shuffleEnabled': shuffleEnabled,
        }),
      );
    } catch (_) {
      // Progress persistence is best-effort.
    }
  }

  void _listenToPlayer(AudioPlayerService service) {
    _subscriptions.add(
      service.playerStateStream.listen((playerState) {
        state = state.copyWith(isPlaying: playerState.playing);
      }),
    );

    _subscriptions.add(
      service.positionStream.listen((position) {
        state = state.copyWith(position: position);
        _scheduleSave();
      }),
    );

    _subscriptions.add(
      service.durationStream.listen((duration) {
        state = state.copyWith(duration: duration);
      }),
    );

    _subscriptions.add(
      service.loopModeStream.listen((loopMode) {
        state = state.copyWith(loopMode: loopMode);
      }),
    );

    _subscriptions.add(
      service.currentIndexStream.listen((index) {
        if (index == null || index < 0 || index >= state.playlist.length) {
          return;
        }
        state = state.copyWith(
          currentIndex: index,
          currentSong: state.playlist[index],
        );
        _scheduleSave();
      }),
    );
  }

  /// Plays a single song, replacing the current playlist.
  Future<void> playSong(Song song) async {
    if (_audioService == null) return;
    await _audioService.playSong(song.id);
    state = state.copyWith(
      currentSong: song,
      isPlaying: true,
      playlist: [song],
      currentIndex: 0,
    );
    unawaited(_saveQueue());
    unawaited(_saveProgress());
    _scheduleSave();
  }

  /// Plays a list of songs starting from [startIndex].
  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (_audioService == null || songs.isEmpty) return;
    await _audioService.playPlaylist(
      songs.map((song) => song.id).toList(),
      startIndex: startIndex,
    );
    state = state.copyWith(
      currentSong: songs[startIndex],
      isPlaying: true,
      playlist: songs,
      currentIndex: startIndex,
    );
    unawaited(_saveQueue());
    unawaited(_saveProgress());
    _scheduleSave();
  }

  /// Toggles play / pause.
  Future<void> togglePlayPause() async {
    if (_audioService == null) return;
    if (state.isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.play();
    }
  }

  /// Seeks to [position].
  Future<void> seek(Duration position) async {
    if (_audioService == null) return;
    final previousPosition = state.position;
    // Publish the target immediately so remote-stream latency never makes the
    // progress control feel stuck. Roll back if just_audio cannot seek.
    state = state.copyWith(position: position);
    try {
      await _audioService.seek(position);
      _scheduleSave();
    } catch (_) {
      state = state.copyWith(position: previousPosition);
      rethrow;
    }
  }

  /// Plays the next song in the playlist.
  Future<void> next() async {
    if (_audioService == null || state.playlist.isEmpty) return;
    final index = _audioService.nextIndex;
    if (index == null) return;
    await playAtIndex(index);
  }

  /// Plays the previous song in the playlist.
  Future<void> previous() async {
    if (_audioService == null || state.playlist.isEmpty) return;
    final index = _audioService.previousIndex;
    if (index == null) {
      await seek(Duration.zero);
      return;
    }
    await playAtIndex(index);
  }

  /// Jumps to a song in the active queue without rebuilding the audio source.
  Future<void> playAtIndex(int index) async {
    if (_audioService == null || index < 0 || index >= state.playlist.length) {
      return;
    }
    await _audioService.seekToIndex(index);
    if (!state.isPlaying) {
      unawaited(_audioService.play());
    }
    state = state.copyWith(
      currentSong: state.playlist[index],
      currentIndex: index,
      position: Duration.zero,
      isPlaying: true,
    );
    _scheduleSave();
  }

  /// Inserts [song] into the queue right after the currently playing track.
  Future<void> playNext(Song song) async {
    if (_audioService == null) return;
    final playlist = [...state.playlist];
    final currentIdx = state.currentIndex;

    if (currentIdx < 0 || currentIdx >= playlist.length) {
      // No active queue yet: just start a new playlist.
      await playPlaylist([song]);
      return;
    }

    final insertIdx = (currentIdx + 1).clamp(0, playlist.length);
    playlist.insert(insertIdx, song);

    await _audioService.insertIntoPlaylist(insertIdx, song.id);
    if (!state.isPlaying) {
      unawaited(_audioService.play());
    }
    state = state.copyWith(playlist: playlist);
    unawaited(_saveQueue());
    _scheduleSave();
  }

  /// Toggles shuffle mode.
  Future<void> toggleShuffle() async {
    await _audioService?.toggleShuffle();
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
    _scheduleSave();
  }

  /// Cycles loop mode: off → all → one.
  Future<void> cycleLoopMode() async {
    await _audioService?.cycleLoopMode();
    state = state.copyWith(loopMode: _audioService!.loopMode);
    _scheduleSave();
  }

  Future<PlaybackMode> cyclePlaybackMode() async {
    if (_audioService == null) return state.playbackMode;
    final next = switch (state.playbackMode) {
      PlaybackMode.sequential => PlaybackMode.shuffle,
      PlaybackMode.shuffle => PlaybackMode.repeatAll,
      PlaybackMode.repeatAll => PlaybackMode.repeatOne,
      PlaybackMode.repeatOne => PlaybackMode.sequential,
    };
    final shuffle = next == PlaybackMode.shuffle;
    final loopMode = switch (next) {
      PlaybackMode.repeatAll => LoopMode.all,
      PlaybackMode.repeatOne => LoopMode.one,
      PlaybackMode.sequential || PlaybackMode.shuffle => LoopMode.off,
    };
    await _audioService.setShuffleModeEnabled(shuffle);
    await _audioService.setLoopMode(loopMode);
    state = state.copyWith(shuffleEnabled: shuffle, loopMode: loopMode);
    _scheduleSave();
    return next;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_saveProgress());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

// ━━━ Providers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// The active Subsonic API instance (null when not connected).
final subsonicApiProvider = Provider<SubsonicApi?>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isConnected) return null;
  return SubsonicApi(
    baseUrl: auth.baseUrl!,
    username: auth.username!,
    password: auth.password!,
  );
});

/// The audio player service instance.
final audioPlayerServiceProvider = Provider<AudioPlayerService?>((ref) {
  final api = ref.watch(subsonicApiProvider);
  final service = AudioPlayerService(api);
  ref.onDispose(service.dispose);
  return service;
});

/// The global player state notifier.
final playerProvider = StateNotifierProvider<PlayerNotifier, PlaybackState>((
  ref,
) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  final notifier = PlayerNotifier(
    audioService,
    ref.watch(secureStorageProvider),
  );
  if (audioService != null) {
    notifier.setAudioService(audioService);
  }
  return notifier;
});
