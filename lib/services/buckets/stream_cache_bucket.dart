import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../cache_bucket.dart';
import '_file_utils.dart';

class StreamBucket extends CacheBucket {
  @override
  String get id => 'stream';

  @override
  String get label => '临时音频';

  @override
  IconData get icon => Icons.music_note_rounded;

  Future<Directory?> get dir async {
    try {
      final tmp = await getTemporaryDirectory();
      final exoDir = Directory('${tmp.path}${Platform.pathSeparator}exo');
      if (await exoDir.exists()) return exoDir;
      return tmp;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> calculateSize() async {
    final d = await dir;
    if (d == null) return 0;
    return Isolate.run(() => calculateDirSizeSync(d.path));
  }

  @override
  Future<void> clear() async {
    final d = await dir;
    if (d == null) return;
    await Isolate.run(() => deleteContentsSync(d.path));
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final d = await dir;
    if (d == null) return;
    await Isolate.run(() => applyLruSync(d.path, targetBytes));
  }
}
