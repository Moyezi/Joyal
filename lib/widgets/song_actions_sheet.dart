import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../config/theme_context.dart';
import '../models/music_classification.dart';
import '../models/song.dart';
import '../providers/music_classification_provider.dart';
import '../services/download_service.dart';
import '../utils/app_toast.dart';
import 'song_actions/song_detail_dialog.dart';

/// Signature for the actions available on a song.
typedef PlayNextCallback = void Function();
typedef ToggleFavoriteCallback = void Function();

/// A rounded bottom sheet that appears when the user taps "…" on a song tile.
///
/// Provides three actions:
/// - 下一首播放 (play next)
/// - 收藏 / 取消收藏 (toggle favorite)
/// - 下载 (download with inline progress bar + permission handling)
class SongActionsSheet extends ConsumerStatefulWidget {
  final String songTitle;
  final String songArtist;
  final bool isStarred;
  final PlayNextCallback? onPlayNext;
  final ToggleFavoriteCallback? onToggleFavorite;
  final DownloadService? downloadService;
  final String songId;
  final Song? song; // Full song metadata needed for download file naming.
  final BuildContext? hostContext;

  const SongActionsSheet({
    super.key,
    required this.songTitle,
    required this.songArtist,
    this.isStarred = false,
    this.onPlayNext,
    this.onToggleFavorite,
    this.downloadService,
    required this.songId,
    this.song,
    this.hostContext,
  });

  /// Shows the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String songTitle,
    required String songArtist,
    bool isStarred = false,
    PlayNextCallback? onPlayNext,
    ToggleFavoriteCallback? onToggleFavorite,
    DownloadService? downloadService,
    required String songId,
    Song? song,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SongActionsSheet(
        songTitle: songTitle,
        songArtist: songArtist,
        isStarred: isStarred,
        onPlayNext: onPlayNext,
        onToggleFavorite: onToggleFavorite,
        downloadService: downloadService,
        songId: songId,
        song: song,
        hostContext: context,
      ),
    );
  }

  @override
  ConsumerState<SongActionsSheet> createState() => _SongActionsSheetState();
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? context.primaryColor),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: context.textBodyLarge)),
          ],
        ),
      ),
    );
  }
}

class _SongActionsSheetState extends ConsumerState<SongActionsSheet> {
  StreamSubscription<DownloadProgress>? _downloadSub;
  DownloadProgress _progress = DownloadProgress(songId: '');
  bool _isDownloading = false;
  bool _downloadComplete = false;

  DownloadService? get _service => widget.downloadService;
  String get _songId => widget.songId;

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _startDownload(Song song) async {
    final service = _service;
    if (service == null) {
      _showSnack('请先连接服务器');
      return;
    }

    // ── Permission check ──
    final granted = await service.requestPermission();
    if (!granted) {
      _showSnack('需要存储权限才能下载音乐');
      unawaited(service.openSettings());
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadComplete = false;
      _progress = DownloadProgress(songId: _songId);
    });

    _downloadSub?.cancel();
    _downloadSub = service.progressStream
        .where((p) => p.songId == _songId)
        .listen(_onStreamProgress);

