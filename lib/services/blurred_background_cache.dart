import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

typedef BlurredBackgroundSourceLoader = Future<File?> Function();

@visibleForTesting
Rect blurredBackgroundContentBounds(Size outputSize, double contentScale) {
  final effectiveScale = contentScale.isFinite
      ? contentScale.clamp(0.5, 2.0).toDouble()
      : 1.0;
  final outputRect = Offset.zero & outputSize;
  return Rect.fromCenter(
    center: outputRect.center,
    width: outputSize.width * effectiveScale,
    height: outputSize.height * effectiveScale,
  );
}

@immutable
class BlurredBackgroundCacheLayout {
  static const int maxRasterSide = 1536;

  final int width;
  final int height;
  final double blurSigma;

  const BlurredBackgroundCacheLayout({
    required this.width,
    required this.height,
    required this.blurSigma,
  });

  factory BlurredBackgroundCacheLayout.fromLogicalSize({
    required Size logicalSize,
    required double devicePixelRatio,
    required double rasterScale,
    required double logicalBlurSigma,
  }) {
    final safePixelRatio = devicePixelRatio.isFinite
        ? devicePixelRatio.clamp(1.0, 4.0).toDouble()
        : 1.0;
    final safeRasterScale = rasterScale.isFinite
        ? rasterScale.clamp(0.1, 1.0).toDouble()
        : 1.0;
    var width = (logicalSize.width * safePixelRatio * safeRasterScale)
        .ceil()
        .clamp(1, 1 << 20)
        .toInt();
    var height = (logicalSize.height * safePixelRatio * safeRasterScale)
        .ceil()
        .clamp(1, 1 << 20)
        .toInt();

    final longestSide = width > height ? width : height;
    if (longestSide > maxRasterSide) {
      final scale = maxRasterSide / longestSide;
      width = (width * scale).round().clamp(1, maxRasterSide).toInt();
      height = (height * scale).round().clamp(1, maxRasterSide).toInt();
    }

    final effectiveScale = logicalSize.longestSide > 0
        ? (width > height ? width : height) /
              (logicalSize.longestSide * safePixelRatio)
        : safeRasterScale;
    final blurSigma = logicalBlurSigma.isFinite
        ? (logicalBlurSigma * safePixelRatio * effectiveScale)
              .clamp(0.0, 96.0)
              .toDouble()
        : 0.0;
    return BlurredBackgroundCacheLayout(
      width: width,
      height: height,
      blurSigma: blurSigma,
    );
  }

  String presentationKey({
    required String stableIdentity,
    required BoxFit fit,
    required Alignment alignment,
    double contentScale = 1,
  }) {
    return [
      BlurredBackgroundCache.schemaVersion,
      stableIdentity,
      '${width}x$height',
      blurSigma.toStringAsFixed(3),
      fit.name,
      alignment.x.toStringAsFixed(3),
      alignment.y.toStringAsFixed(3),
      contentScale.toStringAsFixed(3),
    ].join('|');
  }
}

@immutable
class BlurredBackgroundCacheRequest {
  final String stableIdentity;
  final BlurredBackgroundSourceLoader loadSourceFile;
  final BlurredBackgroundCacheLayout layout;
  final BoxFit fit;
  final Alignment alignment;
  final double contentScale;

  const BlurredBackgroundCacheRequest({
    required this.stableIdentity,
    required this.loadSourceFile,
    required this.layout,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.contentScale = 1,
  });

  double get effectiveContentScale =>
      contentScale.isFinite ? contentScale.clamp(0.5, 2.0).toDouble() : 1.0;

  String get presentationKey => layout.presentationKey(
    stableIdentity: stableIdentity,
    fit: fit,
    alignment: alignment,
    contentScale: effectiveContentScale,
  );
}

/// Stores expensive, full-screen self-image blur results as small PNG files.
///
/// Files live below flutter_cache_manager's image cache root, so existing image
/// cache statistics, manual cleanup, and global LRU enforcement include them.
class BlurredBackgroundCache {
  static const String schemaVersion = 'blurred-background-v2';
  static const int defaultMaxEntries = 24;
  static const int defaultMaxBytes = 32 * 1024 * 1024;

  static final BlurredBackgroundCache instance = BlurredBackgroundCache();

  final Future<Directory> Function() _directoryResolver;
  final int maxEntries;
  final int maxBytes;
  final Map<String, Future<File?>> _pending = {};
  bool _pruneScheduled = false;

  BlurredBackgroundCache({
    Future<Directory> Function()? directoryResolver,
    this.maxEntries = defaultMaxEntries,
    this.maxBytes = defaultMaxBytes,
  }) : _directoryResolver = directoryResolver ?? _defaultDirectory;

