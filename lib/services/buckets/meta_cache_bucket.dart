import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../cache_bucket.dart';
import '_file_utils.dart';

class MetaBucket extends CacheBucket {
  static const excludeDirs = {'album', 'artist', 'search'};

  MetaBucket() : super(autoCleanEnabled: false);

  @override
  String get id => 'meta';

  @override
  String get label => '歌词元数据';

  @override
  IconData get icon => Icons.description_rounded;

  Future<Directory?> get dir async {
    try {
      final support = await getApplicationSupportDirectory();
      final d = Directory('${support.path}${Platform.pathSeparator}cache');
      if (await d.exists()) return d;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> calculateSize() async {
    final d = await dir;
    if (d == null) return 0;
    return Isolate.run(() {
      var total = 0;
      try {
        for (final entry in d.listSync()) {
          if (entry is File && entry.path.endsWith('.json')) {
            try {
              total += entry.lengthSync();
            } catch (_) {}
          }
        }
      } catch (_) {}
      return total;
    });
  }

  @override
  Future<void> clear() async {
    final d = await dir;
    if (d == null) return;
    await Isolate.run(() => deleteContentsExcludingSync(d.path, excludeDirs));
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final d = await dir;
    if (d == null) return;
    await Isolate.run(
      () => applyLruSync(d.path, targetBytes, excludeDirs: excludeDirs),
    );
  }
}