    try {
      await service.download(song);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      _showSnack('下载失败: ${_downloadErrorText(e)}');
      setState(() {
        _isDownloading = false;
        _downloadComplete = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('下载失败: $e');
      setState(() {
        _isDownloading = false;
        _downloadComplete = false;
      });
    }
  }

  void _onStreamProgress(DownloadProgress p) {
    if (!mounted) return;
    setState(() => _progress = p);
    if (p.error != null) {
      setState(() {
        _isDownloading = false;
        _downloadComplete = false;
      });
      return;
    }
    if (p.completed) {
      _showSnack('下载成功，已保存到“音乐/Joyal DL”');
      setState(() {
        _isDownloading = false;
        _downloadComplete = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _showSnack(String message) {
    showAppToast(context, message);
  }

  void _showSongDetails(SongClassification? classification, bool isLoading) {
    final dialogContext = widget.hostContext ?? context;
    final song = widget.song;
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero, () {
      if (!dialogContext.mounted) return;
      showDialog<void>(
        context: dialogContext,
        builder: (_) => SongDetailDialog(
          songTitle: widget.songTitle,
          songArtist: widget.songArtist,
          song: song,
          classification: classification,
          isClassificationLoading: isLoading,
        ),
      );
    });
  }

  String _downloadErrorText(DioException e) {
    return switch (e.type) {
      DioExceptionType.cancel => '已取消',
      DioExceptionType.connectionTimeout => '连接超时',
      DioExceptionType.receiveTimeout => '接收超时，文件可能较大',
      DioExceptionType.connectionError => '网络不可用',
      _ => e.message ?? '下载失败',
    };
  }

  @override
  Widget build(BuildContext context) {
    final classificationState = ref.watch(musicClassificationProvider);
    final classification = classificationState.classifications[widget.songId];
    final showProgress = _isDownloading || _downloadComplete;
    return Container(
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.secondaryColor.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.songTitle,
                          style: context.textTitleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.songArtist,
                          style: context.textBodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, indent: 24, endIndent: 24),
            const SizedBox(height: 8),

            _ActionTile(
              icon: Icons.skip_next_rounded,
              label: '下一首播放',
              onTap: () {
                widget.onPlayNext?.call();
                showAppToast(context, '已加入下一首播放');
                Navigator.of(context).pop();
              },
            ),
            _ActionTile(
              icon: widget.isStarred
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: widget.isStarred ? context.favoriteRedColor : null,
              label: widget.isStarred ? '取消收藏' : '收藏',
              onTap: () {
                Navigator.of(context).pop();
                widget.onToggleFavorite?.call();
              },
            ),
            _ActionTile(
              icon: Icons.info_outline_rounded,
              label: '查看详情',
              onTap: () {
                _showSongDetails(classification, classificationState.isLoading);
              },
            ),

            if (showProgress)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _downloadComplete
                              ? Icons.check_circle_rounded
                              : Icons.downloading_rounded,
                          size: 22,
                          color: _downloadComplete
                              ? Colors.green
                              : context.primaryColor,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _downloadComplete ? '下载完成' : '下载中…',
                            style: context.textBodyLarge,
                          ),
                        ),
                        if (!_downloadComplete)
                          Text(
                            '${(_progress.progress * 100).toStringAsFixed(0)}%',
                            style: context.textBodyMedium,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _progress.progress > 0 ? _progress.progress : null,
                      backgroundColor: context.surfaceColor,
                      color: _downloadComplete
                          ? Colors.green
                          : context.primaryColor,
                      minHeight: 3,
                    ),
                    if (!_downloadComplete && _progress.receivedBytes > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_formatDownloadBytes(_progress.receivedBytes)} / '
                        '${_formatDownloadBytes(_progress.totalBytes)}'
                        '${_progress.systemStatus == null ? '' : ' · ${_systemStatusText(_progress.systemStatus!)}'}'
                        '${_progress.systemReason == null || _progress.systemReason == 0 ? '' : '（${_systemReasonText(_progress.systemReason!)}）'}'
                        '${_progress.taskId == null ? '' : ' · #${_progress.taskId}'}',
                        style: context.textBodyMedium,
                      ),
                    ],
                  ],
                ),
              )
            else
              _ActionTile(
                icon: Icons.download_rounded,
                label: '下载',
                onTap: () {
                  final s = widget.song;
                  if (s != null) _startDownload(s);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDownloadBytes(int bytes) {
    if (bytes <= 0) return '--';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _systemStatusText(String status) => switch (status) {
    'pending' => '等待系统下载',
    'paused' => '系统已暂停',
    'running' => '正在传输',
    'segmented' => '分段传输',
    _ => status,
  };

  String _systemReasonText(int reason) => switch (reason) {
    1 => '原因码 1：等待系统重试，请保持网络',
    2 => '原因码 2：等待网络连接',
    3 => '原因码 3：等待 Wi-Fi',
    4 => '原因码 4：系统未说明原因',
    _ => '原因码 $reason',
  };
}
