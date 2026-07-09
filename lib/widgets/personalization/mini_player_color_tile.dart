import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/mini_player_color_provider.dart';
import 'personalization_choice_tile.dart';

class MiniPlayerColorTile extends ConsumerWidget {
  const MiniPlayerColorTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(miniPlayerColorProvider);

    return Column(
      children: [
        PersonalizationChoiceTile(
          icon: Icons.dark_mode_outlined,
          title: MiniPlayerColorMode.defaultColor.label,
          subtitle: MiniPlayerColorMode.defaultColor.description,
          selected: selectedMode == MiniPlayerColorMode.defaultColor,
          onTap: () => ref
              .read(miniPlayerColorProvider.notifier)
              .setMode(MiniPlayerColorMode.defaultColor),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        PersonalizationChoiceTile(
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
