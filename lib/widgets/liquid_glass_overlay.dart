import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

class LiquidGlassOverlay extends StatelessWidget {
  final double intensity;
  final Alignment lightAlignment;
  final BorderRadius borderRadius;
  final Color tintColor;
  final double tintOpacity;
  final double blurSigma;
  final Color borderColor;
  final double borderOpacity;
  final bool ignorePointer;
  final Widget? child;

  const LiquidGlassOverlay({
    super.key,
    this.intensity = 1,
    this.lightAlignment = Alignment.topLeft,
    this.borderRadius = BorderRadius.zero,
    this.tintColor = Colors.white,
    this.tintOpacity = 0.18,
    this.blurSigma = 8,
    this.borderColor = Colors.white,
    this.borderOpacity = 0,
    this.ignorePointer = true,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final strength = intensity.clamp(0.0, 1.0).toDouble();
    if (strength <= 0.01) return child ?? const SizedBox.expand();

    final tintAlpha = tintOpacity.clamp(0.0, 1.0).toDouble();
    final strokeAlpha = borderOpacity.clamp(0.0, 1.0).toDouble();
    final radius = _cornerRadius(borderRadius);
    final lensChild = LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: radius,
          borderWidth: strokeAlpha <= 0 ? 0 : 0.8 + strokeAlpha * 0.8,
          borderColor: strokeAlpha <= 0
              ? Colors.transparent
              : borderColor.withValues(alpha: strokeAlpha),
          lightColor: Colors.white.withValues(alpha: 0.52 + 0.28 * strength),
          lightDirection: _lightDirection(lightAlignment),
          lightIntensity: strokeAlpha <= 0 ? 0.72 * strength : 1.05 * strength,
          borderType: OpticalBorder(
            ambientIntensity: 0.74 + strength * 0.72,
            borderSaturation: 1.0 + strength * 0.18,
          ),
        ),
        appearance: LiquidGlassAppearance(
          color: tintColor.withValues(alpha: tintAlpha),
          blur: LiquidGlassBlur(
            sigmaX: _liquidBlur(blurSigma, strength),
            sigmaY: _liquidBlur(blurSigma, strength),
          ),
          saturation: 1.0 + 0.08 * strength,
        ),
        refraction: LiquidGlassRefraction(
          refractionType: OpticalRefraction(
            refraction: 1.0 + 0.45 * strength,
            refractionWidth: 18 + 16 * strength,
            depth: 0.16 + 0.42 * strength,
          ),
          chromaticAberration: 0.0012 * strength,
          magnification: 1.0 + 0.018 * strength,
        ),
      ),
      child: child ?? const SizedBox.expand(),
    );

    if (!ignorePointer) return lensChild;
    return IgnorePointer(child: lensChild);
  }

  double _cornerRadius(BorderRadius radius) {
    return [
      radius.topLeft.x,
      radius.topRight.x,
      radius.bottomRight.x,
      radius.bottomLeft.x,
    ].reduce(math.max);
  }

  double _lightDirection(Alignment alignment) {
    if (alignment == Alignment.center) return 135;
    final angle = math.atan2(-alignment.y, alignment.x) * 180 / math.pi;
    return angle < 0 ? angle + 360 : angle;
  }

  double _liquidBlur(double sigma, double strength) {
    if (sigma <= 0.05) return 0;
    return (sigma * (0.22 + strength * 0.38)).clamp(0.0, 10.0).toDouble();
  }
}
