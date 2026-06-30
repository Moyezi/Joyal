import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/cache_stats.dart';
import '../providers/cache_provider.dart';
import '../services/cache_repository.dart';
import '../utils/app_toast.dart';
import '../widgets/donut_chart.dart';
import 'download_manager_screen.dart';

class CacheManagementScreen extends ConsumerStatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  ConsumerState<CacheManagementScreen> createState() =>
      _CacheManagementScreenState();
}

class _CacheManagementScreenState extends ConsumerState<CacheManagementScreen> {
  static const _colors = [
    Color(0xFF1A1A1A), // stream
    Color(0xFF8A8A8E), // image
    Color(0xFFD1D1D6), // meta
    Color(0xFFE53935), // download
    Color(0xFF7C4DFF), // album
    Color(0xFFFF6D00), // artist
    Color(0xFF00C853), // search
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cacheProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(cacheProvider);
    final notifier = ref.read(cacheProvider.notifier);
    final repo = ref.read(cacheRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildOverviewCard(stats, repo),
            const SizedBox(height: AppTheme.spacingLG),
            _buildCategorySection(stats, notifier, repo),
            const SizedBox(height: AppTheme.spacingLG),
            _buildAutoCleanSection(stats, notifier, repo),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(CacheStats stats, CacheRepository repo) {
    final buckets = repo.buckets;
    final bytesList = [
      stats.streamBytes,
      stats.imageBytes,
      stats.metaBytes,
      stats.downloadBytes,
      stats.albumBytes,
      stats.artistBytes,
      stats.searchBytes,
    ];
    final segments = <DonutSegment>[];
    for (var i = 0; i < buckets.length; i++) {
      if (bytesList[i] > 0) {
        segments.add(
          DonutSegment(color: _colors[i], value: bytesList[i].toDouble()),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          DonutChart(
            segments: segments,
            centerText: stats.isCalculating && stats.lastUpdated == null
                ? '...'
                : _formatBytes(stats.totalBytes),
            centerSubtext: 'App 缓存',
            isLoading: stats.isCalculating && stats.lastUpdated == null,
          ),
          const SizedBox(height: 24),
          if (stats.isCalculating && stats.lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('正在更新...', style: context.textBodySmall),
                ],
              ),
            ),
          _buildLegend(stats, repo),
        ],
      ),
    );
  }

  Widget _buildLegend(CacheStats stats, CacheRepository repo) {
    final buckets = repo.buckets;
    final bytesList = [
      stats.streamBytes,
      stats.imageBytes,
      stats.metaBytes,
      stats.downloadBytes,
      stats.albumBytes,
      stats.artistBytes,
      stats.searchBytes,
    ];

    if (stats.totalBytes == 0 && !stats.isCalculating) {
      return Text('暂无缓存数据', style: context.textBodyMedium);
    }
    return Column(
      children: List.generate(buckets.length, (i) {
        return _LegendRow(
          label: buckets[i].label,
          bytes: bytesList[i],
          color: _colors[i],
          isLoading: stats.isCalculating,
        );
      }),
    );
  }

