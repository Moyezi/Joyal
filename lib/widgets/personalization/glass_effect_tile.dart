import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../providers/glass_effect_provider.dart';
import '../../providers/mini_player_color_provider.dart';
import '../../providers/player_provider.dart';
import '../frosted_glass.dart';
import '../mini_player_chrome.dart';

class GlassEffectTile extends ConsumerStatefulWidget {
  const GlassEffectTile({super.key});

  @override
  ConsumerState<GlassEffectTile> createState() => _GlassEffectTileState();
}

class _GlassEffectTileState extends ConsumerState<GlassEffectTile> {
  GlassEffectTarget _selectedTarget = GlassEffectTarget.miniPlayer;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: GlassEffectTarget.values.indexOf(_selectedTarget),
      viewportFraction: 0.78,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glassState = ref.watch(glassEffectProvider);
    final blurSigma = _effectiveBlurFor(
      _selectedTarget,
      glassState.blurFor(_selectedTarget),
    );
    final tintOpacity = glassState.opacityFor(_selectedTarget);
    final blurMax = _blurSliderMaxFor(_selectedTarget);

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 156,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const _GlassPreviewOrbBackdrop(),
                    PageView.builder(
                      controller: _pageController,
                      clipBehavior: Clip.hardEdge,
                      itemCount: GlassEffectTarget.values.length,
                      onPageChanged: (index) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTarget = GlassEffectTarget.values[index];
                        });
                      },
                      itemBuilder: (context, index) {
                        final target = GlassEffectTarget.values[index];
                        final targetBlur = _effectiveBlurFor(
                          target,
                          glassState.blurFor(target),
                        );
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            final page = _pageController.hasClients
                                ? (_pageController.page ??
                                      _pageController.initialPage.toDouble())
                                : _pageController.initialPage.toDouble();
                            final distance = (page - index).abs().clamp(
                              0.0,
                              1.0,
                            );
                            final scale = 1 - distance * 0.08;
                            final verticalOffset = distance * 14;
                            final alignmentX = (page - index).clamp(-1.0, 1.0);
                            return Transform.translate(
                              offset: Offset(0, verticalOffset),
                              child: Transform.scale(
                                scale: scale,
                                child: _GlassPreview(
                                  target: target,
                                  blurSigma: targetBlur,
                                  tintOpacity: glassState.opacityFor(target),
                                  alignment: Alignment(alignmentX, 0),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              _selectedTarget.label,
              style: context.textTitleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            _GlassEffectSlider(
              icon: Icons.blur_on_rounded,
              value: blurSigma,
              min: 0,
              max: blurMax,
              divisions: _blurSliderDivisionsFor(_selectedTarget),
              label: blurSigma.toStringAsFixed(0),
              valueText: blurSigma == 0 ? '关闭' : blurSigma.toStringAsFixed(0),
              onChanged: (value) => ref
                  .read(glassEffectProvider.notifier)
                  .setBlur(_selectedTarget, value, persist: false),
              onChangeEnd: (value) => ref
                  .read(glassEffectProvider.notifier)
                  .setBlur(_selectedTarget, value),
            ),
            _GlassEffectSlider(
              icon: Icons.opacity_rounded,
              value: tintOpacity.clamp(0.0, 1.0).toDouble(),
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(tintOpacity * 100).round()}%',
              valueText: '${(tintOpacity * 100).round()}%',
              onChanged: (value) => ref
                  .read(glassEffectProvider.notifier)
                  .setOpacity(_selectedTarget, value, persist: false),
              onChangeEnd: (value) => ref
                  .read(glassEffectProvider.notifier)
                  .setOpacity(_selectedTarget, value),
            ),
          ],
        ),
      ),
    );
  }

  double _effectiveBlurFor(GlassEffectTarget target, double value) {
    return value.clamp(0.0, _blurSliderMaxFor(target)).toDouble();
  }

  double _blurSliderMaxFor(GlassEffectTarget target) {
    return target == GlassEffectTarget.lyricsPage ? 12 : 30;
  }

  int _blurSliderDivisionsFor(GlassEffectTarget target) {
    return target == GlassEffectTarget.lyricsPage ? 12 : 15;
  }
}

