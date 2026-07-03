import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/page_background_provider.dart';
import '../providers/visual_effect_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/dynamic_album_background.dart';

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
