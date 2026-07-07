import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/listening_stats_provider.dart';
import '../providers/sidebar_image_provider.dart';
import '../providers/theme_provider.dart';

class HomeSidebar extends ConsumerWidget {
  final VoidCallback onSettingsTap;
  final VoidCallback onPersonalizationTap;

  const HomeSidebar({
    super.key,
    required this.onSettingsTap,
    required this.onPersonalizationTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final librarySongs = ref.watch(
      libraryProvider.select((state) => state.songs),
    );
    final listeningStats = ref.watch(listeningStatsProvider);
    final librarySongIds = librarySongs.map((song) => song.id).toSet();
    final heardSongCount = librarySongIds.isEmpty
        ? 0
        : listeningStats.heardSongIds
              .where((songId) => librarySongIds.contains(songId))
              .length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Joyal',
                            style: context.textHeadlineLarge,
                          ),
                        ),
                        if (authState.isConnected && !authState.isLoading)
                          Tooltip(
                            message: 'Navidrome 已连接',
                            child: Icon(
                              Icons.cloud_done_rounded,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('私人音乐空间', style: context.textBodyMedium),
                    if (authState.isLoading || !authState.isConnected) ...[
                      const SizedBox(height: 18),
                      _ConnectionStatus(
                        isLoading: authState.isLoading,
                        isConnected: authState.isConnected,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _ListeningOverviewCard(
                      heardSongCount: heardSongCount,
                      totalSongCount: librarySongs.length,
                    ),
                    const SizedBox(height: 16),
                    const _SidebarImagePanel(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '设置',
                  onPressed: onSettingsTap,
                  style: _sidebarBottomButtonStyle(context),
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: '个性化',
                  onPressed: onPersonalizationTap,
                  style: _sidebarBottomButtonStyle(context),
                  icon: const Icon(Icons.brush_outlined),
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

  const _ConnectionStatus({required this.isLoading, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final icon = isLoading
        ? Icons.cloud_sync_outlined
        : (isConnected ? Icons.cloud_done : Icons.cloud_off);
    final title = isLoading
        ? '正在恢复连接'
        : (isConnected ? 'Navidrome 已连接' : '未连接服务器');
    final subtitle = isLoading ? '请稍候' : (isConnected ? '已保存连接' : '前往设置配置连接');
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

class _ListeningOverviewCard extends StatelessWidget {
  final int heardSongCount;
  final int totalSongCount;

  const _ListeningOverviewCard({
    required this.heardSongCount,
    required this.totalSongCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSongCount == 0
        ? 0.0
        : (heardSongCount / totalSongCount).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFF0B8C7) : const Color(0xFFBE5D74);
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '听歌概览',
                  style: context.textTitleMedium.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.queue_music_rounded, color: accent, size: 22),
            ],
          ),
          const SizedBox(height: 4),
          Text('记录你的每一次播放', style: context.textBodySmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ListeningStat(
                  value: heardSongCount.toString(),
                  label: '已听曲目',
                  valueColor: accent,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: context.secondaryColor.withValues(alpha: 0.14),
              ),
              Expanded(
                child: _ListeningStat(
                  value: totalSongCount.toString(),
                  label: '全部曲目',
                  valueColor: context.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            totalSongCount == 0
                ? '曲库同步后开始记录'
                : '${(progress * 100).toStringAsFixed(0)}% 已听',
            style: context.textCaption,
          ),
        ],
      ),
    );
  }
}

class _ListeningStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _ListeningStat({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: context.textHeadlineMedium.copyWith(
              color: valueColor,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textCaption.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _SidebarImagePanel extends ConsumerWidget {
  const _SidebarImagePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sidebarImageProvider);
    final hasImage = state.imagePath != null && state.imagePath!.isNotEmpty;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: hasImage
            ? Image.file(
                File(state.imagePath!),
                fit: BoxFit.cover,
                alignment: Alignment(state.alignmentX, state.alignmentY),
                errorBuilder: (context, error, stackTrace) {
                  return _SidebarImagePlaceholder(
                    label: '图片读取失败',
                    icon: Icons.broken_image_outlined,
                  );
                },
              )
            : const _SidebarImagePlaceholder(
                label: '个性化中选择图片',
                icon: Icons.image_outlined,
              ),
      ),
    );
  }
}

class _SidebarImagePlaceholder extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SidebarImagePlaceholder({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: context.surfaceHighlightColor),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.secondaryColor, size: 26),
            const SizedBox(height: 8),
            Text(label, style: context.textCaption),
          ],
        ),
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
      style: _sidebarBottomButtonStyle(context),
      icon: Icon(icon),
    );
  }
}

ButtonStyle _sidebarBottomButtonStyle(BuildContext context) {
  return IconButton.styleFrom(
    backgroundColor: context.surfaceColor,
    foregroundColor: context.primaryColor,
    disabledBackgroundColor: context.surfaceColor.withValues(alpha: 0.58),
    disabledForegroundColor: context.primaryColor.withValues(alpha: 0.38),
  );
}
