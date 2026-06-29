import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cache_stats.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import 'buckets/_file_utils.dart';
import 'buckets/album_cache_bucket.dart';
import 'buckets/artist_cache_bucket.dart';
import 'buckets/download_cache_bucket.dart';
import 'buckets/image_cache_bucket.dart';
import 'buckets/meta_cache_bucket.dart';
import 'buckets/search_cache_bucket.dart';
import 'buckets/stream_cache_bucket.dart';
import 'cache_bucket.dart';

class CacheRepository {
  final StreamBucket streamBucket;
  final ImageBucket imageBucket;
  final MetaBucket metaBucket;
  final DownloadBucket downloadBucket;
  final AlbumBucket albumBucket;
  final ArtistBucket artistBucket;
  final SearchBucket searchBucket;

  List<CacheBucket> get buckets => [
        streamBucket,
        imageBucket,
        metaBucket,
        downloadBucket,
        albumBucket,
        artistBucket,
        searchBucket,
      ];

  CacheRepository({
    required this.streamBucket,
    required this.imageBucket,
    required this.metaBucket,
    required this.downloadBucket,
    required this.albumBucket,
    required this.artistBucket,
    required this.searchBucket,
  });

  /// Return the bucket whose [CacheBucket.id] matches [id], or null.
  CacheBucket? bucket(String id) {
    for (final b in buckets) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Aggregate sizes from every bucket in parallel.
  Future<CacheStats> getStats({required int maxLimitMb}) async {
    final results = await Future.wait([
      streamBucket.calculateSize(),
      imageBucket.calculateSize(),
      metaBucket.calculateSize(),
      downloadBucket.calculateSize(),
      albumBucket.calculateSize(),
      artistBucket.calculateSize(),
      searchBucket.calculateSize(),
    ]);

    return CacheStats(
      streamBytes: results[0],
      imageBytes: results[1],
      metaBytes: results[2],
      downloadBytes: results[3],
      albumBytes: results[4],
      artistBytes: results[5],
      searchBytes: results[6],
      isCalculating: false,
      lastUpdated: DateTime.now(),
      maxLimitMb: maxLimitMb,
    );
  }

  /// Delete everything in a single bucket.
  Future<void> clearBucket(String id) async {
    final b = bucket(id);
    if (b == null) return;
    await b.clear();
  }

  /// Enforce total cache limit across enabled buckets using global LRU.
  Future<void> enforceAutoLimit(int maxBytes) async {
    if (maxBytes <= 0) return;

    final allFiles = <({File file, DateTime modified, int size})>[];
    for (final b in buckets) {
      if (!b.autoCleanEnabled) continue;
      Directory? d;
      Set<String>? excl;

      if (b is StreamBucket) {
        d = await b.dir;
      } else if (b is ImageBucket) {
        d = await b.dir;
      } else if (b is MetaBucket) {
        d = await b.dir;
        excl = MetaBucket.excludeDirs;
      } else if (b is AlbumBucket) {
        d = await b.dir;
      } else if (b is ArtistBucket) {
        d = await b.dir;
      } else if (b is SearchBucket) {
        d = await b.dir;
      } else {
        // DownloadBucket: excluded from cleanup.
        continue;
      }

      if (d != null) {
        final dirPath = d.path;
        final exclude = excl ?? const {};
        final files = await Isolate.run(
          () => listFilesByModifiedSync(dirPath, excludeDirs: exclude),
        );
        allFiles.addAll(files);
      }
    }
    if (allFiles.isEmpty) return;

    allFiles.sort((a, b) => a.modified.compareTo(b.modified));

    var total = allFiles.fold<int>(0, (sum, f) => sum + f.size);
    for (final entry in allFiles) {
      if (total <= maxBytes) break;
      try {
        await entry.file.delete();
        total -= entry.size;
      } catch (_) {}
    }
  }

  // ── Convenience data-access methods ──

  Future<List<Song>?> loadAlbumSongs(String albumId) async {
    final json = await albumBucket.load(albumId);
    if (json == null) return null;
    try {
      final songs = (json['songs'] as List<dynamic>?)
          ?.map((s) => Song.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
      return songs;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAlbumSongs(String albumId, List<Song> songs) async {
    await albumBucket.save(albumId, {
      'songs': songs.map((s) => s.toJson()).toList(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> loadArtistDetail(String artistId) async {
    return artistBucket.load(artistId);
  }

  Future<void> saveArtistDetail(
    String artistId,
    Map<String, dynamic> data,
  ) async {
    await artistBucket.save(artistId, {
      ...data,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Song>?> loadArtistSongs(String artistName) async {
    final json = await artistBucket.load('songs_$artistName');
    if (json == null) return null;
    try {
      final songs = (json['songs'] as List<dynamic>?)
          ?.map((s) => Song.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
      return songs;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveArtistSongs(String artistName, List<Song> songs) async {
    await artistBucket.save('songs_$artistName', {
      'songs': songs.map((s) => s.toJson()).toList(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<String>> loadSearchHistory() async {
    return searchBucket.loadHistory();
  }

  Future<void> saveSearchHistory(List<String> history) async {
    await searchBucket.saveHistory(history);
  }

  Future<void> addToSearchHistory(String query) async {
    await searchBucket.addToHistory(query);
  }

  Future<Map<String, dynamic>?> loadSearchResult(String query) async {
    return searchBucket.load(query);
  }

  Future<void> saveSearchResult(
    String query,
    Map<String, dynamic> data,
  ) async {
    await searchBucket.save(query, {
      ...data,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

/// Riverpod provider for the singleton [CacheRepository].
final cacheRepositoryProvider = Provider<CacheRepository>((ref) {
  final streamBucket = StreamBucket();
  final imageBucket = ImageBucket();
  final metaBucket = MetaBucket();
  final downloadBucket = DownloadBucket();
  final albumBucket = AlbumBucket();
  final artistBucket = ArtistBucket();
  final searchBucket = SearchBucket();

  final repo = CacheRepository(
    streamBucket: streamBucket,
    imageBucket: imageBucket,
    metaBucket: metaBucket,
    downloadBucket: downloadBucket,
    albumBucket: albumBucket,
    artistBucket: artistBucket,
    searchBucket: searchBucket,
  );

  // Wire download size changes into the bucket.
  ref.listen(downloadRecordsProvider, (_, next) {
    final records = next.valueOrNull;
    repo.downloadBucket.currentBytes =
        records?.fold<int>(0, (sum, r) => sum + r.size) ?? 0;
  });

  return repo;
});
