import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../providers/visual_effect_provider.dart';

class CoverGlassBackgroundTile extends ConsumerWidget {
  const CoverGlassBackgroundTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(coverGlassBackgroundProvider);
    final notifier = ref.read(coverGlassBackgroundProvider.notifier);

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          children: [
            _BackgroundSlider(
              title: '模糊程度',
              icon: Icons.blur_on_rounded,
              value: settings.blurSigma,
              min: CoverGlassBackgroundState.minBlurSigma,
              max: CoverGlassBackgroundState.maxBlurSigma,
              divisions: 16,
              label: settings.blurSigma.toStringAsFixed(0),
              valueText: settings.blurSigma == 0
                  ? '关闭'
                  : settings.blurSigma.toStringAsFixed(0),
              onChanged: (value) =>
                  notifier.setBlurSigma(value, persist: false),
              onChangeEnd: (value) => notifier.setBlurSigma(value),
            ),
            _BackgroundSlider(
              title: '遮罩强度',
              icon: Icons.contrast_rounded,
              value: settings.overlayOpacity,
              min: CoverGlassBackgroundState.minOverlayOpacity,
              max: CoverGlassBackgroundState.maxOverlayOpacity,
              divisions: 17,
              label: '${(settings.overlayOpacity * 100).round()}%',
              valueText: '${(settings.overlayOpacity * 100).round()}%',
              onChanged: (value) =>
                  notifier.setOverlayOpacity(value, persist: false),
              onChangeEnd: (value) => notifier.setOverlayOpacity(value),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundSlider extends StatelessWidget {
  final String title;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final String valueText;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _BackgroundSlider({
    required this.title,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.valueText,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.spacingXS),
          child: Text(
            title,
            style: context.textBodySmall.copyWith(
              color: context.secondaryColor,
            ),
          ),
        ),
        Row(
          children: [
            Icon(icon, size: 20, color: context.secondaryColor),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: Slider(
                value: value.clamp(min, max).toDouble(),
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
        ),
      ],
    );
  }
}
