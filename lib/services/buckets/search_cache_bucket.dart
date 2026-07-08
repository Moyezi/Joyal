import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../cache_bucket.dart';
import '_file_utils.dart';

class SearchBucket extends DataCacheBucket<Map<String, dynamic>> {
  static const _historyKey = 'history';
  static const _maxHistory = 30;

  SearchBucket() : super(autoCleanEnabled: false);

  @override
  String get id => 'search';

  @override
  String get label => '搜索缓存';

  @override
  IconData get icon => Icons.search_rounded;

  Future<Directory> get dir async {
    final support = await getApplicationSupportDirectory();
    final d = Directory(
      '${support.path}${Platform.pathSeparator}cache${Platform.pathSeparator}search',
    );
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  File _file(Directory d, String key) =>
      File('${d.path}${Platform.pathSeparator}$key.json');

  @override
  Future<int> calculateSize() async {
    final d = await dir;
    return Isolate.run(() => calculateDirSizeSync(d.path));
  }

  @override
  Future<void> clear() async {
    final d = await dir;
    await Isolate.run(() => deleteContentsSync(d.path));
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final d = await dir;
    await Isolate.run(() => applyLruSync(d.path, targetBytes));
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final d = await dir;
      final file = _file(d, key);
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      final decoded = await Isolate.run(() => jsonDecode(contents));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    final d = await dir;
    final file = _file(d, key);
    final tmp = File('${file.path}.tmp');
    final encoded = await Isolate.run(() => jsonEncode(data));
    await tmp.writeAsString(encoded, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  @override
  Future<void> remove(String key) async {
    final d = await dir;
    final file = _file(d, key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> keys() async {
    final d = await dir;
    final result = <String>[];
    try {
      for (final entry in d.listSync()) {
        if (entry is File && entry.path.endsWith('.json')) {
          result.add(entry.uri.pathSegments.last.replaceAll('.json', ''));
        }
      }
    } catch (_) {}
    return result;
  }

  // ── Search-history helpers ──

  Future<List<String>> loadHistory() async {
    final json = await load(_historyKey);
    if (json == null) return [];
    final list = json['items'] as List<dynamic>?;
    return list?.cast<String>() ?? [];
  }

  Future<void> saveHistory(List<String> history) async {
    await save(_historyKey, {'items': history.take(_maxHistory).toList()});
  }

  Future<void> addToHistory(String query) async {
    final history = await loadHistory();
    history.remove(query);
    history.insert(0, query);
    await saveHistory(history.take(_maxHistory).toList());
  }
}
