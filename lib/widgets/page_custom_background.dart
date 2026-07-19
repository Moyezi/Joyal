import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/page_background_provider.dart';
import 'cached_blurred_background.dart';

class PageCustomBackground extends ConsumerWidget {
  // Strongly blurred full-screen images contain little useful high-frequency
  // detail. Blur them in a smaller local raster and scale the finished layer
  // back up so the filter touches substantially fewer pixels.
  static const double _reducedRasterScale = 0.36;
  static const double _reducedRasterBlurThreshold = 6;

  final PageBackgroundTarget? target;

  const PageCustomBackground({super.key, this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageBackground = ref.watch(pageBackgroundProvider);
    final path = pageBackground.imagePath;
    final fallbackColor = Theme.of(context).scaffoldBackgroundColor;
    if (path == null || path.isEmpty) {
      return ColoredBox(
        key: const ValueKey('main-shell-background'),
        color: fallbackColor,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blurSigma = pageBackground.blurSigma;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              key: const ValueKey('main-shell-background'),
              color: fallbackColor,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final fullSize = constraints.biggest;
                final shouldBlur = blurSigma > 0.05;
                final useReducedRaster =
                    blurSigma >= _reducedRasterBlurThreshold;
                final rasterScale = useReducedRaster
                    ? _reducedRasterScale
                    : 1.0;
                final rasterSize = Size(
                  fullSize.width * rasterScale,
                  fullSize.height * rasterScale,
                );
                final cacheWidth = (rasterSize.longestSide * pixelRatio * 1.08)
                    .ceil()
                    .clamp(1, 4096)
                    .toInt();
                final image = Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  width: rasterSize.width,
                  height: rasterSize.height,
                  cacheWidth: cacheWidth,
                );

                final liveBackground = Center(
                  child: Transform.scale(
                    scale: shouldBlur ? 1.04 / rasterScale : 1,
                    child: SizedBox.fromSize(
                      size: rasterSize,
                      child: ImageFiltered(
                        enabled: shouldBlur,
                        imageFilter: ImageFilter.blur(
                          sigmaX: blurSigma * rasterScale,
                          sigmaY: blurSigma * rasterScale,
                        ),
                        child: image,
                      ),
                    ),
                  ),
                );
                if (!useReducedRaster) return liveBackground;
                return CachedBlurredBackground(
                  cacheIdentity: 'shared-page-background:$path',
                  loadSourceFile: () async {
                    final file = File(path);
                    return await file.exists() ? file : null;
                  },
                  blurSigma: blurSigma,
                  rasterScale: _reducedRasterScale,
                  contentScale: 1.04,
                  cacheWritesEnabled: !pageBackground.isAdjustingBlur,
                  liveFallback: liveBackground,
                );
              },
            ),
            ColoredBox(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.54)
                  : Colors.black.withValues(alpha: 0.10),
            ),
          ],
        ),
      ),
    );
  }
}
