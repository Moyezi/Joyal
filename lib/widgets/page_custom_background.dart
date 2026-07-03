import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/page_background_provider.dart';

class PageCustomBackground extends ConsumerWidget {
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
    final image = Image.file(
      File(path),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (blurSigma > 0)
          Transform.scale(
            scale: 1.04,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: image,
            ),
          )
        else
          image,
        ColoredBox(
          color: isDark
              ? Colors.black.withValues(alpha: 0.54)
              : Colors.white.withValues(alpha: 0.68),
        ),
      ],
    );
  }
}
