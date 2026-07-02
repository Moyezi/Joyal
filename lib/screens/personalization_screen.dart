import 'dart:io';

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
              child: DynamicAlbumBackground(
                coverArtId: '',
                coverUrl: '',
                child: Center(
                  child: Text(
                    '背景预览',
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
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text('页面背景', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          ...PageBackgroundTarget.values.map(
            (target) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
              child: _PageBackgroundTile(
                target: target,
                imagePath: pageBackgrounds.pathFor(target),
                onPick: () => _pickPageBackground(context, ref, target),
                onClear: () => _clearPageBackground(context, ref, target),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
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

  Future<void> _pickPageBackground(
    BuildContext context,
    WidgetRef ref,
    PageBackgroundTarget target,
  ) async {
    try {
      final didPick = await ref
          .read(pageBackgroundProvider.notifier)
          .pickFor(target);
      if (!context.mounted || !didPick) return;
      showAppToast(context, '${target.label}背景已更新');
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(context, '图片选择失败');
    }
  }

  Future<void> _clearPageBackground(
    BuildContext context,
    WidgetRef ref,
    PageBackgroundTarget target,
  ) async {
    await ref.read(pageBackgroundProvider.notifier).clear(target);
    if (!context.mounted) return;
    showAppToast(context, '${target.label}背景已清除');
  }
}

class _PageBackgroundTile extends StatelessWidget {
  final PageBackgroundTarget target;
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _PageBackgroundTile({
    required this.target,
    required this.imagePath,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final hasImage = path != null && path.isNotEmpty;

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
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
                      target.label,
                      style: context.textTitleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasImage ? '点击更换背景图片' : '从手机内部存储选择图片',
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
                  tooltip: '清除${target.label}背景',
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