class _GlassEffectSlider extends StatelessWidget {
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final String valueText;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _GlassEffectSlider({
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.valueText,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.secondaryColor),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: context.textBodySmall.copyWith(
              color: context.secondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPreview extends ConsumerWidget {
  final GlassEffectTarget target;
  final double blurSigma;
  final double tintOpacity;
  final Alignment alignment;

  const _GlassPreview({
    required this.target,
    required this.blurSigma,
    required this.tintOpacity,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brightness = Theme.of(context).brightness;
    final miniPlayerColorMode = ref.watch(miniPlayerColorProvider);
    final song = ref.watch(playerProvider.select((state) => state.currentSong));
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = (api != null && song != null && song.coverArt.isNotEmpty)
        ? api.getCoverArtUrl(song.coverArt)
        : '';
    final coverSourceId = api == null ? '' : '${api.baseUrl}|${api.username}';
    final palette =
        miniPlayerColorMode == MiniPlayerColorMode.dynamicAlbum && song != null
        ? ref
              .watch(
                miniPlayerPaletteProvider(
                  MiniPlayerPaletteRequest(
                    coverArtId: song.coverArt,
                    coverSourceId: coverSourceId,
                    coverUrl: coverUrl,
                    brightness: brightness,
                  ),
                ),
              )
              .value
        : null;
    final previewChrome = MiniPlayerChrome.resolve(
      mode: miniPlayerColorMode,
      palette: palette,
      brightness: brightness,
    );
    final previewMiniTint =
        miniPlayerColorMode == MiniPlayerColorMode.dynamicAlbum
        ? previewChrome.tintColor
        : AppTheme.miniPlayerBg;
    final previewMiniAccent =
        miniPlayerColorMode == MiniPlayerColorMode.dynamicAlbum
        ? previewChrome.borderColor
        : Colors.white;
    final tintColor = switch (target) {
      GlassEffectTarget.miniPlayer => previewMiniTint,
      GlassEffectTarget.songCard => context.surfaceColor,
      _ => context.surfaceColor,
    };
    final radius = switch (target) {
      GlassEffectTarget.topBar => BorderRadius.circular(18),
      GlassEffectTarget.searchBar => BorderRadius.circular(18),
      GlassEffectTarget.bottomNav => BorderRadius.circular(34),
      GlassEffectTarget.nowPlayingControls => BorderRadius.circular(34),
      GlassEffectTarget.miniPlayer => BorderRadius.circular(44),
      GlassEffectTarget.songCard => BorderRadius.circular(18),
      GlassEffectTarget.lyricsPage => BorderRadius.circular(24),
      GlassEffectTarget.lyricsDrawer => BorderRadius.circular(28),
    };

    if (target == GlassEffectTarget.lyricsPage) {
      return SizedBox(
        height: 148,
        child: Align(
          alignment: alignment,
          child: SizedBox(
            width: _previewWidthFor(target),
            height: _previewHeightFor(target),
            child: _LyricsPageGlassPreview(
              blurSigma: blurSigma.clamp(0.0, 12.0).toDouble(),
              opacity: tintOpacity,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 148,
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: _previewWidthFor(target),
          height: _previewHeightFor(target),
          child: FrostedGlass(
            blurSigma: blurSigma,
            borderRadius: radius,
            tintColor: tintColor,
            tintOpacity: tintOpacity,
            borderColor: target == GlassEffectTarget.miniPlayer
                ? previewMiniAccent
                : context.primaryColor,
            borderOpacity: _previewBorderOpacity(target, isDark),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            child: _GlassPreviewContent(
              target: target,
              miniPlayerTint: previewMiniTint,
            ),
          ),
        ),
      ),
    );
  }

  double _previewWidthFor(GlassEffectTarget target) {
    return switch (target) {
      GlassEffectTarget.topBar => 280,
      GlassEffectTarget.miniPlayer => 304,
      GlassEffectTarget.searchBar => 280,
      GlassEffectTarget.bottomNav => 304,
      GlassEffectTarget.nowPlayingControls => 304,
      GlassEffectTarget.songCard => 304,
      GlassEffectTarget.lyricsPage => 304,
      GlassEffectTarget.lyricsDrawer => 304,
    };
  }

  double _previewHeightFor(GlassEffectTarget target) {
    return switch (target) {
      GlassEffectTarget.topBar => 54,
      GlassEffectTarget.miniPlayer => 76,
      GlassEffectTarget.searchBar => 54,
      GlassEffectTarget.bottomNav => 64,
      GlassEffectTarget.nowPlayingControls => 80,
      GlassEffectTarget.songCard => 68,
      GlassEffectTarget.lyricsPage => 112,
      GlassEffectTarget.lyricsDrawer => 112,
    };
  }

  double _previewBorderOpacity(GlassEffectTarget target, bool isDark) {
    if (target == GlassEffectTarget.searchBar ||
        target == GlassEffectTarget.bottomNav ||
        target == GlassEffectTarget.nowPlayingControls ||
        target == GlassEffectTarget.miniPlayer ||
        target == GlassEffectTarget.songCard) {
      return 0;
    }
    return isDark ? 0.08 : 0.06;
  }
}

class _LyricsPageGlassPreview extends StatelessWidget {
  final double blurSigma;
  final double opacity;

  const _LyricsPageGlassPreview({
    required this.blurSigma,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveOpacity = opacity.clamp(0.0, 1.0).toDouble();
    final inactiveColor = Color.lerp(
      context.secondaryColor,
      context.primaryColor,
      0.38,
    )!.withValues(alpha: inactiveOpacity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewLyricLine(
            text: '上一句慢慢退远',
            color: inactiveColor,
            blurSigma: blurSigma * 0.58,
          ),
          const SizedBox(height: 8),
          Text(
            '正在唱到这一句',
            style: context.textTitleMedium.copyWith(
              color: context.primaryColor,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _PreviewLyricLine(
            text: '下一句藏进雾里',
            color: inactiveColor,
            blurSigma: blurSigma,
          ),
        ],
      ),
    );
  }
}

class _PreviewLyricLine extends StatelessWidget {
  final String text;
  final Color color;
  final double blurSigma;

  const _PreviewLyricLine({
    required this.text,
    required this.color,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: context.textBodyMedium.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (blurSigma <= 0.05) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: child,
    );
  }
}

class _GlassPreviewOrbBackdrop extends StatelessWidget {
  const _GlassPreviewOrbBackdrop();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _GlassPreviewOrbPainter());
  }
}

class _GlassPreviewOrbPainter extends CustomPainter {
  const _GlassPreviewOrbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF26384A),
    );

    final topLeftCenter = Offset(size.width * 0.10, size.height * -0.08);
    final topLeftRadius = size.shortestSide * 0.96;
    final topLeftBounds = Rect.fromCircle(
      center: topLeftCenter,
      radius: topLeftRadius,
    );
    final topLeftPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.20, -0.24),
        radius: 1.05,
        colors: [Color(0xFFFF2D6D), Color(0xFFC61F4F)],
      ).createShader(topLeftBounds);
    canvas.drawCircle(topLeftCenter, topLeftRadius, topLeftPaint);

    final bottomRightCenter = Offset(size.width * 0.92, size.height * 1.18);
    final bottomRightRadius = size.shortestSide * 1.08;
    final bottomRightBounds = Rect.fromCircle(
      center: bottomRightCenter,
      radius: bottomRightRadius,
    );
    final bottomRightPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.45),
        radius: 1.12,
        colors: [Color(0xFF39A6A3), Color(0xFF1F6B6D)],
      ).createShader(bottomRightBounds);
    canvas.drawCircle(bottomRightCenter, bottomRightRadius, bottomRightPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassPreviewOrbPainter oldDelegate) => false;
}

