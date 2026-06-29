import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cache_stats.dart';
import '../services/app_cache_service.dart';
import '../services/cache_repository.dart';
import 'auth_provider.dart';
import 'library_provider.dart';

class CacheNotifier extends StateNotifier<CacheStats> {
  static const _limitKey = 'cache_max_limit_mb_v1';
  static const _autoCleanPrefix = 'cache_auto_clean_';
  static const _settingsCacheName = 'cache_settings';
  static const _refreshThrottle = Duration(seconds: 5);

  final CacheRepository _repo;
  final FlutterSecureStorage _storage;
  int _downloadBytes = 0;

  CacheNotifier({
    required CacheRepository repo,
    required FlutterSecureStorage storage,
  }) : _repo = repo,
       _storage = storage,
       super(const CacheStats()) {
    unawaited(_loadAndRefresh());
  }

  Future<void> refresh({bool force = false}) async {
    if (state.isCalculating) return;
    if (!force &&
        state.lastUpdated != null &&
        DateTime.now().difference(state.lastUpdated!) < _refreshThrottle) {
      return;
    }

    state = state.copyWith(isCalculating: true, downloadBytes: _downloadBytes);
    final stats = await _repo.getStats(maxLimitMb: state.maxLimitMb);
    state = stats;
    await _enforceIfNeeded();
  }

  Future<void> clearBucket(String id) async {
    await _repo.clearBucket(id);
    await refresh(force: true);
  }

  // ── Convenience aliases ──

  Future<void> clearStream() => clearBucket('stream');
  Future<void> clearImages() => clearBucket('image');
  Future<void> clearMeta() => clearBucket('meta');
  Future<void> clearAlbum() => clearBucket('album');
  Future<void> clearArtist() => clearBucket('artist');
  Future<void> clearSearch() => clearBucket('search');

  // ── Limit ──

  Future<void> setMaxLimit(int maxLimitMb) async {
    state = state.copyWith(maxLimitMb: maxLimitMb);
    await _storage.write(key: _limitKey, value: '$maxLimitMb');
    await AppCacheService.instance.writeJson(_settingsCacheName, {
      'maxLimitMb': maxLimitMb,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await _enforceIfNeeded();
  }

  void updateDownloadBytes(int bytes) {
    _downloadBytes = bytes;
  }

  // ── Auto-clean switch ──

  Future<bool> isAutoCleanEnabled(String bucketId) async {
    final raw = await _storage.read(key: '$_autoCleanPrefix$bucketId');
    if (raw == null) return bucketId == 'stream' || bucketId == 'image';
    return raw == 'true';
  }

  Future<void> setAutoCleanEnabled(String bucketId, bool enabled) async {
    final bucket = _repo.bucket(bucketId);
    if (bucket != null) bucket.autoCleanEnabled = enabled;
    await _storage.write(
      key: '$_autoCleanPrefix$bucketId',
      value: enabled.toString(),
    );
    await _enforceIfNeeded();
  }

  // ── Internal ──

  Future<void> _loadAndRefresh() async {
    final saved = await _loadSavedLimit();
    if (saved != null && CacheStats.limitPresets.contains(saved)) {
      state = state.copyWith(maxLimitMb: saved);
    }
    for (final b in _repo.buckets) {
      final enabled = await isAutoCleanEnabled(b.id);
      b.autoCleanEnabled = enabled;
    }
    await refresh(force: true);
  }

  Future<int?> _loadSavedLimit() async {
    final raw = await _storage.read(key: _limitKey);
    final secureValue = int.tryParse(raw ?? '');
    if (secureValue != null) return secureValue;

    final cached = await AppCacheService.instance.readJson(_settingsCacheName);
    final cachedValue = (cached?['maxLimitMb'] as num?)?.toInt();
    if (cachedValue != null) {
      await _storage.write(key: _limitKey, value: '$cachedValue');
    }
    return cachedValue;
  }

  Future<void> _enforceIfNeeded() async {
    if (!state.hasLimit) return;
    final current = state.totalBytes;
    if (current <= state.maxLimitBytes) return;
    await _repo.enforceAutoLimit(state.maxLimitBytes);
    final stats = await _repo.getStats(maxLimitMb: state.maxLimitMb);
    state = stats;
  }
}

final cacheProvider = StateNotifierProvider<CacheNotifier, CacheStats>((ref) {
  final repo = ref.watch(cacheRepositoryProvider);
  final notifier = CacheNotifier(
    repo: repo,
    storage: ref.watch(secureStorageProvider),
  );

  ref.listen(downloadRecordsProvider, (_, next) {
    final records = next.valueOrNull;
    if (records == null) return;
    final bytes = records.fold<int>(0, (sum, r) => sum + r.size);
    notifier.updateDownloadBytes(bytes);
  });

  return notifier;
});
