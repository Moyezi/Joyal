import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../providers/page_background_provider.dart';
import '../../providers/sidebar_image_provider.dart';
import '../cached_disk_image.dart';
import '../dynamic_album_background.dart';

class PageBackgroundTile extends StatelessWidget {
  final String? imagePath;
  final double blurSigma;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ValueChanged<double> onBlurChanged;

  const PageBackgroundTile({
    super.key,
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
                          ? Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              cacheWidth: physicalImageCacheWidth(context, 58),
                            )
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
                          hasImage ? '首页、曲库、发现共用此背景' : '从手机内部存储选择图片',
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

class SidebarImageTile extends StatelessWidget {
  final String? imagePath;
  final Alignment alignment;
  final VoidCallback onPick;
  final VoidCallback onCrop;
  final VoidCallback onClear;

  const SidebarImageTile({
    super.key,
    required this.imagePath,
    required this.alignment,
    required this.onPick,
    required this.onCrop,
    required this.onClear,
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
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: SizedBox(
                    width: 86,
                    height: 48,
                    child: hasImage
                        ? Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            alignment: alignment,
                            cacheWidth: physicalImageCacheWidth(context, 86),
                          )
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
                        '自定义图片',
                        style: context.textTitleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasImage ? '侧边栏会以 16:9 圆角图片显示' : '选择一张侧边栏展示图',
                        style: context.textBodySmall.copyWith(
                          color: context.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPick,
                    icon: Icon(
                      hasImage
                          ? Icons.image_search_outlined
                          : Icons.add_photo_alternate_outlined,
                    ),
                    label: Text(hasImage ? '更换图片' : '选择图片'),
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(width: AppTheme.spacingSM),
                  IconButton.filledTonal(
                    tooltip: '调整取景',
                    onPressed: onCrop,
                    icon: const Icon(Icons.crop_16_9_rounded),
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  IconButton(
                    tooltip: '清除侧边栏图片',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SidebarImageCropSheet extends ConsumerWidget {
  final VoidCallback onDone;

  const SidebarImageCropSheet({super.key, required this.onDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sidebarImageProvider);
    final path = state.imagePath;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '调整侧边栏图片',
                  style: context.textTitleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '完成',
                onPressed: onDone,
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '拖动图片，选择侧边栏 16:9 卡片里要展示的部分。',
            style: context.textBodySmall.copyWith(
              color: context.secondaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: path == null || path.isEmpty
                        ? null
                        : (details) {
                            ref
                                .read(sidebarImageProvider.notifier)
                                .updateAlignmentFromDrag(details.delta, size);
                          },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (path != null && path.isNotEmpty)
                          Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            alignment: Alignment(
                              state.alignmentX,
                              state.alignmentY,
                            ),
                            cacheWidth: physicalImageCacheWidth(
                              context,
                              constraints.maxWidth,
                              maxWidth: 2048,
                            ),
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                            ),
                            child: Icon(
                              Icons.image_outlined,
                              color: context.secondaryColor,
                            ),
                          ),
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.72),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onDone, child: const Text('保存取景')),
          ),
        ],
      ),
    );
  }
}

class PageBackgroundPreview extends ConsumerWidget {
  const PageBackgroundPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageBackgrounds = ref.watch(pageBackgroundProvider);
    final path = pageBackgrounds.imagePath;
    final hasImage = path != null && path.isNotEmpty;

    if (!hasImage) {
      return DynamicAlbumBackground(
        coverArtId: '',
        coverUrl: '',
        child: _PreviewLabel(title: '背景预览', subtitle: '选择图片后会应用到首页、曲库和发现'),
      );
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * pixelRatio)
        .ceil()
        .clamp(1, 2048)
        .toInt();
    final image = Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (pageBackgrounds.blurSigma > 0.05)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: pageBackgrounds.blurSigma,
              sigmaY: pageBackgrounds.blurSigma,
            ),
            child: image,
          )
        else
          image,
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
