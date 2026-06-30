import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/visual_effect_provider.dart';
import 'album_visual_palette.dart';

/// A softly animated background derived from cached album artwork.
class DynamicAlbumBackground extends ConsumerStatefulWidget {
  final String coverArtId;
  final String coverUrl;
  final Widget child;

  const DynamicAlbumBackground({
    super.key,
    required this.coverArtId,
    required this.coverUrl,
    required this.child,
  });

  @override
  ConsumerState<DynamicAlbumBackground> createState() =>
      _DynamicAlbumBackgroundState();
}

class _DynamicAlbumBackgroundState extends ConsumerState<DynamicAlbumBackground>
    with SingleTickerProviderStateMixin {
  late AlbumVisualPalette _palette;
  Brightness? _brightness;
  bool _paletteLoaded = false;
  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 32),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (!_paletteLoaded || _brightness != brightness) {
      _brightness = brightness;
      _palette = AlbumVisualPalette.fallbackFor(brightness);
      _loadPalette();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicAlbumBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Authenticated cover URLs contain a fresh salt on every build. The cover
    // id is the stable identity and prevents repeated palette work per tick.
    if (widget.coverArtId != oldWidget.coverArtId) {
      _loadPalette();
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _loadPalette() async {
    final brightness = Theme.of(context).brightness;
    final requestedId = widget.coverArtId;
    final palette = await AlbumVisualPalette.resolve(
      coverArtId: requestedId,
      coverUrl: widget.coverUrl,
      brightness: brightness,
    );
    if (!mounted || widget.coverArtId != requestedId) return;
    _paletteLoaded = true;
    setState(() => _palette = palette);
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final style = ref.watch(visualEffectProvider);
    if (style == BackgroundVisualStyle.flowingHalo) {
      if (!_motionController.isAnimating) _motionController.repeat();
    } else {
      _motionController.stop();
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_palette.top, _palette.bottom, scaffoldBg],
          stops: const [0, 0.56, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (style == BackgroundVisualStyle.flowingHalo)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _motionController,
                builder: (context, _) {
                  return _FlowingLightField(
                    palette: _palette,
                    scaffoldBg: scaffoldBg,
                    phase: _motionController.value,
                  );
                },
              ),
            ),
          if (style == BackgroundVisualStyle.flowingHalo)
            const Positioned.fill(child: _FrostedLightVeil()),
          widget.child,
        ],
      ),
    );
  }
}

class _FlowingLightField extends StatelessWidget {
  final AlbumVisualPalette palette;
  final Color scaffoldBg;
  final double phase;

  const _FlowingLightField({
    required this.palette,
    required this.scaffoldBg,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final p = phase * math.pi * 2;
    final sourceHue = HSLColor.fromColor(palette.waveformAccent).hue;
    final warmHalo = _haloColor(
      palette.top,
      brightness,
      targetHue: sourceHue + 18,
      saturationBoost: 1.36,
      lift: isDark ? 0.14 : -0.04,
    );
    final blueHalo = _haloColor(
      palette.bottom,
      brightness,
      targetHue: sourceHue + 108,
      saturationBoost: 1.28,
      lift: isDark ? 0.12 : -0.08,
    );
    final violetHalo = _haloColor(
      palette.waveformAccent,
      brightness,
      targetHue: sourceHue + 232,
      saturationBoost: 1.42,
      lift: isDark ? 0.16 : -0.06,
    );
    final deepHalo = _haloColor(
      scaffoldBg,
      brightness,
      targetHue: sourceHue + 172,
      saturationBoost: 1.18,
      lift: isDark ? 0.06 : -0.10,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          size: size,
          painter: _FlowingLightPainter(
            phase: p,
            isDark: isDark,
            warmHalo: warmHalo,
            blueHalo: blueHalo,
            violetHalo: violetHalo,
            deepHalo: deepHalo,
          ),
        );
      },
    );
  }

  Color _haloColor(
    Color color,
    Brightness brightness, {
    required double targetHue,
    required double saturationBoost,
    required double lift,
  }) {
    final hsl = HSLColor.fromColor(color);
    final normalizedHue = targetHue % 360;
    final blendedHue = _lerpHue(hsl.hue, normalizedHue, 0.42);
    final saturation = (hsl.saturation * saturationBoost)
        .clamp(brightness == Brightness.dark ? 0.34 : 0.24, 0.86)
        .toDouble();
    final lightness = (hsl.lightness + lift).clamp(
      brightness == Brightness.dark ? 0.16 : 0.38,
      brightness == Brightness.dark ? 0.62 : 0.78,
    );
    return hsl
        .withHue(blendedHue)
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor();
  }

  double _lerpHue(double from, double to, double t) {
    final delta = ((to - from + 540) % 360) - 180;
    return (from + delta * t) % 360;
  }
}

