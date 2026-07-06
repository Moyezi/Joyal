import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/music_classification.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/deepseek_classification_service.dart';
import '../services/music_classification_repository.dart';
import 'auth_provider.dart';

class MusicClassificationState {
  final AiClassificationSettings settings;
  final Map<String, SongClassification> classifications;
  final ClassificationTaskStatus status;
  final int completedCount;
  final int totalCount;
  final bool isLoading;
  final bool isTestingConnection;
  final String? error;

  const MusicClassificationState({
    this.settings = const AiClassificationSettings(),
    this.classifications = const {},
    this.status = ClassificationTaskStatus.idle,
    this.completedCount = 0,
    this.totalCount = 0,
    this.isLoading = false,
    this.isTestingConnection = false,
    this.error,
  });

  int get classifiedCount => classifications.length;
  bool get isRunning => status == ClassificationTaskStatus.running;
  bool get isPaused => status == ClassificationTaskStatus.paused;
  bool get hasApiKey => settings.apiKeyConfigured;

  double get progress {
    if (totalCount == 0) return 0;
    return (completedCount / totalCount).clamp(0, 1);
  }

  MusicClassificationState copyWith({
    AiClassificationSettings? settings,
    Map<String, SongClassification>? classifications,
    ClassificationTaskStatus? status,
    int? completedCount,
    int? totalCount,
    bool? isLoading,
    bool? isTestingConnection,
    String? error,
    bool clearError = false,
  }) {
    return MusicClassificationState(
      settings: settings ?? this.settings,
      classifications: classifications ?? this.classifications,
      status: status ?? this.status,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MusicClassificationNotifier
    extends StateNotifier<MusicClassificationState> {
  final MusicClassificationRepository _repository;
  final DeepSeekClassificationService _service;
  bool _cancelRequested = false;

  MusicClassificationNotifier(this._repository, this._service)
    : super(const MusicClassificationState());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final settings = await _repository.loadSettings();
      final classifications = await _repository.loadClassifications();
      state = state.copyWith(
        settings: settings,
        classifications: classifications,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> saveSettings({
    String? apiKey,
    required String apiBaseUrl,
    required String model,
    required int batchSize,
    required bool wifiOnly,
    required bool notificationsEnabled,
  }) async {
    final normalizedUrl = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await _repository.saveApiKey(apiKey.trim());
    }
    final settings = state.settings.copyWith(
      apiKeyConfigured: apiKey != null && apiKey.trim().isNotEmpty
          ? true
          : state.settings.apiKeyConfigured,
      apiBaseUrl: normalizedUrl,
      model: model.trim().isEmpty ? 'deepseek-chat' : model.trim(),
      batchSize: batchSize,
      maxConcurrentRequests: 1,
      wifiOnly: wifiOnly,
      notificationsEnabled: notificationsEnabled,
    );
    state = state.copyWith(settings: settings, clearError: true);
    await _persist();
  }

  Future<void> restoreDefaults() async {
    final hasKey = state.settings.apiKeyConfigured;
    final settings = const AiClassificationSettings().copyWith(
      apiKeyConfigured: hasKey,
    );
    state = state.copyWith(settings: settings, clearError: true);
    await _persist();
  }

  Future<void> clearApiKey() async {
    await _repository.clearApiKey();
    state = state.copyWith(
      settings: state.settings.copyWith(apiKeyConfigured: false),
      clearError: true,
    );
    await _persist();
  }

  Future<void> testConnection({
    String? apiKeyOverride,
    AiClassificationSettings? settingsOverride,
  }) async {
    state = state.copyWith(isTestingConnection: true, clearError: true);
    try {
      final key = apiKeyOverride?.trim().isNotEmpty == true
          ? apiKeyOverride!.trim()
          : await _repository.readApiKey();
      if (key == null || key.isEmpty) {
        throw Exception('请先填写 DeepSeek API Key');
      }
      await _service.testConnection(
        apiKey: key,
        settings: settingsOverride ?? state.settings,
      );
      state = state.copyWith(isTestingConnection: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isTestingConnection: false,
        error: _friendlyError(error),
      );
      rethrow;
    }
  }

  Future<void> startClassification(
    List<Song> songs, {
    bool force = false,
    bool lowConfidenceOnly = false,
  }) async {
    if (state.isRunning) return;
    final apiKey = await _repository.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DeepSeek API 尚未配置');
    }

    final pending = _pendingSongs(
      songs,
      force: force,
      lowConfidenceOnly: lowConfidenceOnly,
    );
    if (pending.isEmpty) {
      state = state.copyWith(
        status: ClassificationTaskStatus.completed,
        completedCount: songs.length,
        totalCount: songs.length,
        clearError: true,
      );
      await _persist();
      return;
    }

    _cancelRequested = false;
    state = state.copyWith(
      status: ClassificationTaskStatus.running,
      completedCount: 0,
      totalCount: pending.length,
      clearError: true,
    );
    await _persist();

    try {
      for (
        var offset = 0;
        offset < pending.length;
        offset += state.settings.batchSize
      ) {
        if (_cancelRequested) break;
        while (state.isPaused && !_cancelRequested) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (_cancelRequested) break;

        final batch = pending
            .skip(offset)
            .take(state.settings.batchSize)
            .toList(growable: false);
        final results = await _service.classifySongs(
          apiKey: apiKey,
          settings: state.settings,
          songs: batch,
        );
        final updated = {...state.classifications};
        for (final result in results) {
          updated[result.songId] = result;
        }
        state = state.copyWith(
          classifications: updated,
          completedCount: (state.completedCount + batch.length).clamp(
            0,
            state.totalCount,
          ),
          clearError: true,
        );
        await _persist();
      }

      state = state.copyWith(
        status: _cancelRequested
            ? ClassificationTaskStatus.idle
            : ClassificationTaskStatus.completed,
      );
      await _persist();
    } catch (error) {
      state = state.copyWith(
        status: ClassificationTaskStatus.failed,
        error: _friendlyError(error),
      );
      await _persist();
      rethrow;
    }
  }

  void pause() {
    if (!state.isRunning) return;
    state = state.copyWith(status: ClassificationTaskStatus.paused);
    unawaited(_persist());
  }

  void resume() {
    if (!state.isPaused) return;
    state = state.copyWith(status: ClassificationTaskStatus.running);
    unawaited(_persist());
  }

  void cancel() {
    _cancelRequested = true;
    state = state.copyWith(status: ClassificationTaskStatus.idle);
    unawaited(_persist());
  }

  Future<void> updateManualClassification(SongClassification classification) {
    final updated = {...state.classifications};
    updated[classification.songId] = classification;
    state = state.copyWith(classifications: updated, clearError: true);
    return _persist();
  }

  List<Song> songsForTag(List<Song> songs, String tag) {
    return songs
        .where((song) {
          final item = state.classifications[song.id];
          if (item == null) return false;
          return item.genres.contains(tag) ||
              item.moods.contains(tag) ||
              item.scenes.contains(tag) ||
              item.language == tag ||
              decadeLabelForSong(song) == tag;
        })
        .toList(growable: false);
  }

  int pendingCount(List<Song> songs) => _pendingSongs(songs).length;

  List<Song> _pendingSongs(
    List<Song> songs, {
    bool force = false,
    bool lowConfidenceOnly = false,
  }) {
    return songs
        .where((song) {
          final existing = state.classifications[song.id];
          if (existing?.source == ClassificationSource.manual && !force) {
            return false;
          }
          if (lowConfidenceOnly) {
            return existing != null && existing.confidence < 0.6;
          }
          if (force) return true;
          return existing == null ||
              !existing.matchesCurrentSong(song, state.settings.model);
        })
        .toList(growable: false);
  }

  Future<void> _persist() {
    return _repository.saveStore(
      settings: state.settings,
      classifications: state.classifications,
      taskStatus: state.status,
      completed: state.completedCount,
      total: state.totalCount,
    );
  }

  String _friendlyError(Object error) {
    final value = error is DioException
        ? error.response?.data ?? error.message ?? error.toString()
        : error.toString();
    final text = value.toString().replaceFirst('Exception: ', '');
    if (text.contains('401') || text.contains('invalid')) {
      return 'API Key 无效';
    }
    if (text.contains('429')) return '请求过于频繁';
    if (text.contains('timeout')) return '请求超时';
    return text;
  }
}

final musicClassificationRepositoryProvider =
    Provider<MusicClassificationRepository>((ref) {
      final storage = ref.watch(secureStorageProvider);
      return MusicClassificationRepository(AppCacheService.instance, storage);
    });

final deepSeekClassificationServiceProvider =
    Provider<DeepSeekClassificationService>((ref) {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return DeepSeekClassificationService(dio);
    });

final musicClassificationProvider =
    StateNotifierProvider<
      MusicClassificationNotifier,
      MusicClassificationState
    >((ref) {
      final repository = ref.watch(musicClassificationRepositoryProvider);
      final service = ref.watch(deepSeekClassificationServiceProvider);
      return MusicClassificationNotifier(repository, service)..initialize();
    });
