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
/// directory itself. Never throws.
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
/// (oldest first). Each record carries size for LRU accounting.
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
