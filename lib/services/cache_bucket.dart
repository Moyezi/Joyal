import 'package:flutter/material.dart';

/// Unified interface for every cache bucket in the app.
abstract class CacheBucket {
  CacheBucket({this.autoCleanEnabled = true});

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
  DataCacheBucket({super.autoCleanEnabled});

  /// Read the cached value for [key], or null when not cached.
  Future<T?> load(String key);

  /// Persist [data] under [key], overwriting any previous value.
  Future<void> save(String key, T data);

  /// Remove the cached entry for [key].
  Future<void> remove(String key);

  /// List every key currently stored in this bucket.
  Future<List<String>> keys();
}
