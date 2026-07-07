import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/cache_stats.dart';
import 'package:joyal_music/providers/cache_provider.dart';
import 'package:joyal_music/services/buckets/album_cache_bucket.dart';
import 'package:joyal_music/services/buckets/artist_cache_bucket.dart';
import 'package:joyal_music/services/buckets/download_cache_bucket.dart';
import 'package:joyal_music/services/buckets/image_cache_bucket.dart';
import 'package:joyal_music/services/buckets/meta_cache_bucket.dart';
import 'package:joyal_music/services/buckets/search_cache_bucket.dart';
import 'package:joyal_music/services/buckets/stream_cache_bucket.dart';
import 'package:joyal_music/services/cache_bucket.dart';
import 'package:joyal_music/services/cache_repository.dart';

void main() {
  test(
    'refresh waits for persisted cache limit before calculating stats',
    () async {
      final storage = _MemorySecureStorage(
        initialValues: {'cache_max_limit_mb_v1': '1024'},
        readDelay: const Duration(milliseconds: 20),
      );
      final repo = _FakeCacheRepository();
      final notifier = CacheNotifier(repo: repo, storage: storage);

      await notifier.refresh(force: true);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.maxLimitMb, 1024);
      expect(repo.statsRequests, isNotEmpty);
      expect(repo.statsRequests, everyElement(1024));
    },
  );
}

class _FakeCacheRepository extends CacheRepository {
  _FakeCacheRepository()
    : super(
        streamBucket: StreamBucket(),
        imageBucket: ImageBucket(),
        metaBucket: MetaBucket(),
        downloadBucket: DownloadBucket(),
        albumBucket: AlbumBucket(),
        artistBucket: ArtistBucket(),
        searchBucket: SearchBucket(),
      );

  final statsRequests = <int>[];
  final _buckets = [_FakeBucket('stream'), _FakeBucket('image')];

  @override
  List<CacheBucket> get buckets => _buckets;

  @override
  CacheBucket? bucket(String id) {
    for (final bucket in _buckets) {
      if (bucket.id == id) return bucket;
    }
    return null;
  }

  @override
  Future<CacheStats> getStats({required int maxLimitMb}) async {
    statsRequests.add(maxLimitMb);
    return CacheStats(maxLimitMb: maxLimitMb, lastUpdated: DateTime.now());
  }

  @override
  Future<void> enforceAutoLimit(int maxBytes) async {}
}

class _FakeBucket extends CacheBucket {
  _FakeBucket(this.id);

  @override
  final String id;

  @override
  String get label => id;

  @override
  IconData get icon => Icons.storage_rounded;

  @override
  bool get autoCleanEnabled => _autoCleanEnabled;

  @override
  set autoCleanEnabled(bool value) {
    _autoCleanEnabled = value;
  }

  bool _autoCleanEnabled = true;

  @override
  Future<int> calculateSize() async => 0;

  @override
  Future<void> clear() async {}

  @override
  Future<void> pruneByLru(int targetBytes) async {}
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage({
    required Map<String, String> initialValues,
    this.readDelay = Duration.zero,
  }) : _values = Map<String, String>.from(initialValues);

  final Map<String, String> _values;
  final Duration readDelay;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (readDelay > Duration.zero) {
      await Future<void>.delayed(readDelay);
    }
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}
