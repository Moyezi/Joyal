import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/glass_effect_provider.dart';
import '../providers/mini_player_color_provider.dart';
import '../providers/page_background_provider.dart';
import '../providers/visual_effect_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/dynamic_album_background.dart';
import '../widgets/frosted_glass.dart';

class PersonalizationScreen extends ConsumerWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(visualEffectProvider);
    final pageBackgrounds = ref.watch(pageBackgroundProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('个性化')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          SizedBox(
            height: 168,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: const _PageBackgroundPreview(),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text('页面背景', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          _PageBackgroundTile(
            imagePath: pageBackgrounds.imagePath,
            blurSigma: pageBackgrounds.blurSigma,
            onPick: () => _pickPageBackground(context, ref),
            onClear: () => _clearPageBackground(context, ref),
            onBlurChanged: (value) =>
                ref.read(pageBackgroundProvider.notifier).setBlurSigma(value),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text('毛玻璃', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          const _GlassEffectTile(),
          const SizedBox(height: AppTheme.spacingLG),
          Text('迷你播放栏', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          const _MiniPlayerColorTile(),
          const SizedBox(height: AppTheme.spacingLG),
          Text('播放背景', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          _BackgroundStyleTile(
            icon: Icons.blur_on_rounded,
            title: '流动光影',
            subtitle: '根据封面取色生成柔和动态光晕',
            selected: style == BackgroundVisualStyle.flowingHalo,
            onTap: () => ref
                .read(visualEffectProvider.notifier)
                .setBackgroundStyle(BackgroundVisualStyle.flowingHalo),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _BackgroundStyleTile(
            icon: Icons.gradient_rounded,
            title: '静态渐变',
            subtitle: '保留封面取色，关闭背景动效',
            selected: style == BackgroundVisualStyle.staticGradient,
            onTap: () => ref
                .read(visualEffectProvider.notifier)
                .setBackgroundStyle(BackgroundVisualStyle.staticGradient),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPageBackground(BuildContext context, WidgetRef ref) async {
    try {
      final didPick = await ref.read(pageBackgroundProvider.notifier).pick();
      if (!context.mounted || !didPick) return;
      showAppToast(context, '页面背景已更新');
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(context, '图片选择失败');
    }
  }

  Future<void> _clearPageBackground(BuildContext context, WidgetRef ref) async {
    await ref.read(pageBackgroundProvider.notifier).clearShared();
    if (!context.mounted) return;
    showAppToast(context, '页面背景已清除');
  }
}

class _MiniPlayerColorTile extends ConsumerWidget {
  const _MiniPlayerColorTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(miniPlayerColorProvider);

    return Column(
      children: [
        _BackgroundStyleTile(
          icon: Icons.dark_mode_outlined,
          title: MiniPlayerColorMode.defaultColor.label,
          subtitle: MiniPlayerColorMode.defaultColor.description,
          selected: selectedMode == MiniPlayerColorMode.defaultColor,
          onTap: () => ref
              .read(miniPlayerColorProvider.notifier)
              .setMode(MiniPlayerColorMode.defaultColor),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _BackgroundStyleTile(
          icon: Icons.palette_outlined,
          title: MiniPlayerColorMode.dynamicAlbum.label,
          subtitle: MiniPlayerColorMode.dynamicAlbum.description,
          selected: selectedMode == MiniPlayerColorMode.dynamicAlbum,
          onTap: () => ref
              .read(miniPlayerColorProvider.notifier)
              .setMode(MiniPlayerColorMode.dynamicAlbum),
        ),
      ],
    );
  }
}

class _GlassEffectTile extends ConsumerStatefulWidget {
  const _GlassEffectTile();

  @override
  ConsumerState<_GlassEffectTile> createState() => _GlassEffectTileState();
}

class _GlassEffectTileState extends ConsumerState<_GlassEffectTile> {
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
    final blurSigma = glassState.blurFor(_selectedTarget);

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
                                  blurSigma: glassState.blurFor(target),
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
            Row(
              children: [
                Icon(
                  Icons.blur_on_rounded,
                  size: 20,
                  color: context.secondaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Slider(
                    value: blurSigma.clamp(0.0, 30.0).toDouble(),
                    min: 0,
                    max: 30,
                    divisions: 15,
                    label: blurSigma.toStringAsFixed(0),
                    onChanged: (value) => ref
                        .read(glassEffectProvider.notifier)
                        .setBlur(_selectedTarget, value),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    blurSigma == 0 ? '关闭' : blurSigma.toStringAsFixed(0),
                    textAlign: TextAlign.end,
                    style: context.textBodySmall.copyWith(
                      color: context.secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPreview extends StatelessWidget {
  final GlassEffectTarget target;
  final double blurSigma;
  final Alignment alignment;

  const _GlassPreview({
    required this.target,
    required this.blurSigma,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = switch (target) {
      GlassEffectTarget.miniPlayer => AppTheme.miniPlayerBg,
      GlassEffectTarget.songCard => context.surfaceColor,
      _ => context.surfaceColor,
    };
    final tintOpacity = switch (target) {
      GlassEffectTarget.miniPlayer => 0.78,
      GlassEffectTarget.topBar => isDark ? 0.72 : 0.62,
      GlassEffectTarget.searchBar => isDark ? 0.72 : 0.62,
      GlassEffectTarget.bottomNav => isDark ? 0.76 : 0.68,
      GlassEffectTarget.songCard => isDark ? 0.64 : 0.72,
    };
    final radius = switch (target) {
      GlassEffectTarget.topBar => BorderRadius.circular(18),
      GlassEffectTarget.searchBar => BorderRadius.circular(18),
      GlassEffectTarget.bottomNav => BorderRadius.circular(34),
      GlassEffectTarget.miniPlayer => BorderRadius.circular(44),
      GlassEffectTarget.songCard => BorderRadius.circular(18),
    };

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
                ? Colors.white
                : context.primaryColor,
            borderOpacity: isDark ? 0.08 : 0.06,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            child: _GlassPreviewContent(target: target),
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
      GlassEffectTarget.songCard => 304,
    };
  }

  double _previewHeightFor(GlassEffectTarget target) {
    return switch (target) {
      GlassEffectTarget.topBar => 54,
      GlassEffectTarget.miniPlayer => 76,
      GlassEffectTarget.searchBar => 54,
      GlassEffectTarget.bottomNav => 64,
      GlassEffectTarget.songCard => 68,
    };
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

  const _GlassPreviewContent({required this.target});

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
          _PreviewNavItem(
            icon: Icons.local_fire_department_outlined,
            label: '收藏',
          ),
        ],
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
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppTheme.miniPlayerBg,
              ),
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
                    '首页、曲库、收藏共用',
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
    };
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

class _PageBackgroundTile extends StatelessWidget {
  final String? imagePath;
  final double blurSigma;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ValueChanged<double> onBlurChanged;

  const _PageBackgroundTile({
    required this.imagePath,
    required this.blurSigma,
    required this.onPick,
    required this.onClear,
    required this.onBlurChanged,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final hasImage = path != null && path.isNotEmpty;

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          children: [
            InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: hasImage
                          ? Image.file(File(path), fit: BoxFit.cover)
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.backgroundColor,
                              ),
                              child: Icon(
                                Icons.image_outlined,
                                color: context.secondaryColor,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主页面背景',
                          style: context.textTitleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasImage ? '首页、曲库、收藏共用此背景' : '从手机内部存储选择图片',
                          style: context.textBodySmall.copyWith(
                            color: context.secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  if (hasImage)
                    IconButton(
                      tooltip: '清除页面背景',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    )
                  else
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: context.secondaryColor,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              children: [
                Icon(
                  Icons.blur_on_rounded,
                  size: 20,
                  color: context.secondaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Slider(
                    value: blurSigma.clamp(0.0, 24.0).toDouble(),
                    min: 0,
                    max: 24,
                    divisions: 12,
                    label: blurSigma.toStringAsFixed(0),
                    onChanged: onBlurChanged,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    blurSigma == 0 ? '关闭' : blurSigma.toStringAsFixed(0),
                    textAlign: TextAlign.end,
                    style: context.textBodySmall.copyWith(
                      color: context.secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBackgroundPreview extends ConsumerWidget {
  const _PageBackgroundPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageBackgrounds = ref.watch(pageBackgroundProvider);
    final path = pageBackgrounds.imagePath;
    final hasImage = path != null && path.isNotEmpty;

    if (!hasImage) {
      return DynamicAlbumBackground(
        coverArtId: '',
        coverUrl: '',
        child: _PreviewLabel(title: '背景预览', subtitle: '选择图片后会应用到首页、曲库和收藏'),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(path), fit: BoxFit.cover),
        if (pageBackgrounds.blurSigma > 0)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: pageBackgrounds.blurSigma,
                sigmaY: pageBackgrounds.blurSigma,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
          ),
          child: const _PreviewLabel(title: '主页面背景', subtitle: '毛玻璃顶栏会透出这张背景'),
        ),
      ],
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PreviewLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: context.textHeadlineMedium.copyWith(
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: context.textBodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              shadows: const [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(0, 1),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundStyleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundStyleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: AppTheme.spacingMD,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, size: 20, color: context.primaryColor),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textTitleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: context.textBodySmall.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? context.primaryColor : context.secondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
