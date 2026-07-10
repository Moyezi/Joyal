import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/music_classification.dart';
import 'app_cache_service.dart';

class MusicClassificationRepository {
  final AppCacheService _cache;
  final FlutterSecureStorage _secureStorage;

  const MusicClassificationRepository(this._cache, this._secureStorage);

  static const _apiKeyStorageKey = 'deepseek_api_key';
  static const _cacheName = 'music_classification_store';

  Future<String?> readApiKey() => _secureStorage.read(key: _apiKeyStorageKey);

  Future<void> saveApiKey(String apiKey) {
    return _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
  }

  Future<void> clearApiKey() {
    return _secureStorage.delete(key: _apiKeyStorageKey);
  }

  Future<AiClassificationSettings> loadSettings() async {
    final json = await _cache.readJson(_cacheName);
    final raw = json?['settings'];
    final settings = raw is Map
        ? AiClassificationSettings.fromJson(Map<String, dynamic>.from(raw))
        : const AiClassificationSettings();
    final hasKey = await readApiKey() != null;
    return settings.copyWith(apiKeyConfigured: hasKey);
  }

  Future<Map<String, SongClassification>> loadClassifications() async {
    final json = await _cache.readJson(_cacheName);
    final raw = json?['classifications'] as Map<String, dynamic>? ?? {};
    return raw.map(
      (key, value) => MapEntry(
        key,
        SongClassification.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  Future<void> saveStore({
    required AiClassificationSettings settings,
    required Map<String, SongClassification> classifications,
    ClassificationTaskStatus taskStatus = ClassificationTaskStatus.idle,
    int completed = 0,
    int total = 0,
  }) {
    return _cache.writeJson(_cacheName, {
      'version': 1,
      'settings': settings.toJson()..remove('apiKeyConfigured'),
      'taskStatus': taskStatus.name,
      'completed': completed,
      'total': total,
      'classifications': classifications.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    }, encodeInBackground: true);
  }
}
