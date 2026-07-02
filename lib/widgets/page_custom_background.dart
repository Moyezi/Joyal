import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/page_background_provider.dart';

class PageCustomBackground extends ConsumerWidget {
  final PageBackgroundTarget target;

  const PageCustomBackground({super.key, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(
      pageBackgroundProvider.select((state) => state.pathFor(target)),
    );
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(path)),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.54)
              : Colors.white.withValues(alpha: 0.68),
        ),
      ),
    );
  }
}
