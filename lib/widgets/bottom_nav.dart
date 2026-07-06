import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/glass_effect_provider.dart';
import 'frosted_glass.dart';

class AppBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shadowAlpha = isDark ? 0.22 : 0.08;
    final blurSigma = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.bottomNav),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: FrostedGlass(
          blurSigma: blurSigma,
          borderRadius: BorderRadius.circular(34),
          tintColor: theme.scaffoldBackgroundColor,
          tintOpacity: isDark ? 0.76 : 0.68,
          borderColor: theme.colorScheme.onSurface,
          borderOpacity: isDark ? 0.08 : 0.06,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: '主页',
                  isActive: currentIndex == 0,
                  onTap: () => onTabChanged(0),
                ),
                _NavItem(
                  icon: Icons.library_music_outlined,
                  activeIcon: Icons.library_music,
                  label: '曲库',
                  isActive: currentIndex == 1,
                  onTap: () => onTabChanged(1),
                ),
                _NavItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: '发现',
                  isActive: currentIndex == 2,
                  onTap: () => onTabChanged(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 26, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
