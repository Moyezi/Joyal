import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../utils/app_toast.dart';
import 'cache_management_screen.dart';
import 'download_manager_screen.dart';
import 'settings_screen.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: authState.isConnected
                        ? Colors.green.withValues(alpha: 0.1)
                        : context.secondaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    authState.isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: authState.isConnected
                        ? Colors.green
                        : context.secondaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.isConnected ? 'Navidrome 已连接' : '未连接服务器',
                        style: context.textTitleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authState.isConnected
                            ? authState.baseUrl ?? ''
                            : '点击右上角设置按钮配置连接',
                        style: context.textBodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.secondaryColor),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          Text('快捷操作', style: context.textTitleMedium),
          const SizedBox(height: AppTheme.spacingMD),
          _MenuItem(
            icon: Icons.cached_outlined,
            title: '刷新曲库',
            subtitle: '从服务器重新加载专辑列表',
            onTap: () {
              ref.read(libraryProvider.notifier).fetchAlbums();
              showAppToast(context, '正在刷新曲库');
            },
          ),
          _MenuItem(
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
          _MenuItem(
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
          _MenuItem(
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
          const SizedBox(height: AppTheme.spacingXL),
          if (!authState.isConnected)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange),
                  SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Text(
                      '请先连接 Navidrome 服务器以开始使用。\n'
                      '点击右上角设置图标进行配置',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, size: 20, color: context.primaryColor),
      ),
      title: Text(title, style: context.textBodyLarge),
      subtitle: Text(subtitle, style: context.textBodyMedium),
      trailing: Icon(Icons.chevron_right, color: context.secondaryColor),
      onTap: onTap,
    );
  }
}
