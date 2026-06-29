import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cache_stats.dart';

class CacheStatsService {
  CacheStatsService._();

  static final CacheStatsService instance = CacheStatsService._();

  Future<Directory?> get _streamCacheDir async {
    try {
      final tmp = await getTemporaryDirectory();
      final exoDir = Directory('${tmp.path}${Platform.pathSeparator}exo');
      if (await exoDir.exists()) return exoDir;
      return tmp;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> get _imageCacheDir async {
    try {
      final tmp = await getTemporaryDirectory();
      final imageDir = Directory(
        '${tmp.path}${Platform.pathSeparator}libCachedImageData',
      );
      if (await imageDir.exists()) return imageDir;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> get _metaCacheDir async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}${Platform.pathSeparator}cache');
      if (await dir.exists()) return dir;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<CacheStats> calculateAll({required int downloadBytes}) async {
    final results = await Future.wait([
      _streamCacheDir.then(_calculateDirSize),
      _imageCacheDir.then(_calculateDirSize),
      _metaCacheDir.then(_calculateDirSize),
    ]);

    return CacheStats(
      streamBytes: results[0],
      imageBytes: results[1],
      metaBytes: results[2],
      downloadBytes: downloadBytes,
      isCalculating: false,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> clearStreamCache() async {
    final dir = await _streamCacheDir;
    if (dir == null) return;
    await Isolate.run(() => _deleteContentsSync(dir.path));
  }

  Future<void> clearImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (error) {
      debugPrint(
        '[CacheStatsService] image cache manager cleanup failed: $error',
      );
    }
    final dir = await _imageCacheDir;
    if (dir != null) {
      await Isolate.run(() => _deleteContentsSync(dir.path));
    }
  }

  Future<void> clearMetaCache() async {
    final dir = await _metaCacheDir;
    if (dir != null) {
      await Isolate.run(() => _deleteContentsSync(dir.path));
    }
  }

  Future<void> applyLru(int maxBytes) async {
    if (maxBytes <= 0) return;
    final streamDir = await _streamCacheDir;
    if (streamDir == null) return;
    try {
      await Isolate.run(() => _applyLruSync(streamDir.path, maxBytes));
    } catch (error) {
      debugPrint('[CacheStatsService] stream cache LRU failed: $error');
    }
  }

  Future<int> _calculateDirSize(Directory? dir) async {
    if (dir == null) return 0;
    try {
      return await Isolate.run(() => _calculateDirSizeSync(dir.path));
    } catch (error) {
      debugPrint('[CacheStatsService] directory size failed: $error');
      return 0;
    }
  }

  static int _calculateDirSizeSync(String dirPath) {
    var total = 0;
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return 0;
      for (final entry in dir.listSync(recursive: true)) {
        if (entry is File) {
          try {
            total += entry.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  static void _deleteContentsSync(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;
      for (final entry in dir.listSync()) {
        try {
          entry.deleteSync(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static void _applyLruSync(String dirPath, int maxBytes) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;

      final files = <({File file, DateTime modified, int size})>[];
      for (final entry in dir.listSync(recursive: true)) {
        if (entry is File) {
          try {
            files.add((
              file: entry,
              modified: entry.lastModifiedSync(),
              size: entry.lengthSync(),
            ));
          } catch (_) {}
        }
      }

      files.sort((a, b) => a.modified.compareTo(b.modified));
      var total = files.fold<int>(0, (sum, item) => sum + item.size);
      for (final item in files) {
        if (total <= maxBytes) break;
        try {
          item.file.deleteSync();
          total -= item.size;
        } catch (_) {}
      }
    } catch (_) {}
  }
}
