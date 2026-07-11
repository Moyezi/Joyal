import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../providers/visual_effect_provider.dart';

class FlowingHaloBackgroundTile extends ConsumerWidget {
  const FlowingHaloBackgroundTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(flowingHaloBackgroundProvider);
    final notifier = ref.read(flowingHaloBackgroundProvider.notifier);
    final frameRate = settings.frameRate;

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '流光动画帧率',
              style: context.textBodySmall.copyWith(
                color: context.secondaryColor,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.speed_rounded,
                  size: 20,
                  color: context.secondaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Slider(
                    value: frameRate.toDouble(),
                    min: FlowingHaloBackgroundState.minFrameRate.toDouble(),
                    max: FlowingHaloBackgroundState.maxFrameRate.toDouble(),
                    divisions: 11,
                    label: '$frameRate FPS',
                    onChanged: (value) =>
                        notifier.setFrameRate(value, persist: false),
                    onChangeEnd: notifier.setFrameRate,
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    '$frameRate FPS',
                    textAlign: TextAlign.end,
                    style: context.textBodySmall.copyWith(
                      color: context.secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '降低帧率可以进一步减少耗电和发热，拖动时会即时生效。',
              style: context.textBodySmall.copyWith(
                color: context.secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
