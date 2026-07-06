import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_toast.dart';
import 'cache_management_screen.dart';
import 'download_manager_screen.dart';
import 'music_classification_screen.dart';
import 'settings_screen.dart';

class SettingsHubScreen extends ConsumerStatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  ConsumerState<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends ConsumerState<SettingsHubScreen> {
  bool _isRefreshing = false;

  Future<void> _refreshLibrary() async {
    if (_isRefreshing) return;

    final authState = ref.read(authProvider);
    if (!authState.isConnected) {
      showAppToast(context, '请先连接服务器');
      return;
    }

    setState(() => _isRefreshing = true);
    showAppToast(context, '正在刷新曲库');

    Object? refreshError;
    try {
      await ref.read(libraryProvider.notifier).refreshLibrary();
    } catch (error) {
      refreshError = error;
    }

    if (!mounted) return;

    setState(() => _isRefreshing = false);
    if (refreshError != null) {
      showAppToast(context, '刷新失败: $refreshError');
      return;
    }

    final stateError = ref.read(libraryProvider).error;
    showAppToast(context, stateError == null ? '曲库已刷新' : '刷新失败: $stateError');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          _SettingsHubItem(
            icon: Icons.dns_outlined,
            title: '服务器连接',
            subtitle: '配置 Navidrome 地址、用户名和密码',
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _SettingsHubItem(
            icon: Icons.cached_outlined,
            title: '刷新曲库',
            subtitle: _isRefreshing ? '正在同步，请稍候' : '重新同步专辑、歌曲和收藏',
            onTap: _isRefreshing ? null : _refreshLibrary,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _SettingsHubItem(
            icon: Icons.auto_awesome_rounded,
            title: '智能分类',
            subtitle: '配置 DeepSeek，整理流派、情绪和场景标签',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MusicClassificationScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _SettingsHubItem(
            icon: Icons.download_for_offline_outlined,
            title: '下载管理',
            subtitle: '查看、播放和删除已下载音乐',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DownloadManagerScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _SettingsHubItem(
            icon: Icons.storage_rounded,
            title: '缓存管理',
            subtitle: '查看缓存占用、分类清理和自动清理策略',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CacheManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _SettingsHubItem(
            icon: Icons.info_outline,
            title: '关于 Joyal',
            subtitle: '版本 1.0.1',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Joyal',
                applicationVersion: '1.0.1',
                applicationLegalese: '© 2026 Joyal',
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeModeProvider);
              final subtitle = switch (mode) {
                ThemeMode.light => '浅色模式',
                ThemeMode.dark => '深色模式',
                ThemeMode.system => '跟随系统',
              };
              return _SettingsHubItem(
                icon: Icons.palette_outlined,
                title: '外观',
                subtitle: subtitle,
                onTap: () => ref.read(themeModeProvider.notifier).cycleMode(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsHubItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsHubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                      style: AppTheme.bodyLarge.copyWith(
                        color: context.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Icon(Icons.chevron_right, color: context.secondaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
