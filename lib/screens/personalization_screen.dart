import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/visual_effect_provider.dart';
import '../widgets/dynamic_album_background.dart';

class PersonalizationScreen extends ConsumerWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(visualEffectProvider);
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
