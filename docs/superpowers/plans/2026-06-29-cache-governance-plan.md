# 全面缓存治理 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将所有缓存类型（音频、图片、元数据、下载、专辑、艺人、搜索）纳入统一的 CacheBucket + CacheRepository 架构，支持分类清理、统一自动清理上限和分类开关、缓存优先加载。

**Architecture:** 新建 `CacheBucket` 抽象接口和 `CacheRepository` 中枢单例，将现有 `CacheStatsService` 和 `AppCacheService` 的职责按类型拆入 7 个独立 Bucket。UI 层通过 Riverpod `cacheRepositoryProvider` 获取统计和触发操作。新增专辑/艺人/搜索磁盘 JSON 缓存，采用缓存优先加载策略。

**Tech Stack:** Flutter/Dart, Riverpod, flutter_secure_storage, Isolate.run, path_provider, flutter_cache_manager, dio

## Implementation Notes

- Bucket `dir` / `dir` getters and `excludeDirs` must be **public** (not `_`-prefixed) so `CacheRepository.enforceAutoLimit` can scan them.
- `DownloadBucket.currentBytes` must be public; the provider wires it from download records.
- `LibraryNotifier` receives `CacheRepository` via constructor (not `ref.read`), since `StateNotifier` has no `ref` access.
- Provider naming: Only `cacheRepositoryProvider` exists (Task 9), which also wires download bytes. No second provider needed.

## Global Constraints

- 缓存优先加载：先展示磁盘缓存 → 后台 API 刷新 → 成功覆盖 UI+缓存，失败静默保留已有缓存
- 专辑/艺人/搜索缓存不自动过期，手动刷新为主
- 自动清理：统一总容量上限 + 每 bucket 独立开关，LRU 跨 bucket 按文件修改时间全局排序
- MetaBucket 扫描 `appSupport/cache/*.json` 时排除 `album/`、`artist/`、`search/` 子目录
- 离线下载不参与自动清理，缓存管理页仅跳转下载管理
- 搜索历史最多保留 30 条
- Widget 优先通过 `ThemeContext` 获取颜色，禁止硬编码
- 使用 `Isolate.run` 进行磁盘 I/O，不阻塞 UI
- 不传输真实明文凭据

---

### Task 1: Create CacheBucket interface and shared utilities

**Files:**
- Create: `lib/services/cache_bucket.dart`
- Create: `lib/services/buckets/_file_utils.dart`

**Interfaces:**
- Produces: `CacheBucket` (abstract class), `DataCacheBucket<T>` (abstract class), `_calculateDirSizeSync`, `_deleteContentsSync`, `_applyLruSync`, `_listFilesSyncByModified`

- [ ] **Step 1: Write `cache_bucket.dart`**

```dart
import 'package:flutter/material.dart';

/// Unified interface for every cache bucket in the app.
abstract class CacheBucket {
  /// Unique identifier (e.g. 'stream', 'image', 'album').
  String get id;

  /// Human-readable label shown in cache management UI.
  String get label;

  /// Icon shown next to this bucket in cache management UI.
  IconData get icon;

  /// Total bytes occupied by this bucket's files on disk.
  Future<int> calculateSize();

  /// Delete every file managed by this bucket.
  Future<void> clear();

  /// Delete oldest files (by last-modified time) until total size
  /// drops to at most [targetBytes]. No-op when already under the limit.
  Future<void> pruneByLru(int targetBytes);

  /// Whether this bucket participates in automatic cache cleanup.
  bool autoCleanEnabled;
}

/// A [CacheBucket] that stores typed data keyed by a string identifier.
abstract class DataCacheBucket<T> extends CacheBucket {
  /// Read the cached value for [key], or null when not cached.
  Future<T?> load(String key);

  /// Persist [data] under [key], overwriting any previous value.
  Future<void> save(String key, T data);

  /// Remove the cached entry for [key].
  Future<void> remove(String key);

  /// List every key currently stored in this bucket.
  Future<List<String>> keys();
}
```

- [ ] **Step 2: Write `_file_utils.dart`** — shared file-system helpers used by all file-based buckets

```dart
import 'dart:io';

/// Recursively sum file sizes in [dirPath], returning 0 on any error.
int calculateDirSizeSync(String dirPath) {
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

/// Recursively delete every child inside [dirPath] without removing the
/// directory itself.  Never throws.
void deleteContentsSync(String dirPath) {
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

/// Recursively delete every child inside [dirPath] that matches
/// any directory name in [excludeDirs] (top-level only).
void deleteContentsExcludingSync(String dirPath, Set<String> excludeDirs) {
  try {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;
    for (final entry in dir.listSync()) {
      if (excludeDirs.contains(entry.uri.pathSegments.last)) continue;
      try {
        entry.deleteSync(recursive: true);
      } catch (_) {}
    }
  } catch (_) {}
}

/// Return every regular file under [dirPath] sorted by last-modified time
/// (oldest first).  Each record carries size for LRU accounting.
List<({File file, DateTime modified, int size})> listFilesByModifiedSync(
  String dirPath, {
  Set<String> excludeDirs = const {},
}) {
  final result = <({File file, DateTime modified, int size})>[];
  try {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return result;
    void walk(Directory current) {
      for (final entry in current.listSync()) {
        if (entry is File) {
          try {
            result.add((
              file: entry,
              modified: entry.lastModifiedSync(),
              size: entry.lengthSync(),
            ));
          } catch (_) {}
        } else if (entry is Directory) {
          if (excludeDirs.contains(entry.uri.pathSegments.last)) continue;
          walk(entry);
        }
      }
    }
    walk(dir);
    result.sort((a, b) => a.modified.compareTo(b.modified));
  } catch (_) {}
  return result;
}

/// Delete oldest files from [dirPath] until total remaining size ≤ [maxBytes].
/// Respects [excludeDirs] at the top level.
void applyLruSync(
  String dirPath,
  int maxBytes, {
  Set<String> excludeDirs = const {},
}) {
  if (maxBytes <= 0) return;
  try {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;
    final files = listFilesByModifiedSync(dirPath, excludeDirs: excludeDirs);

    var total = files.fold<int>(0, (sum, f) => sum + f.size);
    for (final entry in files) {
      if (total <= maxBytes) break;
      try {
        entry.file.deleteSync();
        total -= entry.size;
      } catch (_) {}
    }
  } catch (_) {}
}
```

