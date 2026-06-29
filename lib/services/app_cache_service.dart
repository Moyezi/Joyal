import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Small JSON cache for slow-changing API data and derived visual metadata.
/// Authentication parameters and media streams are deliberately never stored.
class AppCacheService {
  AppCacheService._();

  static final AppCacheService instance = AppCacheService._();

  @visibleForTesting
  static Directory? debugCacheDirectoryOverride;

  Future<void> _writeTail = Future.value();

  String serverScope(String baseUrl, String username) => sha1
      .convert(
        utf8.encode('${baseUrl.toLowerCase()}|${username.toLowerCase()}'),
      )
      .toString();

  Future<Map<String, dynamic>?> readJson(String name) async {
    try {
      final file = await _file(name);
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String name, Map<String, dynamic> value) {
    final operation = _writeTail.then((_) async {
      final file = await _file(name);
      final temporary = File('${file.path}.tmp');
      final encoded = jsonEncode(value);
      await temporary.writeAsString(encoded, flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    });
    final safeOperation = operation.catchError((Object error) {
      debugPrint('[AppCacheService] write failed: $error');
    });
    _writeTail = safeOperation;
    return safeOperation;
  }

  Future<void> prune({
    required String prefix,
    required int maxFiles,
    required Duration maxAge,
  }) async {
    try {
      final sample = await _file('${prefix}sample');
      final files = await sample.parent
          .list()
          .where((item) => item is File && item.path.endsWith('.json'))
          .cast<File>()
          .where((file) => file.uri.pathSegments.last.startsWith(prefix))
          .toList();
      final now = DateTime.now();
      final dated = <({File file, DateTime modified})>[];
      for (final file in files) {
        final modified = await file.lastModified();
        if (now.difference(modified) > maxAge) {
          await file.delete();
        } else {
          dated.add((file: file, modified: modified));
        }
      }
      dated.sort((a, b) => b.modified.compareTo(a.modified));
      for (final entry in dated.skip(maxFiles)) {
        await entry.file.delete();
      }
    } catch (_) {
      // Cache cleanup is best-effort on every supported platform.
    }
  }

  Future<File> _file(String name) async {
    final override = debugCacheDirectoryOverride;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return File('${override.path}${Platform.pathSeparator}$name.json');
    }

    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}cache',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$name.json');
  }
}
