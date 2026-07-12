import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/download_service.dart';
import '../utils/app_toast.dart';
import '../widgets/album_cover.dart';

class DownloadManagerScreen extends ConsumerStatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  ConsumerState<DownloadManagerScreen> createState() =>
      _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends ConsumerState<DownloadManagerScreen> {
  bool _ready = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final service = ref.read(downloadServiceProvider);
      await service?.initialize();
      if (service != null) await _scan(service, showResult: false);
      if (mounted) setState(() => _ready = true);
    });
  }

  Future<void> _scan(DownloadService service, {bool showResult = true}) async {
    if (_scanning) return;
    if (mounted) setState(() => _scanning = true);
    try {
      final found = await service.scanPublicDownloads(
        ref.read(libraryProvider).songs,
      );
      if (showResult && mounted) {
        showAppToast(context, found > 0 ? '发现 $found 首本地歌曲' : '本地下载已是最新');
      }
    } catch (error) {
      if (mounted) showAppToast(context, '扫描失败：$error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _delete(DownloadService service, DownloadRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除下载'),
        content: Text('确定删除"${record.song.title}"的本地文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.delete(record);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, '删除失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(downloadServiceProvider);
    if (service == null || !_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('下载管理')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return StreamBuilder<List<DownloadRecord>>(
      stream: service.recordsStream,
      initialData: service.records,
      builder: (context, snapshot) {
        final records = snapshot.data ?? const [];
        final totalBytes = records.fold<int>(0, (sum, item) => sum + item.size);
        return Scaffold(
          appBar: AppBar(
            title: const Text('下载管理'),
            actions: [
              IconButton(
                tooltip: '重新扫描本地音乐',
                onPressed: _scanning ? null : () => _scan(service),
                icon: _scanning
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: records.isEmpty
              ? const _EmptyDownloads()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppTheme.miniPlayerBg,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.surfaceColor
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.download_done_rounded,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.primaryColor
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${records.length} 首离线歌曲',
                                  style: context.textTitleLarge.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatBytes(totalBytes)} · 音乐/Joyal DL',
                                  style: context.textBodyMedium.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '播放全部下载',
                            onPressed: () => ref
                                .read(playerProvider.notifier)
                                .playPlaylist(
                                  records.map((item) => item.song).toList(),
                                ),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('已下载', style: context.textTitleLarge),
                    const SizedBox(height: 10),
                    ...records.asMap().entries.map((entry) {
                      final record = entry.value;
                      final api = ref.read(subsonicApiProvider);
                      final coverUrl =
                          api == null || record.song.coverArt.isEmpty
                          ? ''
                          : api.getCoverArtUrl(record.song.coverArt, size: 160);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playPlaylist(
                                records.map((item) => item.song).toList(),
                                startIndex: entry.key,
                              ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                AlbumCover(
                                  coverArtUrl: coverUrl,
                                  cacheKey: record.song.coverArt,
                                  size: 58,
                                  borderRadius: 16,
                                  showShadow: false,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.song.title,
                                        style: context.textTitleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${record.song.artist} · ${_formatBytes(record.size)}',
                                        style: context.textBodyMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: '删除本地文件',
                                  onPressed: () => _delete(service, record),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: context.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.download_for_offline_outlined,
                size: 40,
                color: context.secondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text('还没有下载歌曲', style: context.textTitleLarge),
            const SizedBox(height: 8),
            Text(
              '在曲库歌曲右侧的"…"菜单中选择下载，完成后可直接从本地播放。',
              style: context.textBodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
