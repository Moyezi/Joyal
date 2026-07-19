import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/services/blurred_background_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reduced raster layout preserves aspect ratio under the size cap', () {
    const logicalSize = Size(1440, 3200);
    final layout = BlurredBackgroundCacheLayout.fromLogicalSize(
      logicalSize: logicalSize,
      devicePixelRatio: 3,
      rasterScale: 0.32,
      logicalBlurSigma: 18,
    );

    expect(layout.width, lessThanOrEqualTo(1536));
    expect(layout.height, lessThanOrEqualTo(1536));
    expect(layout.width / layout.height, closeTo(1440 / 3200, 0.002));
    expect(layout.blurSigma, greaterThan(0));
  });

  test('presentation key changes only with blur-affecting inputs', () {
    const first = BlurredBackgroundCacheLayout(
      width: 360,
      height: 800,
      blurSigma: 8,
    );
    const second = BlurredBackgroundCacheLayout(
      width: 360,
      height: 800,
      blurSigma: 9,
    );

    final key = first.presentationKey(
      stableIdentity: 'server|cover',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      contentScale: 1,
    );
    expect(
      first.presentationKey(
        stableIdentity: 'server|cover',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        contentScale: 1,
      ),
      key,
    );
    expect(
      second.presentationKey(
        stableIdentity: 'server|cover',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        contentScale: 1,
      ),
      isNot(key),
    );
    expect(
      first.presentationKey(
        stableIdentity: 'server|cover',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        contentScale: 1.04,
      ),
      isNot(key),
    );
  });

  test('cached content bounds match the live layer scale exactly', () {
    expect(
      blurredBackgroundContentBounds(const Size(100, 200), 1),
      const Rect.fromLTWH(0, 0, 100, 200),
    );
    expect(
      blurredBackgroundContentBounds(const Size(100, 200), 1.04),
      const Rect.fromLTWH(-2, -4, 104, 208),
    );
  });

  test('rendered cache is reused and invalidated by source version', () async {
    final root = await Directory.systemTemp.createTemp(
      'joyal_blur_cache_test_',
    );
    addTearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (await root.exists()) await root.delete(recursive: true);
    });
    final source = File('${root.path}${Platform.pathSeparator}source.png');
    await _writeSolidPng(source, Colors.blue);
    final cache = BlurredBackgroundCache(
      directoryResolver: () async =>
          Directory('${root.path}${Platform.pathSeparator}cache'),
    );
    const requestLayout = BlurredBackgroundCacheLayout(
      width: 64,
      height: 96,
      blurSigma: 4,
    );
    BlurredBackgroundCacheRequest request() => BlurredBackgroundCacheRequest(
      stableIdentity: 'test-source',
      loadSourceFile: () async => source,
      layout: requestLayout,
    );

    final first = await cache.resolve(request());
    final reused = await cache.resolve(request());
    expect(first, isNotNull);
    expect(await first!.exists(), isTrue);
    expect(reused?.path, first.path);
    await _expectImageSize(first, width: 64, height: 96);

    await _writeSolidPng(source, Colors.red);
    await source.setLastModified(
      DateTime.now().add(const Duration(seconds: 1)),
    );
    final changed = await cache.resolve(request());
    expect(changed, isNotNull);
    expect(changed!.path, isNot(first.path));
    expect(await changed.exists(), isTrue);
  });
}

Future<void> _writeSolidPng(File file, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 16, 16), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(16, 16);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  image.dispose();
  picture.dispose();
}

Future<void> _expectImageSize(
  File file, {
  required int width,
  required int height,
}) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  expect(descriptor.width, width);
  expect(descriptor.height, height);
  descriptor.dispose();
  buffer.dispose();
}