class _GlassPreviewContent extends StatelessWidget {
  final GlassEffectTarget target;
  final Color miniPlayerTint;

  const _GlassPreviewContent({
    required this.target,
    required this.miniPlayerTint,
  });

  @override
  Widget build(BuildContext context) {
    return switch (target) {
      GlassEffectTarget.topBar => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '晚上好',
                style: context.textTitleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '继续享受你的音乐',
                style: context.textBodySmall.copyWith(
                  color: context.secondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      GlassEffectTarget.searchBar => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: context.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '搜索歌曲、专辑或艺人',
                style: context.textBodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: context.secondaryColor,
            ),
          ],
        ),
      ),
      GlassEffectTarget.bottomNav => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _PreviewNavItem(icon: Icons.home, label: '首页', active: true),
          _PreviewNavItem(icon: Icons.library_music_outlined, label: '曲库'),
          _PreviewNavItem(icon: Icons.explore_outlined, label: '发现'),
        ],
      ),
      GlassEffectTarget.nowPlayingControls => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(Icons.shuffle_rounded, size: 22),
            Icon(Icons.skip_previous_rounded, size: 30),
            _PreviewNowPlayingButton(),
            Icon(Icons.skip_next_rounded, size: 30),
            Icon(Icons.queue_music_rounded, size: 22),
          ],
        ),
      ),
      GlassEffectTarget.miniPlayer => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: const Icon(Icons.music_note, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '当前句歌词',
                style: context.textTitleMedium.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.play_arrow_rounded, color: miniPlayerTint),
            ),
          ],
        ),
      ),
      GlassEffectTarget.songCard => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在播放的歌曲',
                    style: context.textTitleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '首页、曲库、发现共用',
                    style: context.textBodySmall.copyWith(
                      color: context.secondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.more_horiz_rounded, color: context.secondaryColor),
          ],
        ),
      ),
      GlassEffectTarget.lyricsPage => const SizedBox.shrink(),
      GlassEffectTarget.lyricsDrawer => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '歌词个性化',
              style: context.textTitleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.palette_outlined, color: context.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.format_size_rounded, color: context.secondaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.64,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    };
  }
}

class _PreviewNowPlayingButton extends StatelessWidget {
  const _PreviewNowPlayingButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.pause_rounded,
        size: 30,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _PreviewNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _PreviewNavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? context.primaryColor
        : context.primaryColor.withValues(alpha: 0.45);
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
