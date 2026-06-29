// ignore_for_file: prefer_initializing_formals

import 'package:flutter/services.dart';

import '../providers/player_provider.dart';

typedef AndroidMediaControlHandler = Future<void> Function(String action);
typedef AndroidCoverArtPathResolver =
    Future<String?> Function(PlaybackState state);

class AndroidMediaBridge {
  static const MethodChannel _channel = MethodChannel(
    'joyal_music/android_media',
  );
  static const Duration positionSyncInterval = Duration(seconds: 1);

  AndroidMediaBridge({
    MethodChannel channel = _channel,
    AndroidMediaControlHandler? onControlAction,
    AndroidCoverArtPathResolver? resolveCoverArtPath,
    DateTime Function()? now,
  }) : _channelInstance = channel,
       _onControlAction = onControlAction,
       _resolveCoverArtPath = resolveCoverArtPath,
       _now = now ?? DateTime.now {
    _channelInstance.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channelInstance;
  final AndroidMediaControlHandler? _onControlAction;
  final AndroidCoverArtPathResolver? _resolveCoverArtPath;
  final DateTime Function() _now;
  DateTime? _lastSyncAt;
  PlaybackState? _lastSyncedState;
  String? _lastCoverArtId;
  String? _lastCoverArtPath;

  static Map<String, Object?> snapshotPayload(
    PlaybackState state, {
    String? coverArtPath,
  }) {
    final song = state.currentSong;
    if (song == null) {
      return {
        'hasSong': false,
        'isPlaying': false,
        'positionMs': state.position.inMilliseconds,
        'durationMs': state.duration?.inMilliseconds,
        'currentIndex': state.currentIndex,
        'playlistLength': state.playlist.length,
      };
    }

    return {
      'hasSong': true,
      'songId': song.id,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'isPlaying': state.isPlaying,
      'positionMs': state.position.inMilliseconds,
      'durationMs': state.duration?.inMilliseconds,
      'currentIndex': state.currentIndex,
      'playlistLength': state.playlist.length,
      'coverArtId': song.coverArt,
      'coverArtPath': coverArtPath,
    };
  }

  static bool shouldSync({
    required PlaybackState? previous,
    required PlaybackState next,
    required Duration elapsedSinceLastSync,
  }) {
    if (previous == null) return true;
    if (previous.currentSong?.id != next.currentSong?.id) return true;
    if (previous.isPlaying != next.isPlaying) return true;
    if (previous.duration != next.duration) return true;
    if (previous.currentIndex != next.currentIndex) return true;
    if (previous.playlist.length != next.playlist.length) return true;
    return elapsedSinceLastSync >= positionSyncInterval;
  }

  Future<void> sync(PlaybackState state) async {
    final now = _now();
    final elapsed = _lastSyncAt == null
        ? positionSyncInterval
        : now.difference(_lastSyncAt!);
    if (!shouldSync(
      previous: _lastSyncedState,
      next: state,
      elapsedSinceLastSync: elapsed,
    )) {
      return;
    }

    _lastSyncAt = now;
    _lastSyncedState = state;
    final coverArtPath = await _coverArtPathFor(state);
    try {
      await _channelInstance.invokeMethod<void>(
        'updatePlaybackState',
        snapshotPayload(state, coverArtPath: coverArtPath),
      );
    } on PlatformException {
      // Android media surfaces must never interrupt playback.
    } on MissingPluginException {
      // Non-Android platforms do not provide this channel.
    }
  }

  Future<String?> _coverArtPathFor(PlaybackState state) async {
    final coverArtId = state.currentSong?.coverArt;
    if (coverArtId == null || coverArtId.isEmpty) {
      _lastCoverArtId = null;
      _lastCoverArtPath = null;
      return null;
    }
    if (_lastCoverArtId == coverArtId) return _lastCoverArtPath;
    _lastCoverArtId = coverArtId;
    _lastCoverArtPath = null;
    try {
      _lastCoverArtPath = await _resolveCoverArtPath?.call(state);
    } catch (_) {
      // Album art is decorative on Android media surfaces.
    }
    return _lastCoverArtPath;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method != 'mediaControl') return null;
    final action = call.arguments as String?;
    if (action == null) return null;
    await _onControlAction?.call(action);
    return null;
  }

  void dispose() {
    _channelInstance.setMethodCallHandler(null);
  }
}
