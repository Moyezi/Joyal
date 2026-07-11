import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/glass_effect_provider.dart';
import 'liquid_glass_overlay.dart';

class FrostedGlass extends ConsumerWidget {
  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;
  final Color tintColor;
  final double tintOpacity;
  final Color borderColor;
  final double borderOpacity;
  final List<BoxShadow>? boxShadow;
  final bool useBackdropGroup;
  final bool? liquidGlassEnabled;

  /// Scales refraction while preserving the shared liquid-glass preference.
  final double liquidGlassIntensityScale;

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
    this.liquidGlassEnabled,
    this.liquidGlassIntensityScale = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sigma = blurSigma.clamp(0.0, 30.0).toDouble();
    final tintAlpha = tintOpacity.clamp(0.0, 1.0).toDouble();
    final strokeAlpha = borderOpacity.clamp(0.0, 1.0).toDouble();
    final liquidScale = liquidGlassIntensityScale.clamp(0.0, 1.0).toDouble();
    final shouldBlur = sigma > 0.05 && tintAlpha < 0.995;
    final bool liquidEnabled =
        liquidGlassEnabled ??
        ref.watch(
          glassEffectProvider.select((state) => state.liquidGlassEnabled),
        );
    final canApplyLiquid =
        liquidEnabled &&
        liquidScale > 0.01 &&
        tintAlpha < 0.96 &&
        (sigma > 0.05 || tintAlpha < 0.8);
    final liquidIntensity = canApplyLiquid
        ? ((1 - tintAlpha * 0.48) * (0.58 + sigma / 70))
                  .clamp(0.0, 1.0)
                  .toDouble() *
              liquidScale
        : 0.0;
    if (liquidIntensity > 0.01) {
      return DecoratedBox(
        decoration: BoxDecoration(boxShadow: boxShadow),
        child: LiquidGlassOverlay(
          intensity: liquidIntensity,
          borderRadius: borderRadius,
          tintColor: tintColor,
          tintOpacity: tintAlpha,
          blurSigma: sigma,
          borderColor: borderColor,
          borderOpacity: strokeAlpha,
          ignorePointer: false,
          child: child,
        ),
      );
    }

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
                  border: strokeAlpha <= 0
                      ? null
                      : Border.all(
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
