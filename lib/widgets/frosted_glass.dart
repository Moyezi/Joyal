import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;
  final Color tintColor;
  final double tintOpacity;
  final Color borderColor;
  final double borderOpacity;
  final List<BoxShadow>? boxShadow;
  final bool useBackdropGroup;

  const FrostedGlass({
    super.key,
    required this.child,
    required this.blurSigma,
    required this.borderRadius,
    required this.tintColor,
    this.tintOpacity = 0.62,
    this.borderColor = Colors.white,
    this.borderOpacity = 0.14,
    this.boxShadow,
    this.useBackdropGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final sigma = blurSigma.clamp(0.0, 30.0).toDouble();
    final tintAlpha = tintOpacity.clamp(0.0, 1.0).toDouble();
    final strokeAlpha = borderOpacity.clamp(0.0, 1.0).toDouble();
    final shouldBlur = sigma > 0.05 && tintAlpha < 0.995;
    final backdrop = shouldBlur
        ? (useBackdropGroup
              ? BackdropFilter.grouped(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                ))
        : const SizedBox.expand();

    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: boxShadow),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: backdrop),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tintColor.withValues(alpha: tintAlpha),
                  border: Border.all(
                    color: borderColor.withValues(alpha: strokeAlpha),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
