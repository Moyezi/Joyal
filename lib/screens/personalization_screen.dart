import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/page_background_provider.dart';
import '../providers/sidebar_image_provider.dart';
import '../providers/visual_effect_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/personalization/glass_effect_tile.dart';
import '../widgets/personalization/liquid_glass_toggle_tile.dart';
import '../widgets/personalization/mini_player_color_tile.dart';
import '../widgets/personalization/cover_glass_background_tile.dart';
import '../widgets/personalization/flowing_halo_background_tile.dart';
import '../widgets/personalization/page_background_settings.dart';
import '../widgets/personalization/personalization_choice_tile.dart';

class PersonalizationScreen extends ConsumerWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(visualEffectProvider);
    final pageBackgrounds = ref.watch(pageBackgroundProvider);
    final sidebarImage = ref.watch(sidebarImageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('个性化')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          SizedBox(
            height: 168,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: const PageBackgroundPreview(),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text('页面背景', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          PageBackgroundTile(
            imagePath: pageBackgrounds.imagePath,
            blurSigma: pageBackgrounds.blurSigma,
            onPick: () => _pickPageBackground(context, ref),
            onClear: () => _clearPageBackground(context, ref),
            onBlurChanged: (value) =>
                ref.read(pageBackgroundProvider.notifier).setBlurSigma(value),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text('侧边栏图片', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          SidebarImageTile(
            imagePath: sidebarImage.imagePath,
            alignment: Alignment(
              sidebarImage.alignmentX,
              sidebarImage.alignmentY,
            ),
            onPick: () => _pickSidebarImage(context, ref),
            onCrop: () => _showSidebarImageCropSheet(context, ref),
            onClear: () => _clearSidebarImage(context, ref),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text('毛玻璃', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          const LiquidGlassToggleTile(),
          const SizedBox(height: AppTheme.spacingMD),
          const GlassEffectTile(),
          const SizedBox(height: AppTheme.spacingLG),
          Text('迷你播放栏', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          const MiniPlayerColorTile(),
          const SizedBox(height: AppTheme.spacingLG),
          Text('播放背景', style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          PersonalizationChoiceTile(
            icon: Icons.blur_on_rounded,
            title: '流动光影',
            subtitle: '根据封面取色生成柔和动态光晕',
            selected: style == BackgroundVisualStyle.flowingHalo,
            onTap: () => ref
                .read(visualEffectProvider.notifier)
                .setBackgroundStyle(BackgroundVisualStyle.flowingHalo),
          ),
          if (style == BackgroundVisualStyle.flowingHalo) ...[
            const SizedBox(height: AppTheme.spacingMD),
            const FlowingHaloBackgroundTile(),
          ],
          const SizedBox(height: AppTheme.spacingMD),
          PersonalizationChoiceTile(
            icon: Icons.gradient_rounded,
            title: '静态渐变',
            subtitle: '保留封面取色，关闭背景动效',
            selected: style == BackgroundVisualStyle.staticGradient,
            onTap: () => ref
                .read(visualEffectProvider.notifier)
                .setBackgroundStyle(BackgroundVisualStyle.staticGradient),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          PersonalizationChoiceTile(
            icon: Icons.album_rounded,
            title: '封面毛玻璃',
            subtitle: '将专辑封面模糊为播放详情和歌词页背景',
            selected: style == BackgroundVisualStyle.albumCoverGlass,
            onTap: () => ref
                .read(visualEffectProvider.notifier)
                .setBackgroundStyle(BackgroundVisualStyle.albumCoverGlass),
          ),
          if (style == BackgroundVisualStyle.albumCoverGlass) ...[
            const SizedBox(height: AppTheme.spacingMD),
            const CoverGlassBackgroundTile(),
          ],
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

  Future<void> _pickSidebarImage(BuildContext context, WidgetRef ref) async {
    try {
      final didPick = await ref.read(sidebarImageProvider.notifier).pick();
      if (!context.mounted || !didPick) return;
      showAppToast(context, '侧边栏图片已更新');
      await _showSidebarImageCropSheet(context, ref);
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(context, '图片选择失败');
    }
  }

  Future<void> _clearSidebarImage(BuildContext context, WidgetRef ref) async {
    await ref.read(sidebarImageProvider.notifier).clear();
    if (!context.mounted) return;
    showAppToast(context, '侧边栏图片已清除');
  }

  Future<void> _showSidebarImageCropSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final imagePath = ref.read(sidebarImageProvider).imagePath;
    if (imagePath == null || imagePath.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) =>
          SidebarImageCropSheet(onDone: () => Navigator.of(sheetContext).pop()),
    );
  }
}
