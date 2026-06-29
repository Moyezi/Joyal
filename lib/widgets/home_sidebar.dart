import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class HomeSidebar extends ConsumerWidget {
  final VoidCallback onSettingsTap;

  const HomeSidebar({super.key, required this.onSettingsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Joyal', style: context.textHeadlineLarge),
            const SizedBox(height: 6),
            Text('私人音乐空间', style: context.textBodyMedium),
            const SizedBox(height: 18),
            _ConnectionStatus(
              isLoading: authState.isLoading,
              isConnected: authState.isConnected,
              baseUrl: authState.baseUrl,
            ),
            const SizedBox(height: 16),
            const _ReservedItem(title: '灵感入口'),
            const SizedBox(height: 12),
            const _ReservedItem(title: '最近动态'),
            const SizedBox(height: 12),
            const _ReservedItem(title: '个性化预留'),
            const Spacer(),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '设置',
                  onPressed: onSettingsTap,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 12),
                _ThemeModeButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final bool isLoading;
  final bool isConnected;
  final String? baseUrl;

  const _ConnectionStatus({
    required this.isLoading,
    required this.isConnected,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isLoading
        ? Icons.cloud_sync_outlined
        : (isConnected ? Icons.cloud_done : Icons.cloud_off);
    final title = isLoading
        ? '正在恢复连接'
        : (isConnected ? 'Navidrome 已连接' : '未连接服务器');
    final subtitle = isLoading
        ? '请稍候'
        : (isConnected
              ? ((baseUrl != null && baseUrl!.isNotEmpty) ? baseUrl! : '已保存连接')
              : '前往设置配置连接');
    final iconColor = isLoading
        ? context.secondaryColor
        : (isConnected ? Colors.green : context.secondaryColor);
    final titleColor = isLoading
        ? context.secondaryColor
        : (isConnected ? Colors.green : context.primaryColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTitleMedium.copyWith(color: titleColor),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.textBodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservedItem extends StatelessWidget {
  final String title;

  const _ReservedItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceHighlightColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.textTitleMedium)),
          const SizedBox(width: 12),
          Text('预留', style: context.textCaption),
        ],
      ),
    );
  }
}

class _ThemeModeButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final icon = switch (mode) {
      ThemeMode.light => Icons.sunny,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.system => Icons.brightness_auto,
    };
    final label = switch (mode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '自动',
    };

    return IconButton.filledTonal(
      tooltip: '主题模式 - $label',
      onPressed: () => ref.read(themeModeProvider.notifier).cycleMode(),
      icon: Icon(icon),
    );
  }
}
