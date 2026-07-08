import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../cache_bucket.dart';
import '_file_utils.dart';

class ImageBucket extends CacheBucket {
  @override
  String get id => 'image';

  @override
  String get label => '图片封面';

  @override
  IconData get icon => Icons.image_rounded;

  Future<Directory?> get dir async {
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

  @override
  Future<int> calculateSize() async {
    final d = await dir;
    final size = d != null
        ? await Isolate.run(() => calculateDirSizeSync(d.path))
        : 0;
    return size;
  }

  @override
  Future<void> clear() async {
    // 1. Empty the flutter_cache_manager's own store.
    try {
      await DefaultCacheManager().emptyCache();
    } catch (error) {
      debugPrint('[ImageBucket] cache manager cleanup failed: $error');
    }
    // 2. Delete temporary image files from libCachedImageData.
    final d = await dir;
    if (d != null) {
      await Isolate.run(() => deleteContentsSync(d.path));
    }
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final d = await dir;
    if (d == null) return;
    await Isolate.run(() => applyLruSync(d.path, targetBytes));
  }
}
