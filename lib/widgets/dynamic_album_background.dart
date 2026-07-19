import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../providers/visual_effect_provider.dart';
import 'album_visual_palette.dart';
import 'cached_blurred_background.dart';
import 'cached_disk_image.dart';

/// A softly animated background derived from cached album artwork.
class DynamicAlbumBackground extends ConsumerStatefulWidget {
  final String coverArtId;
  final String coverUrl;
  final String? coverCacheIdentity;
  final String? motionSeed;
  final bool motionEnabled;
  final Widget child;

  const DynamicAlbumBackground({
    super.key,
    required this.coverArtId,
    required this.coverUrl,
    this.coverCacheIdentity,
    this.motionSeed,
    this.motionEnabled = true,
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
  late _FlowingMotionProfile _motionProfile;
  late final AnimationController _motionController;
  late final _ThrottledRepaint _motionRepaint;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    );
    // The halos move very slowly, so the default 20 FPS remains smooth for a
    // 32-second cycle while cutting full-screen paint work. Personalization
    // can adjust this throttle without rebuilding the background every tick.
    _motionRepaint = _ThrottledRepaint(
      _motionController,
      framesPerSecond: FlowingHaloBackgroundState.defaultFrameRate,
    );
    _motionProfile = _FlowingMotionProfile.fromSeed(_motionSeed);
  }

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
    if (_motionSeed != _resolveMotionSeed(oldWidget)) {
      _motionProfile = _FlowingMotionProfile.fromSeed(_motionSeed);
    }
  }

  @override
  void dispose() {
    _motionRepaint.dispose();
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

  String get _motionSeed => _resolveMotionSeed(widget);

  String _resolveMotionSeed(DynamicAlbumBackground source) {
    final seed = source.motionSeed;
    if (seed != null && seed.isNotEmpty) return seed;
    return source.coverArtId;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final style = ref.watch(visualEffectProvider);
    final motionFrameRate = ref.watch(
      flowingHaloBackgroundProvider.select((state) => state.frameRate),
    );
    final coverGlassSettings = ref.watch(coverGlassBackgroundProvider);
    _motionRepaint.updateFrameRate(motionFrameRate);
    if (style == BackgroundVisualStyle.flowingHalo && widget.motionEnabled) {
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
              child: TweenAnimationBuilder<_FlowingMotionProfile>(
                tween: _FlowingMotionProfileTween(end: _motionProfile),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOutCubic,
                builder: (context, motionProfile, _) {
                  return _FlowingLightField(
                    palette: _palette,
                    scaffoldBg: scaffoldBg,
                    phaseAnimation: _motionController,
                    repaint: _motionRepaint,
                    motionProfile: motionProfile,
                  );
                },
              ),
            ),
          if (style == BackgroundVisualStyle.flowingHalo)
            const Positioned.fill(child: _FrostedLightVeil()),
          if (style == BackgroundVisualStyle.albumCoverGlass)
            Positioned.fill(
              child: _CoverGlassBackground(
                coverArtId: widget.coverArtId,
                coverUrl: widget.coverUrl,
                cacheIdentity: widget.coverCacheIdentity ?? widget.coverArtId,
                blurSigma: coverGlassSettings.blurSigma,
                overlayOpacity: coverGlassSettings.overlayOpacity,
                cacheWritesEnabled: !coverGlassSettings.isAdjustingBlur,
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _CoverGlassBackground extends StatelessWidget {
  // A blurred cover contains very little high-frequency detail. Rasterizing it
  // at full-screen resolution makes the GPU blur millions of pixels that are
  // immediately discarded by the blur. Keep the filter in a smaller local
  // coordinate space, then let the compositor scale the finished layer.
  static const double _rasterScale = 0.32;

  final String coverArtId;
  final String coverUrl;
  final String cacheIdentity;
  final double blurSigma;
  final double overlayOpacity;
  final bool cacheWritesEnabled;

  const _CoverGlassBackground({
    required this.coverArtId,
    required this.coverUrl,
    required this.cacheIdentity,
    required this.blurSigma,
    required this.overlayOpacity,
    required this.cacheWritesEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final veil = isDark ? Colors.black : Colors.white;
    final effectiveBlur = blurSigma
        .clamp(
          CoverGlassBackgroundState.minBlurSigma,
          CoverGlassBackgroundState.maxBlurSigma,
        )
        .toDouble();
    final effectiveOverlay = overlayOpacity
        .clamp(
          CoverGlassBackgroundState.minOverlayOpacity,
          CoverGlassBackgroundState.maxOverlayOpacity,
        )
        .toDouble();

    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final fullSize = constraints.biggest;
                final useReducedRaster = effectiveBlur > 0.05;
                final rasterScale = useReducedRaster ? _rasterScale : 1.0;
                final rasterSize = Size(
                  fullSize.width * rasterScale,
                  fullSize.height * rasterScale,
                );
                final cover = CachedDiskImage(
                  imageUrl: coverUrl,
                  cacheKey: coverArtId,
                  fit: BoxFit.cover,
                  decodeWidth: rasterSize.longestSide,
                  placeholderBuilder: (_) => const SizedBox.expand(),
                  errorBuilder: (context, error) => const SizedBox.expand(),
                  fadeInDuration: const Duration(milliseconds: 250),
                  fadeOutDuration: const Duration(milliseconds: 120),
                );
                final filteredCover = useReducedRaster
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: effectiveBlur * rasterScale,
                          sigmaY: effectiveBlur * rasterScale,
                        ),
                        child: cover,
                      )
                    : cover;
                final liveBackground = Center(
                  child: Transform.scale(
                    scale: 1 / rasterScale,
                    child: SizedBox.fromSize(
                      size: rasterSize,
                      child: filteredCover,
                    ),
                  ),
                );
                if (!useReducedRaster ||
                    coverArtId.isEmpty ||
                    coverUrl.isEmpty ||
                    cacheIdentity.isEmpty) {
                  return liveBackground;
                }
                return CachedBlurredBackground(
                  cacheIdentity: 'cover-glass:$cacheIdentity',
                  loadSourceFile: _loadCoverSource,
                  blurSigma: effectiveBlur,
                  rasterScale: _rasterScale,
                  cacheWritesEnabled: cacheWritesEnabled,
                  liveFallback: liveBackground,
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    veil.withValues(alpha: effectiveOverlay * 0.82),
                    veil.withValues(alpha: effectiveOverlay),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _loadCoverSource() async {
    final cacheManager = DefaultCacheManager();
    final cached = await cacheManager.getFileFromCache(coverArtId);
    if (cached?.file case final file? when await file.exists()) {
      return file;
    }
    if (coverUrl.isEmpty) return null;
    return cacheManager.getSingleFile(coverUrl, key: coverArtId);
  }
}

class _FlowingLightField extends StatelessWidget {
  final AlbumVisualPalette palette;
  final Color scaffoldBg;
  final Animation<double> phaseAnimation;
  final Listenable repaint;
  final _FlowingMotionProfile motionProfile;

  const _FlowingLightField({
    required this.palette,
    required this.scaffoldBg,
    required this.phaseAnimation,
    required this.repaint,
    required this.motionProfile,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
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
            phaseAnimation: phaseAnimation,
            repaint: repaint,
            motionProfile: motionProfile,
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

class _FlowingMotionProfile {
  final List<double> phaseOffsets;
  final List<Offset> centerOffsets;
  final List<double> amplitudeScales;
  final List<double> radiusScales;

  const _FlowingMotionProfile({
    required this.phaseOffsets,
    required this.centerOffsets,
    required this.amplitudeScales,
    required this.radiusScales,
  });

  factory _FlowingMotionProfile.fromSeed(String seed) {
    final random = math.Random(_stableHash(seed));
    return _FlowingMotionProfile(
      phaseOffsets: List<double>.generate(
        4,
        (_) => random.nextDouble() * math.pi * 2,
      ),
      centerOffsets: List<Offset>.generate(
        4,
        (_) => Offset(_range(random, -0.08, 0.08), _range(random, -0.07, 0.07)),
      ),
      amplitudeScales: List<double>.generate(
        4,
        (_) => _range(random, 0.86, 1.16),
      ),
      radiusScales: List<double>.generate(4, (_) => _range(random, 0.92, 1.10)),
    );
  }

  static _FlowingMotionProfile lerp(
    _FlowingMotionProfile a,
    _FlowingMotionProfile b,
    double t,
  ) {
    return _FlowingMotionProfile(
      phaseOffsets: List<double>.generate(
        4,
        (index) => _lerpAngle(a.phaseOffsets[index], b.phaseOffsets[index], t),
      ),
      centerOffsets: List<Offset>.generate(
        4,
        (index) =>
            Offset.lerp(a.centerOffsets[index], b.centerOffsets[index], t)!,
      ),
      amplitudeScales: List<double>.generate(
        4,
        (index) =>
            _lerpDouble(a.amplitudeScales[index], b.amplitudeScales[index], t),
      ),
      radiusScales: List<double>.generate(
        4,
        (index) => _lerpDouble(a.radiusScales[index], b.radiusScales[index], t),
      ),
    );
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    final source = value.isEmpty ? 'joyal-flowing-halo' : value;
    for (final unit in source.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static double _range(math.Random random, double min, double max) {
    return min + (max - min) * random.nextDouble();
  }

  static double _lerpAngle(double from, double to, double t) {
    final delta = ((to - from + math.pi * 3) % (math.pi * 2)) - math.pi;
    return from + delta * t;
  }

  static double _lerpDouble(double from, double to, double t) {
    return from + (to - from) * t;
  }
}

class _FlowingMotionProfileTween extends Tween<_FlowingMotionProfile> {
  _FlowingMotionProfileTween({required _FlowingMotionProfile end})
    : super(begin: end, end: end);

  @override
  _FlowingMotionProfile lerp(double t) {
    return _FlowingMotionProfile.lerp(begin!, end!, t);
  }
}

class _FlowingLightPainter extends CustomPainter {
  final Animation<double> phaseAnimation;
  final _FlowingMotionProfile motionProfile;
  final bool isDark;
  final Color warmHalo;
  final Color blueHalo;
  final Color violetHalo;
  final Color deepHalo;

  _FlowingLightPainter({
    required this.phaseAnimation,
    required Listenable repaint,
    required this.motionProfile,
    required this.isDark,
    required this.warmHalo,
    required this.blueHalo,
    required this.violetHalo,
    required this.deepHalo,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = phaseAnimation.value * math.pi * 2;
    final base = math.max(size.width, size.height);
    final breathing = 1 + 0.05 * math.sin(phase * 2);

    _paintBlob(
      canvas,
      size,
      color: violetHalo,
      center: Offset(
        0.04 +
            motionProfile.centerOffsets[0].dx +
            0.15 *
                motionProfile.amplitudeScales[0] *
                math.sin(phase + motionProfile.phaseOffsets[0]),
        0.72 +
            motionProfile.centerOffsets[0].dy +
            0.19 *
                motionProfile.amplitudeScales[0] *
                math.sin(
                  phase * 2 + math.pi / 2 + motionProfile.phaseOffsets[0],
                ),
      ),
      radius: base * 0.72 * breathing * motionProfile.radiusScales[0],
      opacity: isDark ? 0.52 : 0.36,
    );
    _paintBlob(
      canvas,
      size,
      color: blueHalo,
      center: Offset(
        0.48 +
            motionProfile.centerOffsets[1].dx +
            0.22 *
                motionProfile.amplitudeScales[1] *
                math.sin(phase + 1.1 + motionProfile.phaseOffsets[1]),
        -0.05 +
            motionProfile.centerOffsets[1].dy +
            0.11 *
                motionProfile.amplitudeScales[1] *
                math.cos(phase * 2 + motionProfile.phaseOffsets[1]),
      ),
      radius: base * 0.78 * (2 - breathing) * motionProfile.radiusScales[1],
      opacity: isDark ? 0.40 : 0.28,
    );
    _paintBlob(
      canvas,
      size,
      color: warmHalo,
      center: Offset(
        1.04 +
            motionProfile.centerOffsets[2].dx +
            0.14 *
                motionProfile.amplitudeScales[2] *
                math.cos(phase + 0.8 + motionProfile.phaseOffsets[2]),
        0.42 +
            motionProfile.centerOffsets[2].dy +
            0.18 *
                motionProfile.amplitudeScales[2] *
                math.sin(phase * 2 + 2.4 + motionProfile.phaseOffsets[2]),
      ),
      radius: base * 0.74 * motionProfile.radiusScales[2],
      opacity: isDark ? 0.38 : 0.26,
    );
    _paintBlob(
      canvas,
      size,
      color: deepHalo,
      center: Offset(
        0.82 +
            motionProfile.centerOffsets[3].dx +
            0.18 *
                motionProfile.amplitudeScales[3] *
                math.sin(phase + 2.8 + motionProfile.phaseOffsets[3]),
        0.94 +
            motionProfile.centerOffsets[3].dy +
            0.10 *
                motionProfile.amplitudeScales[3] *
                math.cos(phase * 2 + 1.4 + motionProfile.phaseOffsets[3]),
      ),
      radius: base * 0.62 * motionProfile.radiusScales[3],
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
    return phaseAnimation != oldDelegate.phaseAnimation ||
        motionProfile != oldDelegate.motionProfile ||
        isDark != oldDelegate.isDark ||
        warmHalo != oldDelegate.warmHalo ||
        blueHalo != oldDelegate.blueHalo ||
        violetHalo != oldDelegate.violetHalo ||
        deepHalo != oldDelegate.deepHalo;
  }
}

class _ThrottledRepaint extends ChangeNotifier {
  final Listenable source;
  int _minIntervalMicros;
  final Stopwatch _clock = Stopwatch()..start();
  int _lastNotificationMicros = -1;

  _ThrottledRepaint(this.source, {required int framesPerSecond})
    : _minIntervalMicros = _intervalFor(framesPerSecond) {
    source.addListener(_handleTick);
  }

  void updateFrameRate(int framesPerSecond) {
    _minIntervalMicros = _intervalFor(framesPerSecond);
  }

  static int _intervalFor(int framesPerSecond) {
    final safeFrameRate = framesPerSecond.clamp(
      FlowingHaloBackgroundState.minFrameRate,
      FlowingHaloBackgroundState.maxFrameRate,
    );
    return Duration.microsecondsPerSecond ~/ safeFrameRate;
  }

  void _handleTick() {
    final elapsed = _clock.elapsedMicroseconds;
    if (_lastNotificationMicros >= 0 &&
        elapsed - _lastNotificationMicros < _minIntervalMicros) {
      return;
    }
    _lastNotificationMicros = elapsed;
    notifyListeners();
  }

  @override
  void dispose() {
    source.removeListener(_handleTick);
    super.dispose();
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