- [ ] **Step 3: Run static analysis**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS
dart analyze lib/services/cache_bucket.dart lib/services/buckets/_file_utils.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/services/cache_bucket.dart lib/services/buckets/_file_utils.dart
git commit -m "feat: add CacheBucket interface and shared file utils"
```

---

### Task 2: Implement StreamBucket

**Files:**
- Create: `lib/services/buckets/stream_cache_bucket.dart`

**Interfaces:**
- Consumes: `CacheBucket`, `_file_utils.dart`
- Produces: `StreamBucket` — id `'stream'`, manages `temp/exo/` directory

- [ ] **Step 1: Write `stream_cache_bucket.dart`**

```dart
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

  @override
  bool autoCleanEnabled = true;

  Future<Directory?> get _dir async {
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
    final dir = await _dir;
    if (dir == null) return 0;
    return Isolate.run(() => calculateDirSizeSync(dir.path));
  }

  @override
  Future<void> clear() async {
    final dir = await _dir;
    if (dir == null) return;
    await Isolate.run(() => deleteContentsSync(dir.path));
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final dir = await _dir;
    if (dir == null) return;
    await Isolate.run(() => applyLruSync(dir.path, targetBytes));
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/services/buckets/stream_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/buckets/stream_cache_bucket.dart
git commit -m "feat: add StreamBucket"
```

---

### Task 3: Implement ImageBucket

**Files:**
- Create: `lib/services/buckets/image_cache_bucket.dart`

**Interfaces:**
- Consumes: `CacheBucket`, `_file_utils.dart`, `flutter_cache_manager`
- Produces: `ImageBucket` — id `'image'`, manages `libCachedImageData/` + `DefaultCacheManager`

- [ ] **Step 1: Write `image_cache_bucket.dart`**

```dart
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
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

  @override
  bool autoCleanEnabled = true;

  Future<Directory?> get _dir async {
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
    final dir = await _dir;
    final size = dir != null
        ? await Isolate.run(() => calculateDirSizeSync(dir.path))
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
    final dir = await _dir;
    if (dir != null) {
      await Isolate.run(() => deleteContentsSync(dir.path));
    }
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final dir = await _dir;
    if (dir == null) return;
    await Isolate.run(() => applyLruSync(dir.path, targetBytes));
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/services/buckets/image_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/buckets/image_cache_bucket.dart
git commit -m "feat: add ImageBucket"
```

---

### Task 4: Implement MetaBucket

**Files:**
- Create: `lib/services/buckets/meta_cache_bucket.dart`

**Interfaces:**
- Consumes: `CacheBucket`, `_file_utils.dart`
- Produces: `MetaBucket` — id `'meta'`, manages `appSupport/cache/*.json` excluding `album/`, `artist/`, `search/`

- [ ] **Step 1: Write `meta_cache_bucket.dart`**

```dart
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../cache_bucket.dart';
import '_file_utils.dart';

class MetaBucket extends CacheBucket {
  static const _excludeDirs = {'album', 'artist', 'search'};

  @override
  String get id => 'meta';

  @override
  String get label => '歌词元数据';

  @override
  IconData get icon => Icons.description_rounded;

  @override
  bool autoCleanEnabled = false;

  Future<Directory?> get _dir async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}${Platform.pathSeparator}cache');
      if (await dir.exists()) return dir;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> calculateSize() async {
    final dir = await _dir;
    if (dir == null) return 0;
    return Isolate.run(() {
      // Sum all .json files at root; skip excluded subdirs.
      var total = 0;
      try {
        for (final entry in dir.listSync()) {
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
    final dir = await _dir;
    if (dir == null) return;
    await Isolate.run(
      () => deleteContentsExcludingSync(dir.path, _excludeDirs),
    );
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final dir = await _dir;
    if (dir == null) return;
    await Isolate.run(
      () => applyLruSync(dir.path, targetBytes, excludeDirs: _excludeDirs),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/services/buckets/meta_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/buckets/meta_cache_bucket.dart
git commit -m "feat: add MetaBucket"
```

---

### Task 5: Implement DownloadBucket

**Files:**
- Create: `lib/services/buckets/download_cache_bucket.dart`

**Interfaces:**
- Consumes: `CacheBucket`
- Produces: `DownloadBucket` — id `'download'`, size reported via callback (not disk scan), `clear()` and `pruneByLru()` are no-ops

- [ ] **Step 1: Write `download_cache_bucket.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../cache_bucket.dart';

class DownloadBucket extends CacheBucket {
  final Stream<int> _sizeStream;
  int _currentBytes = 0;

  DownloadBucket(Stream<int> sizeStream) : _sizeStream = sizeStream {
    _sizeStream.listen((bytes) {
      _currentBytes = bytes;
    });
  }

  @override
  String get id => 'download';

  @override
  String get label => '离线下载';

  @override
  IconData get icon => Icons.download_done_rounded;

  @override
  bool autoCleanEnabled = false;

  @override
  Future<int> calculateSize() async => _currentBytes;

  @override
  Future<void> clear() async {
    // Downloads are managed on their dedicated screen; never clear from here.
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    // Downloads are excluded from automatic cleanup.
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/services/buckets/download_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/buckets/download_cache_bucket.dart
git commit -m "feat: add DownloadBucket"
```

---

### Task 6: Implement AlbumBucket (data-type)

**Files:**
- Create: `lib/services/buckets/album_cache_bucket.dart`

**Interfaces:**
- Consumes: `DataCacheBucket<Map<String, dynamic>>`, `_file_utils.dart`
- Produces: `AlbumBucket` — id `'album'`, stores JSON in `appSupport/cache/album/`

- [ ] **Step 1: Write `album_cache_bucket.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../cache_bucket.dart';
import '_file_utils.dart';

class AlbumBucket extends DataCacheBucket<Map<String, dynamic>> {
  @override
  String get id => 'album';

  @override
  String get label => '专辑缓存';

  @override
  IconData get icon => Icons.album_rounded;

  @override
  bool autoCleanEnabled = false;

  Future<Directory> get _dir async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}cache${Platform.pathSeparator}album',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _file(Directory dir, String key) =>
      File('${dir.path}${Platform.pathSeparator}$key.json');

  @override
  Future<int> calculateSize() async {
    final dir = await _dir;
    return Isolate.run(() => calculateDirSizeSync(dir.path));
  }

  @override
  Future<void> clear() async {
    final dir = await _dir;
    await Isolate.run(() => deleteContentsSync(dir.path));
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final dir = await _dir;
    await Isolate.run(() => applyLruSync(dir.path, targetBytes));
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final dir = await _dir;
      final file = _file(dir, key);
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
    final dir = await _dir;
    final file = _file(dir, key);
    final tmp = File('${file.path}.tmp');
    final encoded = await Isolate.run(() => jsonEncode(data));
    await tmp.writeAsString(encoded, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  @override
  Future<void> remove(String key) async {
    final dir = await _dir;
    final file = _file(dir, key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> keys() async {
    final dir = await _dir;
    final result = <String>[];
    try {
      for (final entry in dir.listSync()) {
        if (entry is File && entry.path.endsWith('.json')) {
          result.add(
            entry.uri.pathSegments.last.replaceAll('.json', ''),
          );
        }
      }
    } catch (_) {}
    return result;
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/services/buckets/album_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/buckets/album_cache_bucket.dart
git commit -m "feat: add AlbumBucket"
```

---

### Task 7: Implement ArtistBucket (data-type)

**Files:**
- Create: `lib/services/buckets/artist_cache_bucket.dart`

**Interfaces:**
- Consumes: `DataCacheBucket<Map<String, dynamic>>`, `_file_utils.dart`
- Produces: `ArtistBucket` — id `'artist'`, stores JSON in `appSupport/cache/artist/`

- [ ] **Step 1: Write `artist_cache_bucket.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../cache_bucket.dart';
import '_file_utils.dart';

class ArtistBucket extends DataCacheBucket<Map<String, dynamic>> {
  @override
  String get id => 'artist';

  @override
  String get label => '艺人缓存';

  @override
  IconData get icon => Icons.person_rounded;

  @override
  bool autoCleanEnabled = false;

  Future<Directory> get _dir async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}cache${Platform.pathSeparator}artist',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _file(Directory dir, String key) =>
      File('${dir.path}${Platform.pathSeparator}$key.json');

  @override
  Future<int> calculateSize() async {
    final dir = await _dir;
    return Isolate.run(() => calculateDirSizeSync(dir.path));
  }

  @override
  Future<void> clear() async {
    final dir = await _dir;
    await Isolate.run(() => deleteContentsSync(dir.path));
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final dir = await _dir;
    await Isolate.run(() => applyLruSync(dir.path, targetBytes));
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final dir = await _dir;
      final file = _file(dir, key);
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
    final dir = await _dir;
    final file = _file(dir, key);
    final tmp = File('${file.path}.tmp');
    final encoded = await Isolate.run(() => jsonEncode(data));
    await tmp.writeAsString(encoded, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  @override
  Future<void> remove(String key) async {
    final dir = await _dir;
    final file = _file(dir, key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> keys() async {
    final dir = await _dir;
    final result = <String>[];
    try {
      for (final entry in dir.listSync()) {
        if (entry is File && entry.path.endsWith('.json')) {
          result.add(
            entry.uri.pathSegments.last.replaceAll('.json', ''),
          );
        }
      }
    } catch (_) {}
    return result;
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/services/buckets/artist_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/buckets/artist_cache_bucket.dart
git commit -m "feat: add ArtistBucket"
```

---

### Task 8: Implement SearchBucket (data-type)

**Files:**
- Create: `lib/services/buckets/search_cache_bucket.dart`

**Interfaces:**
- Consumes: `DataCacheBucket<Map<String, dynamic>>`, `_file_utils.dart`
- Produces: `SearchBucket` — id `'search'`, stores JSON in `appSupport/cache/search/`, max 30 history entries

- [ ] **Step 1: Write `search_cache_bucket.dart`**

```dart
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

  @override
  String get id => 'search';

  @override
  String get label => '搜索缓存';

  @override
  IconData get icon => Icons.search_rounded;

  @override
  bool autoCleanEnabled = false;

  Future<Directory> get _dir async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}cache${Platform.pathSeparator}search',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _file(Directory dir, String key) =>
      File('${dir.path}${Platform.pathSeparator}$key.json');

  @override
  Future<int> calculateSize() async {
    final dir = await _dir;
    return Isolate.run(() => calculateDirSizeSync(dir.path));
  }

  @override
  Future<void> clear() async {
    final dir = await _dir;
    await Isolate.run(() => deleteContentsSync(dir.path));
  }

  @override
  Future<void> pruneByLru(int targetBytes) async {
    if (targetBytes <= 0) return;
    final dir = await _dir;
    await Isolate.run(() => applyLruSync(dir.path, targetBytes));
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final dir = await _dir;
      final file = _file(dir, key);
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
    final dir = await _dir;
    final file = _file(dir, key);
    final tmp = File('${file.path}.tmp');
    final encoded = await Isolate.run(() => jsonEncode(data));
    await tmp.writeAsString(encoded, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  @override
  Future<void> remove(String key) async {
    final dir = await _dir;
    final file = _file(dir, key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> keys() async {
    final dir = await _dir;
    final result = <String>[];
    try {
      for (final entry in dir.listSync()) {
        if (entry is File && entry.path.endsWith('.json')) {
          result.add(
            entry.uri.pathSegments.last.replaceAll('.json', ''),
          );
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
    await save(_historyKey, {
      'items': history.take(_maxHistory).toList(),
    });
  }

  Future<void> addToHistory(String query) async {
    final history = await loadHistory();
    history.remove(query);
    history.insert(0, query);
    await saveHistory(history.take(_maxHistory).toList());
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/services/buckets/search_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/buckets/search_cache_bucket.dart
git commit -m "feat: add SearchBucket"
```

---

### Task 9: Create CacheRepository

**Files:**
- Create: `lib/services/cache_repository.dart`

**Interfaces:**
- Consumes: all 7 buckets, `CacheStats`
- Produces: `CacheRepository` (singleton), `cacheRepositoryProvider`

- [ ] **Step 1: Write `cache_repository.dart`**

```dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cache_stats.dart';
import '../models/song.dart';
import 'cache_bucket.dart';
import 'buckets/album_cache_bucket.dart';
import 'buckets/artist_cache_bucket.dart';
import 'buckets/download_cache_bucket.dart';
import 'buckets/image_cache_bucket.dart';
import 'buckets/meta_cache_bucket.dart';
import 'buckets/search_cache_bucket.dart';
import 'buckets/stream_cache_bucket.dart';
import 'buckets/_file_utils.dart';

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

  /// Aggregate sizes from every bucket in parallel.  Returns a fresh
  /// [CacheStats] without mutation.
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
  ///
  /// Collects every file from every bucket where [autoCleanEnabled] is true,
  /// sorts them by last-modified time globally, and deletes the oldest until
  /// total size ≤ [maxBytes].
  Future<void> enforceAutoLimit(int maxBytes) async {
    if (maxBytes <= 0) return;
    // Gather all files from enabled buckets.
    final allFiles = <({File file, DateTime modified, int size})>[];
    for (final b in buckets) {
      if (!b.autoCleanEnabled) continue;
      if (b is StreamBucket) {
        final dir = await b._dir;
        if (dir != null) {
          final files = await Isolate.run(
            () => listFilesByModifiedSync(dir.path),
          );
          allFiles.addAll(files);
        }
      } else if (b is ImageBucket) {
        final dir = await b._dir;
        if (dir != null) {
          final files = await Isolate.run(
            () => listFilesByModifiedSync(dir.path),
          );
          allFiles.addAll(files);
        }
      } else if (b is MetaBucket) {
        final dir = await b._dir;
        if (dir != null) {
          final files = await Isolate.run(
            () => listFilesByModifiedSync(
              dir.path,
              excludeDirs: MetaBucket._excludeDirs,
            ),
          );
          allFiles.addAll(files);
        }
      } else if (b is AlbumBucket || b is ArtistBucket || b is SearchBucket) {
        final dir = await (b as dynamic)._dir as Directory;
        final files = await Isolate.run(
          () => listFilesByModifiedSync(dir.path),
        );
        allFiles.addAll(files);
      }
    }
    if (allFiles.isEmpty) return;

    // Sort oldest-first globally.
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

  Future<List<String>?> loadSearchHistory() async {
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
  final downloadBytesStream = ref.watch(downloadRecordsProvider).map(
    (records) => records.valueOrNull?.fold<int>(
      0,
      (sum, r) => sum + r.size,
    ) ?? 0,
  );

  final streamBucket = StreamBucket();
  final imageBucket = ImageBucket();
  final metaBucket = MetaBucket();
  final downloadBucket = DownloadBucket(Stream.value(0));
  final albumBucket = AlbumBucket();
  final artistBucket = ArtistBucket();
  final searchBucket = SearchBucket();

  // Wire download size changes into the bucket.
  downloadBytesStream.listen((bytes) {
    downloadBucket.currentBytes = bytes;
  });

  return CacheRepository(
    streamBucket: streamBucket,
    imageBucket: imageBucket,
    metaBucket: metaBucket,
    downloadBucket: downloadBucket,
    albumBucket: albumBucket,
    artistBucket: artistBucket,
    searchBucket: searchBucket,
  );
});
```

- [ ] **Step 2: Make `StreamBucket._dir`, `ImageBucket._dir`, `MetaBucket._dir`, `MetaBucket._excludeDirs` accessible to `CacheRepository`

  The repository's `enforceAutoLimit` needs to scan each bucket's directory.  Make the directory getters and exclusion set public:

  **In `stream_cache_bucket.dart`**, rename `_dir` → `dir` (public getter):

```dart
  Future<Directory?> get dir async { // was _dir
    try {
      final tmp = await getTemporaryDirectory();
      final exoDir = Directory('${tmp.path}${Platform.pathSeparator}exo');
      if (await exoDir.exists()) return exoDir;
      return tmp;
    } catch (_) {
      return null;
    }
  }
```

  **In `image_cache_bucket.dart`**, same rename `_dir` → `dir`.

  **In `meta_cache_bucket.dart`**, rename `_dir` → `dir` and `_excludeDirs` → `excludeDirs` (public static const).

  **In `download_cache_bucket.dart`**, rename `_currentBytes` → `currentBytes` (public).

  Then update all internal references in those files and `cache_repository.dart` to use the public names.

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/services/cache_repository.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/services/cache_repository.dart
git add lib/services/buckets/stream_cache_bucket.dart
git add lib/services/buckets/image_cache_bucket.dart
git add lib/services/buckets/meta_cache_bucket.dart
git commit -m "feat: add CacheRepository with all 7 buckets"
```

---

### Task 10: Extend CacheStats model

**Files:**
- Modify: `lib/models/cache_stats.dart`

- [ ] **Step 1: Add `albumBytes`, `artistBytes`, `searchBytes` fields**

  Replace the entire file:

```dart
class CacheStats {
  static const List<int> limitPresets = [500, 1024, 2048, 5120, 0];

  final int streamBytes;
  final int imageBytes;
  final int metaBytes;
  final int downloadBytes;
  final int albumBytes;
  final int artistBytes;
  final int searchBytes;
  final bool isCalculating;
  final DateTime? lastUpdated;
  final int maxLimitMb;

  const CacheStats({
    this.streamBytes = 0,
    this.imageBytes = 0,
    this.metaBytes = 0,
    this.downloadBytes = 0,
    this.albumBytes = 0,
    this.artistBytes = 0,
    this.searchBytes = 0,
    this.isCalculating = false,
    this.lastUpdated,
    this.maxLimitMb = 0,
  });

  int get totalBytes =>
      streamBytes + imageBytes + metaBytes + downloadBytes +
      albumBytes + artistBytes + searchBytes;

  int get limitPresetIndex {
    final index = limitPresets.indexOf(maxLimitMb);
    return index >= 0 ? index : limitPresets.length - 1;
  }

  double get sliderMax => (limitPresets.length - 1).toDouble();

  int get sliderDivisions => limitPresets.length - 1;

  String get maxLimitLabel => limitToLabel(maxLimitMb);

  int get maxLimitBytes => maxLimitMb <= 0 ? 0 : maxLimitMb * 1024 * 1024;

  bool get hasLimit => maxLimitMb > 0;

  CacheStats copyWith({
    int? streamBytes,
    int? imageBytes,
    int? metaBytes,
    int? downloadBytes,
    int? albumBytes,
    int? artistBytes,
    int? searchBytes,
    bool? isCalculating,
    DateTime? lastUpdated,
    int? maxLimitMb,
  }) {
    return CacheStats(
      streamBytes: streamBytes ?? this.streamBytes,
      imageBytes: imageBytes ?? this.imageBytes,
      metaBytes: metaBytes ?? this.metaBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      albumBytes: albumBytes ?? this.albumBytes,
      artistBytes: artistBytes ?? this.artistBytes,
      searchBytes: searchBytes ?? this.searchBytes,
      isCalculating: isCalculating ?? this.isCalculating,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      maxLimitMb: maxLimitMb ?? this.maxLimitMb,
    );
  }

  static int sliderValueToLimit(double value) {
    final index = value.round().clamp(0, limitPresets.length - 1);
    return limitPresets[index];
  }

  static String limitToLabel(int mb) {
    return switch (mb) {
      0 => '无限制',
      1024 => '1 GB',
      2048 => '2 GB',
      5120 => '5 GB',
      _ => '$mb MB',
    };
  }
}
```

- [ ] **Step 2: Run analyze on everything affected**

```bash
dart analyze lib/models/cache_stats.dart lib/providers/cache_provider.dart lib/screens/cache_management_screen.dart
```

Expected: No errors.  (If any call site uses positional args instead of named, fix them.)

- [ ] **Step 3: Commit**

```bash
git add lib/models/cache_stats.dart
git commit -m "feat: extend CacheStats with albumBytes, artistBytes, searchBytes"
```

---

### Task 11: Refactor CacheProvider to use CacheRepository

**Files:**
- Modify: `lib/providers/cache_provider.dart`

- [ ] **Step 1: Rewrite `CacheNotifier` and provider**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cache_stats.dart';
import '../services/cache_repository.dart';
import 'auth_provider.dart';
import 'library_provider.dart';

class CacheNotifier extends StateNotifier<CacheStats> {
  static const _limitKey = 'cache_max_limit_mb_v1';
  static const _autoCleanPrefix = 'cache_auto_clean_';
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
    state = state.copyWith(isCalculating: true);
    final stats = await _repo.getStats(maxLimitMb: state.maxLimitMb);
    state = stats;
    await _enforceIfNeeded();
  }

  Future<void> clearBucket(String id) async {
    await _repo.clearBucket(id);
    await refresh(force: true);
  }

  // ── Convenience aliases matching old API ──

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
    await _enforceIfNeeded();
  }

  void updateDownloadBytes(int bytes) {
    _downloadBytes = bytes;
  }

  // ── Auto-clean switch ──

  Future<bool> isAutoCleanEnabled(String bucketId) async {
    final raw = await _storage.read(key: '$_autoCleanPrefix$bucketId');
    // Default: stream & image ON, others OFF.
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

  Future<void> _loadAndRefresh() async {
    // Load limit.
    final raw = await _storage.read(key: _limitKey);
    final saved = int.tryParse(raw ?? '');
    if (saved != null && CacheStats.limitPresets.contains(saved)) {
      state = state.copyWith(maxLimitMb: saved);
    }
    // Load auto-clean switches.
    for (final b in _repo.buckets) {
      final enabled = await isAutoCleanEnabled(b.id);
      b.autoCleanEnabled = enabled;
    }
    await refresh(force: true);
  }

  Future<void> _enforceIfNeeded() async {
    if (!state.hasLimit) return;
    final current = state.totalBytes;
    if (current <= state.maxLimitBytes) return;
    await _repo.enforceAutoLimit(state.maxLimitBytes);
    // Recalculate after cleanup.
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

  // Keep download bytes in sync with CacheNotifier.
  ref.listen(downloadRecordsProvider, (_, next) {
    final records = next.valueOrNull;
    if (records == null) return;
    final bytes = records.fold<int>(0, (sum, r) => sum + r.size);
    notifier.updateDownloadBytes(bytes);
  });

  return notifier;
});
```

- [ ] **Step 2: Fix DownloadBucket to expose `_currentBytes`**

  In `download_cache_bucket.dart`, make the field public and update the setter:

```dart
  // Change _currentBytes → currentBytes (public), and the _sizeStream
  // listener updates it. The CacheRepository._dir exposure pattern
  // isn't needed here — just make currentBytes writable.
```

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/providers/cache_provider.dart lib/services/cache_repository.dart lib/services/buckets/download_cache_bucket.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/cache_provider.dart lib/services/buckets/download_cache_bucket.dart
git commit -m "refactor: CacheProvider now delegates to CacheRepository"
```

---

### Task 12: Refactor CacheManagementScreen UI

**Files:**
- Modify: `lib/screens/cache_management_screen.dart`

- [ ] **Step 1: Rewrite with 7 categories and auto-clean switches**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/cache_stats.dart';
import '../providers/cache_provider.dart';
import '../services/cache_repository.dart';
import '../widgets/donut_chart.dart';
import 'download_manager_screen.dart';

class CacheManagementScreen extends ConsumerStatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  ConsumerState<CacheManagementScreen> createState() =>
      _CacheManagementScreenState();
}

class _CacheManagementScreenState extends ConsumerState<CacheManagementScreen> {
  // 7 colors for 7 categories.
  static const _colors = [
    Color(0xFF1A1A1A), // stream
    Color(0xFF8A8A8E), // image
    Color(0xFFD1D1D6), // meta
    Color(0xFFE53935), // download
    Color(0xFF7C4DFF), // album
    Color(0xFFFF6D00), // artist
    Color(0xFF00C853), // search
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cacheProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(cacheProvider);
    final notifier = ref.read(cacheProvider.notifier);
    final repo = ref.read(cacheRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildOverviewCard(stats, repo),
            const SizedBox(height: AppTheme.spacingLG),
            _buildCategorySection(stats, notifier, repo),
            const SizedBox(height: AppTheme.spacingLG),
            _buildAutoCleanSection(stats, notifier, repo),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(CacheStats stats, CacheRepository repo) {
    final buckets = repo.buckets;
    final bytesList = [
      stats.streamBytes, stats.imageBytes, stats.metaBytes,
      stats.downloadBytes, stats.albumBytes, stats.artistBytes,
      stats.searchBytes,
    ];

    final segments = <DonutSegment>[];
    for (var i = 0; i < buckets.length; i++) {
      if (bytesList[i] > 0) {
        segments.add(DonutSegment(
          color: _colors[i],
          value: bytesList[i].toDouble(),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          DonutChart(
            segments: segments,
            centerText: stats.isCalculating && stats.lastUpdated == null
                ? '...'
                : _formatBytes(stats.totalBytes),
            centerSubtext: 'App 缓存',
            isLoading: stats.isCalculating && stats.lastUpdated == null,
          ),
          const SizedBox(height: 24),
          if (stats.isCalculating && stats.lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('正在更新...', style: context.textBodySmall),
                ],
              ),
            ),
          _buildLegend(stats, repo),
        ],
      ),
    );
  }

  Widget _buildLegend(CacheStats stats, CacheRepository repo) {
    final buckets = repo.buckets;
    final bytesList = [
      stats.streamBytes, stats.imageBytes, stats.metaBytes,
      stats.downloadBytes, stats.albumBytes, stats.artistBytes,
      stats.searchBytes,
    ];

    if (stats.totalBytes == 0 && !stats.isCalculating) {
      return Text('暂无缓存数据', style: context.textBodyMedium);
    }

    return Column(
      children: List.generate(buckets.length, (i) {
        return _LegendRow(
          label: buckets[i].label,
          bytes: bytesList[i],
          color: _colors[i],
          isLoading: stats.isCalculating,
        );
      }),
    );
  }

  Widget _buildCategorySection(
    CacheStats stats,
    CacheNotifier notifier,
    CacheRepository repo,
  ) {
    final buckets = repo.buckets;
    final bytesList = [
      stats.streamBytes, stats.imageBytes, stats.metaBytes,
      stats.downloadBytes, stats.albumBytes, stats.artistBytes,
      stats.searchBytes,
    ];

    final subtitles = const [
      '播放歌曲时产生的临时文件。清理后不会影响已下载的离线音乐。',
      '专辑封面和歌手头像。清理后再次浏览时会重新加载。',
      '歌词、歌手信息和曲库快照。遇到歌词或信息异常时可清理排查。',
      '已下载到本地的歌曲。请前往下载管理逐首删除，避免误删。',
      '专辑详情页的歌曲列表缓存。清理后进入专辑页会重新加载。',
      '艺人页的详情和歌曲缓存。清理后进入艺人页会重新加载。',
      '搜索历史和搜索结果缓存。清理后搜索记录和缓存结果会清空。',
    ];

    final icons = [
      Icons.music_note_rounded,
      Icons.image_rounded,
      Icons.description_rounded,
      Icons.download_done_rounded,
      Icons.album_rounded,
      Icons.person_rounded,
      Icons.search_rounded,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('分类清理', style: context.textTitleMedium),
        ),
        for (var i = 0; i < buckets.length; i++) ...[
          _CategoryTile(
            icon: icons[i],
            title: '${buckets[i].label}缓存',
            subtitle: subtitles[i],
            bytes: bytesList[i],
            isLoading: stats.isCalculating,
            buttonLabel: buckets[i].id == 'download' ? '查看管理' : '清理',
            onTap: buckets[i].id == 'download'
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DownloadManagerScreen(),
                      ),
                    );
                  }
                : bytesList[i] > 0
                    ? () => _clearWithFeedback(
                          () => notifier.clearBucket(buckets[i].id),
                          '${buckets[i].label}缓存已清理',
                        )
                    : null,
          ),
          if (i < buckets.length - 1)
            const SizedBox(height: AppTheme.spacingSM),
        ],
      ],
    );
  }

  Widget _buildAutoCleanSection(
    CacheStats stats,
    CacheNotifier notifier,
    CacheRepository repo,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自动清理', style: context.textTitleMedium),
          const SizedBox(height: 6),
          Text('设置总缓存上限，超出后自动按LRU删除最旧文件。', style: context.textBodyMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('当前上限', style: context.textBodySmall),
              Text(
                stats.maxLimitLabel,
                style: context.textBodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: stats.limitPresetIndex.toDouble(),
            min: 0,
            max: stats.sliderMax,
            divisions: stats.sliderDivisions,
            activeColor: context.primaryColor,
            inactiveColor: AppTheme.waveformUnplayed,
            onChanged: (value) {
              notifier.setMaxLimit(CacheStats.sliderValueToLimit(value));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('500 MB', style: context.textCaption),
              Text('1 GB', style: context.textCaption),
              Text('2 GB', style: context.textCaption),
              Text('5 GB', style: context.textCaption),
              Text('无限制', style: context.textCaption),
            ],
          ),
          const SizedBox(height: 20),
          Text('参与自动清理的类型', style: context.textTitleMedium),
          const SizedBox(height: 12),
          // Show switches for all buckets except 'download'.
          for (final b in repo.buckets.where((b) => b.id != 'download'))
            FutureBuilder<bool>(
              future: notifier.isAutoCleanEnabled(b.id),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.label, style: context.textBodyMedium),
                  value: enabled,
                  onChanged: (value) {
                    notifier.setAutoCleanEnabled(b.id, value);
                    setState(() {}); // Rebuild to reflect toggle.
                  },
                  activeColor: context.primaryColor,
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _clearWithFeedback(
    Future<void> Function() clearFn,
    String message,
  ) async {
    try {
      await clearFn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理失败：$error')),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

// ── Private widgets ──

class _LegendRow extends StatelessWidget {
  final String label;
  final int bytes;
  final Color color;
  final bool isLoading;

  const _LegendRow({
    required this.label,
    required this.bytes,
    required this.color,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: context.textBodyMedium)),
          Text(
            isLoading ? '...' : _formatBytes(bytes),
            style: context.textBodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (bytes >= 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int bytes;
  final bool isLoading;
  final String buttonLabel;
  final VoidCallback? onTap;

  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.isLoading,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: context.secondaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: context.textBodyLarge),
                    ),
                    Text(
                      isLoading ? '...' : _formatBytes(bytes),
                      style: context.textBodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: context.textCaption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onTap,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int b) {
    if (b >= 1024 * 1024 * 1024) return '${(b / (1 << 30)).toStringAsFixed(1)} GB';
    if (b >= 1024 * 1024) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze lib/screens/cache_management_screen.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/cache_management_screen.dart
git commit -m "feat: expand cache management UI to 7 categories with auto-clean switches"
```

---

### Task 13: Integrate cache-first loading into LibraryProvider (album songs)

**Files:**
- Modify: `lib/providers/library_provider.dart`

- [ ] **Step 1: Rewrite `fetchAlbumSongs` with cache-first strategy**

Replace the existing `fetchAlbumSongs` method:

```dart
  /// Fetches the tracklist for a specific album — cache-first.
  Future<void> fetchAlbumSongs(String albumId) async {
    if (_api == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Try disk cache first.
    final cachedSongs = await _cacheRepo.loadAlbumSongs(albumId);
    if (cachedSongs != null && mounted) {
      state = state.copyWith(albumSongs: cachedSongs, isLoading: false);
      // 2. Background refresh.
      unawaited(_fetchAlbumSongsFromNetwork(albumId));
      return;
    }

    // No cache — fetch from network directly.
    await _fetchAlbumSongsFromNetwork(albumId);
  }

  Future<void> _fetchAlbumSongsFromNetwork(String albumId) async {
    if (_api == null) return;
    try {
      final url = _api.getAlbumUrl(albumId);
      final response = await _dio.get(url);
      final data = response.data['subsonic-response'];
      if (data['status'] != 'ok') {
        throw Exception(data['error']?['message'] ?? 'Unknown API error');
      }
      final songList = data['album']?['song'] as List<dynamic>? ?? [];
      final songs = songList
          .map((json) => Song.fromJson(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        state = state.copyWith(albumSongs: songs, isLoading: false);
        // Persist to disk cache.
        unawaited(_cacheRepo.saveAlbumSongs(albumId, songs));
      }
    } catch (e) {
      if (mounted) {
        // Keep any existing albumSongs in state (could be from cache).
        state = state.copyWith(
          isLoading: false,
          error: state.albumSongs.isEmpty ? e.toString() : null,
        );
      }
    }
  }
```

**Note:** `LibraryNotifier` is a `StateNotifier` and doesn't have direct access to `ref`.  We need to restructure slightly: pass `CacheRepository` via constructor or make the provider access it.  The cleanest approach is to add `CacheRepository` as a constructor parameter to `LibraryNotifier`.

- [ ] **Step 2: Modify `LibraryNotifier` constructor to accept `CacheRepository`**

```dart
class LibraryNotifier extends StateNotifier<LibraryState> {
  final SubsonicApi? _api;
  final Dio _dio;
  final AppCacheService _cache;
  final CacheRepository _cacheRepo;
  final Map<String, ({DateTime savedAt, Map<String, dynamic> value})>
  _searchCache = {};
  Future<void>? _initialization;

  LibraryNotifier(this._api, this._dio, this._cache, this._cacheRepo)
    : super(const LibraryState());
  // ... rest of the class ...
}
```

- [ ] **Step 3: Update `libraryProvider` to inject `CacheRepository`**

```dart
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((
  ref,
) {
  final api = ref.watch(subsonicApiProvider);
  final dio = ref.watch(dioProvider);
  final cacheRepo = ref.watch(cacheRepositoryProvider);
  return LibraryNotifier(api, dio, AppCacheService.instance, cacheRepo);
});
```

- [ ] **Step 4: Add import in library_provider.dart**

```dart
import '../services/cache_repository.dart';
```

- [ ] **Step 5: Run analyze**

```bash
dart analyze lib/providers/library_provider.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/library_provider.dart
git commit -m "feat: album songs cache-first loading via CacheRepository"
```

---

### Task 14: Integrate cache-first loading into LibraryProvider (artist data)

**Files:**
- Modify: `lib/providers/library_provider.dart`

- [ ] **Step 1: Rewrite `fetchArtistDetail` with cache-first**

```dart
  Future<void> fetchArtistDetail(String artistId) async {
    if (_api == null) return;

    // Try disk cache first.
    final cached = await _cacheRepo.loadArtistDetail(artistId);
    if (cached != null && mounted) {
      _applyArtistDetailCache(cached);
      // Background network refresh.
      unawaited(_fetchArtistDetailFromNetwork(artistId));
      return;
    }

    await _fetchArtistDetailFromNetwork(artistId);
  }

  void _applyArtistDetailCache(Map<String, dynamic> json) {
    try {
      final artist = Artist.fromJson(
        Map<String, dynamic>.from(json['artist'] as Map),
      );
      final albumList = (json['albums'] as List<dynamic>? ?? [])
          .map((j) => Album.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      state = state.copyWith(
        artistDetail: artist,
        artistAlbums: albumList,
        isLoadingArtist: false,
      );
    } catch (_) {}
  }

  Future<void> _fetchArtistDetailFromNetwork(String artistId) async {
    state = state.copyWith(isLoadingArtist: true, clearArtistError: true);
    try {
      final artistResp = await _dio.get(_api.getArtistUrl(artistId));
      final artistData =
          artistResp.data['subsonic-response']['artist']
              as Map<String, dynamic>? ?? {};
      final artist = Artist.fromJson(artistData);
      final albumList = (artistData['album'] as List<dynamic>? ?? [])
          .map((json) => Album.fromJson(json as Map<String, dynamic>))
          .toList();

      String? avatarUrl;
      try {
        final infoResp = await _dio.get(_api.getArtistInfo2Url(artistId));
        final infoData =
            infoResp.data['subsonic-response']['artistInfo2']
                as Map<String, dynamic>? ?? {};
        avatarUrl = infoData['largeImageUrl'] as String? ??
            infoData['mediumImageUrl'] as String? ??
            infoData['smallImageUrl'] as String?;
      } catch (_) {}

      final artistWithAvatar = Artist(
        id: artist.id,
        name: artist.name,
        albumCount: artist.albumCount,
        avatarUrl: avatarUrl ?? artist.avatarUrl,
      );

      if (mounted) {
        state = state.copyWith(
          artistDetail: artistWithAvatar,
          artistAlbums: albumList,
          isLoadingArtist: false,
        );
        // Persist.
        unawaited(_cacheRepo.saveArtistDetail(artistId, {
          'artist': artistWithAvatar.toJson(),
          'albums': albumList.map((a) => a.toJson()).toList(),
        }));
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoadingArtist: false,
          artistError: state.artistDetail == null ? e.toString() : null,
        );
      }
    }
  }
```

- [ ] **Step 2: Rewrite `fetchArtistSongs` with cache-first**

```dart
  Future<void> fetchArtistSongs(String artistName) async {
    if (_api == null) return;

    final cached = await _cacheRepo.loadArtistSongs(artistName);
    if (cached != null && mounted) {
      state = state.copyWith(artistSongs: cached, isLoadingArtist: false);
      unawaited(_fetchArtistSongsFromNetwork(artistName));
      return;
    }

    await _fetchArtistSongsFromNetwork(artistName);
  }

  Future<void> _fetchArtistSongsFromNetwork(String artistName) async {
    state = state.copyWith(isLoadingArtist: true, clearArtistError: true);
    try {
      const pageSize = 500;
      var offset = 0;
      final songs = <Song>[];
      while (true) {
        final response = await _dio.get(
          _api.searchUrl(artistName, count: pageSize, offset: offset),
        );
        final data = response.data['subsonic-response'];
        if (data['status'] != 'ok') {
          throw Exception(data['error']?['message'] ?? 'Unknown API error');
        }
        final result = data['searchResult3'] ?? data['searchResult2'] ?? {};
        final page = result['song'] as List<dynamic>? ?? [];
        songs.addAll(
          page
              .map((json) => Song.fromJson(json as Map<String, dynamic>))
              .where((song) =>
                  song.artist.toLowerCase() == artistName.toLowerCase()),
        );
        if (page.length < pageSize) break;
        offset += pageSize;
      }

      if (mounted) {
        state = state.copyWith(artistSongs: songs, isLoadingArtist: false);
        unawaited(_cacheRepo.saveArtistSongs(artistName, songs));
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoadingArtist: false,
          artistError: state.artistSongs.isEmpty ? e.toString() : null,
        );
      }
    }
  }
```

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/providers/library_provider.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/library_provider.dart
git commit -m "feat: artist data cache-first loading via CacheRepository"
```

---

### Task 15: Integrate cache-first loading into SearchScreen

**Files:**
- Modify: `lib/screens/search_screen.dart`

**Interfaces:**
- Consumes: `cacheRepositoryProvider`, `CacheRepository`
- Produces: Search results cached to disk, history persisted to disk

- [ ] **Step 1: Rewrite `_search` method with cache-first**

Replace `_search` and related state in `_SearchScreenState`:

```dart
  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    final cacheRepo = ref.read(cacheRepositoryProvider);
    unawaited(cacheRepo.addToSearchHistory(query));

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    // 1. Try disk cache first.
    final cached = await cacheRepo.loadSearchResult(query);
    if (cached != null && mounted && query == _controller.text.trim()) {
      setState(() {
        _results = _deserializeSearchResult(cached);
        _isSearching = false;
      });
      return;
    }

    // 2. Fetch from network.
    final results = await ref.read(libraryProvider.notifier).search(query);
    if (!mounted || query != _controller.text.trim()) return;

    setState(() {
      _results = results;
      _isSearching = false;
    });

    // 3. Persist.
    unawaited(cacheRepo.saveSearchResult(query, _serializeResults(results)));
  }

  Map<String, dynamic> _serializeResults(Map<String, dynamic> results) {
    return {
      'artists': results['artists'],
      'albums': (results['albums'] as List<dynamic>? ?? [])
          .map((a) => (a as dynamic).toJson())
          .toList(),
      'songs': (results['songs'] as List<dynamic>? ?? [])
          .map((s) => (s as dynamic).toJson())
          .toList(),
    };
  }

  Map<String, dynamic> _deserializeSearchResult(Map<String, dynamic> json) {
    return {
      'artists': json['artists'] ?? [],
      'albums': (json['albums'] as List<dynamic>? ?? [])
          .map((j) => Album.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList(),
      'songs': (json['songs'] as List<dynamic>? ?? [])
          .map((j) => Song.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList(),
    };
  }
```

- [ ] **Step 2: Load search history from disk on init**

Add to `initState` or `build`:

```dart
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final cacheRepo = ref.read(cacheRepositoryProvider);
    final history = await cacheRepo.loadSearchHistory();
    if (history != null && mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  // Add field:
  List<String> _history = [];
```

- [ ] **Step 3: Update the history display section to use `_history` instead of `searchHistoryProvider`**

  In the build method, replace references to `searchHistoryProvider` with `_history`, and when a history item is used, persist:

```dart
  void _useHistory(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _search();
  }

  // On clear history:
  Future<void> _clearHistory() async {
    final cacheRepo = ref.read(cacheRepositoryProvider);
    await cacheRepo.saveSearchHistory([]);
    setState(() {
      _history = [];
    });
  }
```

- [ ] **Step 4: Add imports**

```dart
import '../services/cache_repository.dart';
```

- [ ] **Step 5: Run analyze**

```bash
dart analyze lib/screens/search_screen.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/search_screen.dart
git commit -m "feat: search cache-first loading with history persistence"
```

---

### Task 16: Write bucket unit tests

**Files:**
- Create: `test/cache_bucket_test.dart`

- [ ] **Step 1: Write tests for all bucket types**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/services/buckets/_file_utils.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('cache_bucket_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('calculateDirSizeSync', () {
    test('returns 0 for non-existent directory', () {
      expect(calculateDirSizeSync('${tmpDir.path}/nope'), 0);
    });

    test('returns 0 for empty directory', () {
      expect(calculateDirSizeSync(tmpDir.path), 0);
    });

    test('sums file sizes recursively', () {
      File('${tmpDir.path}/a.txt').writeAsStringSync('hello');      // 5
      File('${tmpDir.path}/b.txt').writeAsStringSync('world!');     // 6
      final sub = Directory('${tmpDir.path}/sub');
      sub.createSync();
      File('${sub.path}/c.txt').writeAsStringSync('test');          // 4
      expect(calculateDirSizeSync(tmpDir.path), 15);
    });
  });

  group('deleteContentsSync', () {
    test('does not throw on non-existent dir', () {
      deleteContentsSync('${tmpDir.path}/nope');
    });

    test('removes all children but keeps dir', () {
      File('${tmpDir.path}/a.txt').writeAsStringSync('data');
      Directory('${tmpDir.path}/sub').createSync();
      File('${tmpDir.path}/sub/b.txt').writeAsStringSync('data');
      deleteContentsSync(tmpDir.path);
      expect(Directory(tmpDir.path).existsSync(), isTrue);
      expect(Directory(tmpDir.path).listSync(), isEmpty);
    });
  });

  group('deleteContentsExcludingSync', () {
    test('skips excluded top-level dirs', () {
      File('${tmpDir.path}/keep.json').writeAsStringSync('data');
      final album = Directory('${tmpDir.path}/album');
      album.createSync();
      File('${album.path}/x.json').writeAsStringSync('data');

      deleteContentsExcludingSync(tmpDir.path, {'album'});

      expect(File('${tmpDir.path}/keep.json').existsSync(), isFalse);
      expect(Directory('${tmpDir.path}/album').existsSync(), isTrue);
      expect(File('${album.path}/x.json').existsSync(), isTrue);
    });
  });

  group('listFilesByModifiedSync', () {
    test('returns empty for empty dir', () {
      expect(listFilesByModifiedSync(tmpDir.path), isEmpty);
    });

    test('returns files sorted oldest-first', () {
      final a = File('${tmpDir.path}/a.txt')..writeAsStringSync('a');
      final b = File('${tmpDir.path}/b.txt')..writeAsStringSync('bb');
      // Touch a to be older.
      a.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
      b.setLastModifiedSync(DateTime.now());

      final files = listFilesByModifiedSync(tmpDir.path);
      expect(files.length, 2);
      expect(files[0].file.path, endsWith('a.txt'));
      expect(files[1].file.path, endsWith('b.txt'));
    });

    test('excludes specified subdirs', () {
      File('${tmpDir.path}/x.txt').writeAsStringSync('x');
      final excl = Directory('${tmpDir.path}/excluded');
      excl.createSync();
      File('${excl.path}/y.txt').writeAsStringSync('y');

      final files = listFilesByModifiedSync(
        tmpDir.path,
        excludeDirs: {'excluded'},
      );
      expect(files.length, 1);
      expect(files[0].file.path, endsWith('x.txt'));
    });
  });

  group('applyLruSync', () {
    test('no-op when under limit', () {
      File('${tmpDir.path}/a.txt').writeAsStringSync('hello'); // 5 bytes
      applyLruSync(tmpDir.path, 100);
      expect(File('${tmpDir.path}/a.txt').existsSync(), isTrue);
    });

    test('deletes oldest files to fit limit', () {
      final a = File('${tmpDir.path}/a.txt')..writeAsStringSync('aaaaa'); // 5
      final b = File('${tmpDir.path}/b.txt')..writeAsStringSync('bbbbb'); // 5
      final c = File('${tmpDir.path}/c.txt')..writeAsStringSync('ccccc'); // 5
      a.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 3)));
      b.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
      c.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

      applyLruSync(tmpDir.path, 11); // Need to remove at least 4 bytes → delete 5-byte file.

      expect(a.existsSync(), isFalse); // oldest → deleted
      expect(b.existsSync(), isTrue);
      expect(c.existsSync(), isTrue);
    });

    test('does not touch excluded dirs', () {
      final a = File('${tmpDir.path}/a.txt')..writeAsStringSync('x' * 100);
      final excl = Directory('${tmpDir.path}/excluded');
      excl.createSync();
      final b = File('${excl.path}/b.txt')..writeAsStringSync('y' * 100);
      a.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
      b.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

      applyLruSync(tmpDir.path, 50, excludeDirs: {'excluded'});

      // a.txt should be deleted (oldest eligible), excluded/b.txt untouched.
      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS
flutter test test/cache_bucket_test.dart
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/cache_bucket_test.dart
git commit -m "test: add unit tests for file utils used by all cache buckets"
```

---

### Task 17: Write CacheRepository unit tests

**Files:**
- Create: `test/cache_repository_test.dart`

- [ ] **Step 1: Write repository-level tests**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/services/cache_repository.dart';
import 'package:joyal_music/services/buckets/stream_cache_bucket.dart';
import 'package:joyal_music/services/buckets/image_cache_bucket.dart';
import 'package:joyal_music/services/buckets/meta_cache_bucket.dart';
import 'package:joyal_music/services/buckets/download_cache_bucket.dart';
import 'package:joyal_music/services/buckets/album_cache_bucket.dart';
import 'package:joyal_music/services/buckets/artist_cache_bucket.dart';
import 'package:joyal_music/services/buckets/search_cache_bucket.dart';

void main() {
  late CacheRepository repo;

  setUp(() {
    repo = CacheRepository(
      streamBucket: StreamBucket(),
      imageBucket: ImageBucket(),
      metaBucket: MetaBucket(),
      downloadBucket: DownloadBucket(Stream.value(0)),
      albumBucket: AlbumBucket(),
      artistBucket: ArtistBucket(),
      searchBucket: SearchBucket(),
    );
  });

  group('CacheRepository', () {
    test('has 7 buckets', () {
      expect(repo.buckets.length, 7);
    });

    test('bucket lookup by id', () {
      expect(repo.bucket('stream')!.id, 'stream');
      expect(repo.bucket('album')!.id, 'album');
      expect(repo.bucket('nonexistent'), isNull);
    });

    test('getStats returns all fields', () async {
      final stats = await repo.getStats(maxLimitMb: 1024);
      expect(stats.streamBytes, isA<int>());
      expect(stats.albumBytes, isA<int>());
      expect(stats.artistBytes, isA<int>());
      expect(stats.searchBytes, isA<int>());
      expect(stats.maxLimitMb, 1024);
      expect(stats.isCalculating, false);
      expect(stats.lastUpdated, isNotNull);
    });

    test('clearBucket does not throw for any id', () async {
      for (final b in repo.buckets) {
        await expectLater(repo.clearBucket(b.id), completes);
      }
    });

    test('enforceAutoLimit completes without error', () async {
      await expectLater(repo.enforceAutoLimit(1024 * 1024 * 1024), completes);
    });

    test('album save/load round-trip', () async {
      const albumId = 'test-album-1';
      await repo.albumBucket.save(albumId, {'title': 'Test Album', 'year': 2024});
      final loaded = await repo.albumBucket.load(albumId);
      expect(loaded, isNotNull);
      expect(loaded!['title'], 'Test Album');

      // Cleanup
      await repo.albumBucket.remove(albumId);
      expect(await repo.albumBucket.load(albumId), isNull);
    });

    test('artist save/load round-trip', () async {
      const artistId = 'test-artist-1';
      await repo.artistBucket.save(artistId, {'name': 'Test Artist'});
      final loaded = await repo.artistBucket.load(artistId);
      expect(loaded!['name'], 'Test Artist');

      await repo.artistBucket.remove(artistId);
      expect(await repo.artistBucket.load(artistId), isNull);
    });

    test('search history add/load', () async {
      await repo.searchBucket.addToHistory('hello');
      await repo.searchBucket.addToHistory('world');
      await repo.searchBucket.addToHistory('hello'); // dedup + move to front
      final history = await repo.searchBucket.loadHistory();
      expect(history, ['hello', 'world']);

      await repo.searchBucket.saveHistory([]);
      expect(await repo.searchBucket.loadHistory(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/cache_repository_test.dart
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/cache_repository_test.dart
git commit -m "test: add CacheRepository unit tests"
```

---

### Task 18: Write CacheProvider unit tests

**Files:**
- Create: `test/cache_provider_test.dart`

- [ ] **Step 1: Write provider-level tests**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/cache_stats.dart';
import 'package:joyal_music/providers/cache_provider.dart';
import 'package:joyal_music/services/cache_repository.dart';
import 'package:joyal_music/services/buckets/stream_cache_bucket.dart';
import 'package:joyal_music/services/buckets/image_cache_bucket.dart';
import 'package:joyal_music/services/buckets/meta_cache_bucket.dart';
import 'package:joyal_music/services/buckets/download_cache_bucket.dart';
import 'package:joyal_music/services/buckets/album_cache_bucket.dart';
import 'package:joyal_music/services/buckets/artist_cache_bucket.dart';
import 'package:joyal_music/services/buckets/search_cache_bucket.dart';

void main() {
  test('CacheStats totalBytes includes new fields', () {
    const stats = CacheStats(
      streamBytes: 100,
      imageBytes: 200,
      metaBytes: 50,
      downloadBytes: 300,
      albumBytes: 10,
      artistBytes: 20,
      searchBytes: 5,
    );
    expect(stats.totalBytes, 685);
  });

  test('CacheStats copyWith preserves new fields', () {
    const original = CacheStats(albumBytes: 42);
    final updated = original.copyWith(artistBytes: 99);
    expect(updated.albumBytes, 42);
    expect(updated.artistBytes, 99);
    expect(updated.searchBytes, 0);
  });

  test('CacheStats limit presets unchanged', () {
    expect(CacheStats.limitPresets, [500, 1024, 2048, 5120, 0]);
  });

  test('CacheNotifier can be created with repository', () {
    final repo = CacheRepository(
      streamBucket: StreamBucket(),
      imageBucket: ImageBucket(),
      metaBucket: MetaBucket(),
      downloadBucket: DownloadBucket(Stream.value(0)),
      albumBucket: AlbumBucket(),
      artistBucket: ArtistBucket(),
      searchBucket: SearchBucket(),
    );
    final notifier = CacheNotifier(
      repo: repo,
      storage: const FlutterSecureStorage(),
    );
    expect(notifier.state, isA<CacheStats>());
    notifier.dispose();
  });
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/cache_provider_test.dart
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/cache_provider_test.dart
git commit -m "test: add CacheProvider and CacheStats unit tests"
```

---

### Task 19: Write Widget test for CacheManagementScreen

**Files:**
- Create: `test/cache_management_screen_test.dart`

- [ ] **Step 1: Write widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/screens/cache_management_screen.dart';

void main() {
  testWidgets('renders 7 category tiles', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CacheManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should find labels for all 7 categories.
    expect(find.textContaining('临时音频'), findsOneWidget);
    expect(find.textContaining('图片封面'), findsOneWidget);
    expect(find.textContaining('歌词元数据'), findsOneWidget);
    expect(find.textContaining('离线下载'), findsOneWidget);
    expect(find.textContaining('专辑缓存'), findsOneWidget);
    expect(find.textContaining('艺人缓存'), findsOneWidget);
    expect(find.textContaining('搜索缓存'), findsOneWidget);

    // Auto-clean section.
    expect(find.text('自动清理'), findsOneWidget);
    expect(find.text('当前上限'), findsOneWidget);
    expect(find.text('参与自动清理的类型'), findsOneWidget);
  });

  testWidgets('donut chart renders', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CacheManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App 缓存'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/cache_management_screen_test.dart
```

Expected: Tests pass (may show "没有歌曲" if no real data — that's fine).

- [ ] **Step 3: Commit**

```bash
git add test/cache_management_screen_test.dart
git commit -m "test: add CacheManagementScreen widget test"
```

---

### Task 20: Full static analysis and test suite

**Files:**
- All modified files

- [ ] **Step 1: Run full static analysis**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS
dart analyze lib test
```

Expected: No errors.

- [ ] **Step 2: Run full test suite**

```bash
flutter test
```

Expected: All existing and new tests pass.

- [ ] **Step 3: Fix any failures**

  Address any failing tests.  Common issues:
  - `CacheStats` now requires new named params — ensure all call sites use named params.
  - `LibraryNotifier` constructor changed — update any test that constructs it.
  - Import paths need verification.

- [ ] **Step 4: Commit fixes if any**

```bash
git add -A
git commit -m "fix: resolve static analysis and test failures after cache refactor"
```

---

### Task 21: Build APK and verify

**Files:**
- Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

- [ ] **Step 1: Build arm64 release APK**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```

Expected: Build succeeds.

- [ ] **Step 2: Verify APK exists**

```bash
Test-Path build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Expected: `True`.

- [ ] **Step 3: Manual smoke test checklist** (install on device)

  1. Open cache management from sidebar → 7 categories visible
  2. Toggle auto-clean switches → they persist across page revisit
  3. Enter album detail → first time sees loading, second time instant from cache
  4. Enter artist page → same cache-first behavior
  5. Search "test" → results appear; search again → instant from cache
  6. Search history persists across page close/reopen
  7. Clear individual caches → size updates
  8. Set total limit to 500MB with all switches ON → verify LRU enforcement

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: finalize cache governance implementation"
```

---

### Task 22: Cleanup deprecated code

**Files:**
- Evaluate: `lib/services/cache_stats_service.dart` (can be removed or kept as thin wrapper)
- Evaluate: `lib/services/app_cache_service.dart` (lyrics_service still uses it — keep)

- [ ] **Step 1: Mark `CacheStatsService` as deprecated**

  If no other code references `CacheStatsService` directly, add `@Deprecated` annotation and point to `CacheRepository`.  If it's still used (e.g., by lyrics service), keep it but mark as internal.

```dart
@Deprecated('Use CacheRepository instead')
class CacheStatsService { ... }
```

- [ ] **Step 2: Verify no broken imports**

```bash
dart analyze lib test
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/cache_stats_service.dart
git commit -m "refactor: deprecate CacheStatsService in favor of CacheRepository"
```

- [ ] **Step 4: Final commit and summary**

```bash
git log --oneline -20
```
