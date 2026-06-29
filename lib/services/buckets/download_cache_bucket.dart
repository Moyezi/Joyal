import 'dart:async';

import 'package:flutter/material.dart';

import '../cache_bucket.dart';

class DownloadBucket extends CacheBucket {
  int currentBytes = 0;

  DownloadBucket();

  @override
  String get id => 'download';

  @override
  String get label => '离线下载';

  @override
  IconData get icon => Icons.download_done_rounded;

  @override
  bool autoCleanEnabled = false;

  @override
  Future<int> calculateSize() async => currentBytes;

  @override
  Future<void> clear() async {
    // Downloads are managed on their dedicated screen; never clear from here.
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    // Downloads are excluded from automatic cleanup.
  }
}
