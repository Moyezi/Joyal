import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../providers/glass_effect_provider.dart';
import '../frosted_glass.dart';

class LiquidGlassToggleTile extends ConsumerWidget {
  const LiquidGlassToggleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      glassEffectProvider.select((state) => state.liquidGlassEnabled),
    );

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: () => ref
            .read(glassEffectProvider.notifier)
            .setLiquidGlassEnabled(!enabled),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _LiquidGlassPreviewBackdrop(),
                      Padding(
                        padding: const EdgeInsets.all(7),
                        child: FrostedGlass(
                          blurSigma: 18,
                          borderRadius: BorderRadius.circular(13),
                          tintColor: context.surfaceColor,
                          tintOpacity: 0.36,
                          borderOpacity: 0,
                          liquidGlassEnabled: true,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 20,
                            color: context.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '液态玻璃',
                            style: context.textTitleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '实验',
                            style: context.textCaption.copyWith(
                              color: context.secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '使用 liquid_glass_easy 为玻璃组件加入实时折射',
                      style: context.textBodySmall.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Switch.adaptive(
                value: enabled,
                onChanged: (value) => ref
                    .read(glassEffectProvider.notifier)
                    .setLiquidGlassEnabled(value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassPreviewBackdrop extends StatelessWidget {
  const _LiquidGlassPreviewBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7E8A96),
            context.backgroundColor,
            const Color(0xFF3E6B78),
          ],
        ),
      ),
    );
  }
}
