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
  });

  @override
  Widget build(BuildContext context) {
    final sigma = blurSigma.clamp(0.0, 30.0).toDouble();

    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: boxShadow),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: sigma > 0
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: const SizedBox.expand(),
                    )
                  : const SizedBox.expand(),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tintColor.withValues(alpha: tintOpacity),
                  border: Border.all(
                    color: borderColor.withValues(alpha: borderOpacity),
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
