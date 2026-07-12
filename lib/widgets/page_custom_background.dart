import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/page_background_provider.dart';

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
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blurSigma = pageBackground.blurSigma;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
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

                return Center(
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