  Widget _buildCategorySection(
    CacheStats stats,
    CacheNotifier notifier,
    CacheRepository repo,
  ) {
    final buckets = repo.buckets;
    final bytesList = [
      stats.streamBytes,
      stats.imageBytes,
      stats.metaBytes,
      stats.downloadBytes,
      stats.albumBytes,
      stats.artistBytes,
      stats.searchBytes,
    ];
    final subtitles = const [
      '播放歌曲时产生的临时文件。清理后不会影响已下载的离线音乐。',
      '专辑封面和歌手头像。清理后再次浏览时会重新加载。',
      '歌词、歌手信息和曲库快照。遇到歌词或信息异常时可清理排查。',
      '已下载到本地的歌曲。请前往下载管理逐首删除，避免误删。',
      '专辑详情页的歌曲列表缓存。清理后进入专辑页会重新加载。',
      '艺人页的详情和歌曲缓存。清理后进入艺人页会重新加载。',
      '搜索历史和搜索结果缓存。清理后搜索记录和缓存结果会清空。',
    ];
    final icons = [
      Icons.music_note_rounded,
      Icons.image_rounded,
      Icons.description_rounded,
      Icons.download_done_rounded,
      Icons.album_rounded,
      Icons.person_rounded,
      Icons.search_rounded,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('分类清理', style: context.textTitleMedium),
        ),
        for (var i = 0; i < buckets.length; i++) ...[
          _CategoryTile(
            icon: icons[i],
            title: '${buckets[i].label}缓存',
            subtitle: subtitles[i],
            bytes: bytesList[i],
            isLoading: stats.isCalculating,
            buttonLabel: buckets[i].id == 'download' ? '查看管理' : '清理',
            onTap: buckets[i].id == 'download'
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DownloadManagerScreen(),
                      ),
                    );
                  }
                : bytesList[i] > 0
                ? () => _clearWithFeedback(
                    () => notifier.clearBucket(buckets[i].id),
                    '${buckets[i].label}缓存已清理',
                  )
                : null,
          ),
          if (i < buckets.length - 1)
            const SizedBox(height: AppTheme.spacingSM),
        ],
      ],
    );
  }

  Widget _buildAutoCleanSection(
    CacheStats stats,
    CacheNotifier notifier,
    CacheRepository repo,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自动清理', style: context.textTitleMedium),
          const SizedBox(height: 6),
          Text('设置总缓存上限，超出后自动按LRU删除最旧文件。', style: context.textBodyMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('当前上限', style: context.textBodySmall),
              Text(
                stats.maxLimitLabel,
                style: context.textBodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: stats.limitPresetIndex.toDouble(),
            min: 0,
            max: stats.sliderMax,
            divisions: stats.sliderDivisions,
            activeColor: context.primaryColor,
            inactiveColor: AppTheme.waveformUnplayed,
            onChanged: (value) {
              notifier.setMaxLimit(CacheStats.sliderValueToLimit(value));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('500 MB', style: context.textCaption),
              Text('1 GB', style: context.textCaption),
              Text('2 GB', style: context.textCaption),
              Text('5 GB', style: context.textCaption),
              Text('无限制', style: context.textCaption),
            ],
          ),
          const SizedBox(height: 20),
          Text('参与自动清理的类型', style: context.textTitleMedium),
          const SizedBox(height: 12),
          for (final b in repo.buckets.where((b) => b.id != 'download'))
            FutureBuilder<bool>(
              future: notifier.isAutoCleanEnabled(b.id),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.label, style: context.textBodyMedium),
                  value: enabled,
                  onChanged: (value) {
                    notifier.setAutoCleanEnabled(b.id, value);
                    setState(() {});
                  },
                  activeColor: context.primaryColor,
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _clearWithFeedback(
    Future<void> Function() clearFn,
    String message,
  ) async {
    try {
      await clearFn();
      if (!mounted) return;
      showAppToast(context, message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, '清理失败：$error');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int bytes;
  final Color color;
  final bool isLoading;

  const _LegendRow({
    required this.label,
    required this.bytes,
    required this.color,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: context.textBodyMedium)),
          Text(
            isLoading ? '...' : _formatBytes(bytes),
            style: context.textBodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int bytes;
  final bool isLoading;
  final String buttonLabel;
  final VoidCallback? onTap;

  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.isLoading,
    required this.buttonLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: context.primaryColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: context.textTitleMedium)),
              Text(
                isLoading ? '...' : _formatBytes(bytes),
                style: context.textBodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(subtitle, style: context.textBodySmall),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTap,
              icon: Icon(
                buttonLabel == '查看管理'
                    ? Icons.chevron_right_rounded
                    : Icons.delete_outline,
                size: 18,
              ),
              label: Text(buttonLabel),
              style: TextButton.styleFrom(
                foregroundColor: onTap == null
                    ? context.secondaryColor
                    : context.primaryColor,
                textStyle: context.textBodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}