  Future<File?> resolve(BlurredBackgroundCacheRequest request) async {
    if (request.stableIdentity.isEmpty || request.layout.blurSigma <= 0.05) {
      return null;
    }

    try {
      final source = await request.loadSourceFile();
      if (source == null || !await source.exists()) return null;
      final stat = await source.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) return null;

      final sourceVersion = [
        stat.size,
        stat.modified.millisecondsSinceEpoch,
      ].join(':');
      final digest = sha256
          .convert(utf8.encode('${request.presentationKey}|$sourceVersion'))
          .toString();
      final pending = _pending[digest];
      if (pending != null) return pending;

      late final Future<File?> operation;
      operation = _resolveFile(digest: digest, source: source, request: request)
          .whenComplete(() {
            if (identical(_pending[digest], operation)) {
              _pending.remove(digest);
            }
          });
      _pending[digest] = operation;
      return operation;
    } catch (error) {
      debugPrint('[BlurredBackgroundCache] resolve failed: $error');
      return null;
    }
  }

  Future<File?> _resolveFile({
    required String digest,
    required File source,
    required BlurredBackgroundCacheRequest request,
  }) async {
    final directory = await _directoryResolver();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final destination = File(
      '${directory.path}${Platform.pathSeparator}$digest.png',
    );
    if (await destination.exists() && await destination.length() > 0) {
      unawaited(_touch(destination));
      return destination;
    }

    final generated = await _renderBlurredPng(
      source: source,
      destination: destination,
      request: request,
    );
    if (generated != null) _schedulePrune(directory);
    return generated;
  }

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {}
  }

  Future<File?> _renderBlurredPng({
    required File source,
    required File destination,
    required BlurredBackgroundCacheRequest request,
  }) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? sourceImage;
    ui.Picture? picture;
    ui.Image? renderedImage;
    File? temporary;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(source.path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final sourceSize = Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
      final outputSize = Size(
        request.layout.width.toDouble(),
        request.layout.height.toDouble(),
      );
      final contentSize = Size(
        outputSize.width * request.effectiveContentScale,
        outputSize.height * request.effectiveContentScale,
      );
      final decodeFit = applyBoxFit(request.fit, sourceSize, contentSize);
      final decodeScale =
          (decodeFit.destination.longestSide / decodeFit.source.longestSide)
              .clamp(0.01, 1.0)
              .toDouble();
      final decodeWidth = (descriptor.width * decodeScale)
          .round()
          .clamp(1, descriptor.width)
          .toInt();
      final decodeHeight = (descriptor.height * decodeScale)
          .round()
          .clamp(1, descriptor.height)
          .toInt();
      codec = await descriptor.instantiateCodec(
        targetWidth: decodeWidth,
        targetHeight: decodeHeight,
      );
      final frame = await codec.getNextFrame();
      sourceImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final outputRect = Offset.zero & outputSize;
      final destinationBounds = blurredBackgroundContentBounds(
        outputSize,
        request.effectiveContentScale,
      );
      final fitted = applyBoxFit(
        request.fit,
        Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        destinationBounds.size,
      );
      final sourceRect = request.alignment.inscribe(
        fitted.source,
        Rect.fromLTWH(
          0,
          0,
          sourceImage.width.toDouble(),
          sourceImage.height.toDouble(),
        ),
      );
      final destinationRect = request.alignment.inscribe(
        fitted.destination,
        destinationBounds,
      );
      canvas.clipRect(outputRect);
      canvas.drawImageRect(
        sourceImage,
        sourceRect,
        destinationRect,
        Paint()
          ..filterQuality = FilterQuality.low
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: request.layout.blurSigma,
            sigmaY: request.layout.blurSigma,
            tileMode: TileMode.clamp,
          ),
      );
      picture = recorder.endRecording();
      renderedImage = await picture.toImage(
        request.layout.width,
        request.layout.height,
      );
      final bytes = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (bytes == null) return null;

      temporary = File(
        '${destination.path}.tmp_${DateTime.now().microsecondsSinceEpoch}',
      );
      await temporary.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      return await temporary.rename(destination.path);
    } catch (error) {
      debugPrint('[BlurredBackgroundCache] generation failed: $error');
      try {
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      } catch (_) {}
      return null;
    } finally {
      renderedImage?.dispose();
      picture?.dispose();
      sourceImage?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  void _schedulePrune(Directory directory) {
    if (_pruneScheduled) return;
    _pruneScheduled = true;
    final directoryPath = directory.path;
    final entryLimit = maxEntries;
    final byteLimit = maxBytes;
    unawaited(() async {
      try {
        await _pruneDirectoryInIsolate(
          directoryPath,
          maxEntries: entryLimit,
          maxBytes: byteLimit,
        );
      } finally {
        _pruneScheduled = false;
      }
    }());
  }

  static Future<Directory> _defaultDirectory() async {
    final temporary = await getTemporaryDirectory();
    return Directory(
      '${temporary.path}${Platform.pathSeparator}libCachedImageData'
      '${Platform.pathSeparator}derived_blurred_backgrounds',
    );
  }
}

Future<void> _pruneDirectoryInIsolate(
  String directoryPath, {
  required int maxEntries,
  required int maxBytes,
}) {
  return Isolate.run(
    () => _pruneDirectorySync(
      directoryPath,
      maxEntries: maxEntries,
      maxBytes: maxBytes,
    ),
  );
}

void _pruneDirectorySync(
  String directoryPath, {
  required int maxEntries,
  required int maxBytes,
}) {
  try {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return;
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => !file.path.contains('.tmp_'))
            .map((file) {
              try {
                return (
                  file: file,
                  modified: file.lastModifiedSync(),
                  size: file.lengthSync(),
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<({File file, DateTime modified, int size})>()
            .toList()
          ..sort((a, b) => a.modified.compareTo(b.modified));

    var totalBytes = files.fold<int>(0, (sum, item) => sum + item.size);
    var remainingEntries = files.length;
    for (final item in files) {
      if (remainingEntries <= maxEntries && totalBytes <= maxBytes) break;
      try {
        item.file.deleteSync();
        totalBytes -= item.size;
        remainingEntries--;
      } catch (_) {}
    }
  } catch (_) {}
}