class _FlowingLightPainter extends CustomPainter {
  final double phase;
  final bool isDark;
  final Color warmHalo;
  final Color blueHalo;
  final Color violetHalo;
  final Color deepHalo;

  const _FlowingLightPainter({
    required this.phase,
    required this.isDark,
    required this.warmHalo,
    required this.blueHalo,
    required this.violetHalo,
    required this.deepHalo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final base = math.max(size.width, size.height);
    final breathing = 1 + 0.05 * math.sin(phase * 2);

    _paintBlob(
      canvas,
      size,
      color: violetHalo,
      center: Offset(
        0.04 + 0.15 * math.sin(phase),
        0.72 + 0.19 * math.sin(phase * 2 + math.pi / 2),
      ),
      radius: base * 0.72 * breathing,
      opacity: isDark ? 0.52 : 0.36,
    );
    _paintBlob(
      canvas,
      size,
      color: blueHalo,
      center: Offset(
        0.48 + 0.22 * math.sin(phase + 1.1),
        -0.05 + 0.11 * math.cos(phase * 2),
      ),
      radius: base * 0.78 * (2 - breathing),
      opacity: isDark ? 0.40 : 0.28,
    );
    _paintBlob(
      canvas,
      size,
      color: warmHalo,
      center: Offset(
        1.04 + 0.14 * math.cos(phase + 0.8),
        0.42 + 0.18 * math.sin(phase * 2 + 2.4),
      ),
      radius: base * 0.74,
      opacity: isDark ? 0.38 : 0.26,
    );
    _paintBlob(
      canvas,
      size,
      color: deepHalo,
      center: Offset(
        0.82 + 0.18 * math.sin(phase + 2.8),
        0.94 + 0.10 * math.cos(phase * 2 + 1.4),
      ),
      radius: base * 0.62,
      opacity: isDark ? 0.30 : 0.20,
    );
  }

  void _paintBlob(
    Canvas canvas,
    Size size, {
    required Color color,
    required Offset center,
    required double radius,
    required double opacity,
  }) {
    final absoluteCenter = Offset(
      size.width * center.dx,
      size.height * center.dy,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.10, -0.16),
        radius: 1,
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.34),
          color.withValues(alpha: opacity * 0.10),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.24, 0.64, 1],
      ).createShader(Rect.fromCircle(center: absoluteCenter, radius: radius));
    canvas.drawCircle(absoluteCenter, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _FlowingLightPainter oldDelegate) {
    return phase != oldDelegate.phase ||
        isDark != oldDelegate.isDark ||
        warmHalo != oldDelegate.warmHalo ||
        blueHalo != oldDelegate.blueHalo ||
        violetHalo != oldDelegate.violetHalo ||
        deepHalo != oldDelegate.deepHalo;
  }
}

class _FrostedLightVeil extends StatelessWidget {
  const _FrostedLightVeil();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white).withValues(
            alpha: isDark ? 0.30 : 0.24,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? Colors.white : Colors.black).withValues(
                alpha: isDark ? 0.025 : 0.018,
              ),
              Colors.transparent,
              (isDark ? Colors.black : Colors.white).withValues(
                alpha: isDark ? 0.28 : 0.34,
              ),
            ],
            stops: const [0, 0.46, 1],
          ),
        ),
      ),
    );
  }
}
