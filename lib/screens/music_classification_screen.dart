import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/music_classification.dart';
import '../models/song.dart';
import '../models/song_highlight.dart';
import '../providers/library_provider.dart';
import '../providers/music_classification_provider.dart';
import '../providers/player_provider.dart';
import '../providers/song_highlight_provider.dart';
import '../services/app_cache_service.dart';
import '../utils/app_toast.dart';
import '../widgets/album_cover.dart';

class MusicClassificationScreen extends ConsumerStatefulWidget {
  const MusicClassificationScreen({super.key});

  @override
  ConsumerState<MusicClassificationScreen> createState() =>
      _MusicClassificationScreenState();
}

class _MusicClassificationScreenState
    extends ConsumerState<MusicClassificationScreen> {
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureApiKey = true;
  bool _initializedFields = false;
  int _batchSize = 20;
  bool _wifiOnly = true;
  bool _notificationsEnabled = true;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _syncFields() {
    if (_initializedFields) return;
    final settings = ref.read(musicClassificationProvider).settings;
    _apiUrlController.text = settings.apiBaseUrl;
    _modelController.text = settings.model;
    _batchSize = settings.batchSize;
    _wifiOnly = settings.wifiOnly;
    _notificationsEnabled = settings.notificationsEnabled;
    _initializedFields = true;
  }

  Future<void> _save() async {
    await ref
        .read(musicClassificationProvider.notifier)
        .saveSettings(
          apiKey: _apiKeyController.text,
          apiBaseUrl: _apiUrlController.text.trim(),
          model: _modelController.text.trim(),
          batchSize: _batchSize,
          wifiOnly: _wifiOnly,
          notificationsEnabled: _notificationsEnabled,
        );
    _apiKeyController.clear();
    if (mounted) showAppToast(context, '小Jo 的服务设置已保存');
  }

  Future<void> _testConnection() async {
    try {
      final settings = ref
          .read(musicClassificationProvider)
          .settings
          .copyWith(
            apiBaseUrl: _apiUrlController.text.trim(),
            model: _modelController.text.trim(),
            batchSize: _batchSize,
            wifiOnly: _wifiOnly,
            notificationsEnabled: _notificationsEnabled,
          );
      await ref
          .read(musicClassificationProvider.notifier)
          .testConnection(
            apiKeyOverride: _apiKeyController.text,
            settingsOverride: settings,
          );
      if (mounted) showAppToast(context, '连接成功，DeepSeek 服务可以正常使用');
    } catch (_) {
      if (!mounted) return;
      final error = ref.read(musicClassificationProvider).error ?? '连接失败';
      showAppToast(context, error);
    }
  }

  Future<void> _startClassification({bool force = false}) async {
    final library = ref.read(libraryProvider);
    final notifier = ref.read(musicClassificationProvider.notifier);
    final pending = force
        ? library.songs.length
        : notifier.pendingCount(library.songs);
    if (library.songs.isEmpty) {
      showAppToast(context, '曲库还没有歌曲，请先刷新曲库');
      return;
    }
    if (!ref.read(musicClassificationProvider).hasApiKey &&
        _apiKeyController.text.trim().isEmpty) {
      showAppToast(context, '请先在“服务”中填写并保存 DeepSeek API Key');
      return;
    }
    if (_apiKeyController.text.trim().isNotEmpty) await _save();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(force ? '重新整理全部标签' : '开始整理标签'),
        content: Text(
          '待处理歌曲：$pending 首\n'
          '预计请求批次：${(pending / _batchSize).ceil()} 批\n'
          '每批歌曲：$_batchSize 首\n\n'
          '这会使用你的 DeepSeek API 额度，结果只保存在当前设备。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('开始整理'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await notifier.startClassification(library.songs, force: force);
      if (mounted) showAppToast(context, '标签整理已完成');
    } catch (_) {
      if (!mounted) return;
      final error = ref.read(musicClassificationProvider).error ?? '分类失败';
      showAppToast(context, error);
    }
  }

  Future<void> _deleteHighlight(RecognizedSongHighlight entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除高潮记录'),
        content: Text('清除《${entry.song.title}》的本地高潮识别结果？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    final scope = AppCacheService.instance.serverScope(
      api.baseUrl,
      api.username,
    );
    await ref
        .read(songHighlightRepositoryProvider)
        .delete(scope, entry.song.id);
    ref.invalidate(cachedSongHighlightProvider(entry.song));
    ref.invalidate(songHighlightProvider);
    ref.invalidate(recognizedSongHighlightsProvider);
    if (mounted) showAppToast(context, '已清除《${entry.song.title}》的高潮记录');
  }

  Future<void> _deleteAllHighlights(
    List<RecognizedSongHighlight> entries,
  ) async {
    if (entries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除全部高潮记录'),
        content: Text('将清除 ${entries.length} 首歌曲的本地高潮识别结果。标签分类不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('全部清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    final scope = AppCacheService.instance.serverScope(
      api.baseUrl,
      api.username,
    );
    await ref
        .read(songHighlightRepositoryProvider)
        .deleteAll(scope, entries.map((entry) => entry.song.id));
    for (final entry in entries) {
      ref.invalidate(cachedSongHighlightProvider(entry.song));
    }
    ref.invalidate(songHighlightProvider);
    ref.invalidate(recognizedSongHighlightsProvider);
    if (mounted) showAppToast(context, '全部高潮记录已清除');
  }

  @override
  Widget build(BuildContext context) {
    _syncFields();
    final state = ref.watch(musicClassificationProvider);
    final library = ref.watch(libraryProvider);
    final highlights = ref.watch(recognizedSongHighlightsProvider);
    final pendingCount = ref
        .read(musicClassificationProvider.notifier)
        .pendingCount(library.songs);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('小Jo同学')),
        body: Column(
          children: [
            _JoHeader(
              classifiedCount: state.classifiedCount,
              totalCount: library.songs.length,
              highlightCount: highlights.asData?.value.length,
            ),
            const _JoTabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildClassificationTab(
                    state,
                    pendingCount,
                    library.songs.length,
                  ),
                  _buildHighlightsTab(highlights),
                  _buildServiceTab(state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationTab(
    MusicClassificationState state,
    int pendingCount,
    int totalSongs,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      children: [
        _TaskStatusPanel(
          statusText: _statusText(state),
          detailText:
              '已整理 ${state.classifiedCount} / $totalSongs 首 · 待整理 $pendingCount 首',
          progress: state.progress,
          isRunning: state.isRunning,
        ),
        const SizedBox(height: AppTheme.spacingLG),
        Text('标签整理', style: context.textTitleLarge),
        const SizedBox(height: 4),
        Text('保留原有的流派、情绪、场景和语言标签，可在歌曲详情中继续长按修正。', style: context.textBodySmall),
        const SizedBox(height: AppTheme.spacingMD),
        FilledButton.icon(
          style: _filledPillButtonStyle(context),
          onPressed: state.isRunning ? null : () => _startClassification(),
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: const _ButtonLabel('整理待处理歌曲'),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: _outlinedPillButtonStyle(context),
                onPressed: state.isRunning
                    ? () =>
                          ref.read(musicClassificationProvider.notifier).pause()
                    : state.isPaused
                    ? () => ref
                          .read(musicClassificationProvider.notifier)
                          .resume()
                    : null,
                child: _ButtonLabel(state.isPaused ? '继续' : '暂停'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: OutlinedButton(
                style: _outlinedPillButtonStyle(context),
                onPressed: state.isRunning || state.isPaused
                    ? () => ref
                          .read(musicClassificationProvider.notifier)
                          .cancel()
                    : null,
                child: const _ButtonLabel('取消'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: OutlinedButton(
                style: _outlinedPillButtonStyle(context),
                onPressed: state.isRunning
                    ? null
                    : () => _startClassification(force: true),
                child: const _ButtonLabel('全部重分'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingLG),
        _PrivacyNote(
          icon: Icons.text_fields_rounded,
          text: '标签整理只发送歌曲名、歌手和专辑等文字元数据，不上传音乐文件。',
        ),
      ],
    );
  }

  Widget _buildHighlightsTab(
    AsyncValue<List<RecognizedSongHighlight>> highlights,
  ) {
    return highlights.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _HighlightsError(
        onRetry: () => ref.invalidate(recognizedSongHighlightsProvider),
      ),
      data: (entries) => ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('高潮记录', style: context.textTitleLarge),
                    const SizedBox(height: 4),
                    Text(
                      entries.isEmpty
                          ? '还没有本地识别记录'
                          : '已识别 ${entries.length} 首，按最近识别排序',
                      style: context.textBodySmall,
                    ),
                  ],
                ),
              ),
              if (entries.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _deleteAllHighlights(entries),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('全部清除'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (entries.isEmpty)
            const _EmptyHighlights()
          else
            for (final entry in entries) ...[
              _HighlightSongCard(
                entry: entry,
                coverUrl: _coverUrl(entry.song),
                onDelete: () => _deleteHighlight(entry),
              ),
              const SizedBox(height: AppTheme.spacingSM),
            ],
          const SizedBox(height: AppTheme.spacingSM),
          const _PrivacyNote(
            icon: Icons.lyrics_outlined,
            text: '高潮分析来自带时间歌词；这里展示和清除的都是当前服务器在本机保存的结果。',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTab(MusicClassificationState state) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      children: [
        Text('DeepSeek 服务', style: context.textTitleLarge),
        const SizedBox(height: 4),
        Text('标签整理与歌词高潮分析共用这套连接设置。', style: context.textBodySmall),
        const SizedBox(height: AppTheme.spacingMD),
        _TextInput(
          controller: _apiKeyController,
          label: 'API Key',
          hintText: state.hasApiKey ? '已保存 sk-••••••••' : 'sk-...',
          obscureText: _obscureApiKey,
          suffix: IconButton(
            onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
            icon: Icon(
              _obscureApiKey
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _TextInput(
          controller: _apiUrlController,
          label: 'API 地址',
          hintText: 'https://api.deepseek.com',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _TextInput(
          controller: _modelController,
          label: '模型名称',
          hintText: 'deepseek-chat',
        ),
        const SizedBox(height: AppTheme.spacingSM),
        _SettingTile(
          title: '每批处理数量',
          subtitle: '默认 20 首，并发请求固定为 1',
          trailing: DropdownButton<int>(
            value: _batchSize,
            underline: const SizedBox.shrink(),
            items: const [10, 20, 30, 40]
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text('$value 首')),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _batchSize = value);
            },
          ),
        ),
        _SwitchTile(
          title: '仅使用 Wi-Fi',
          value: _wifiOnly,
          onChanged: (value) => setState(() => _wifiOnly = value),
        ),
        _SwitchTile(
          title: '分类通知',
          value: _notificationsEnabled,
          onChanged: (value) => setState(() => _notificationsEnabled = value),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: _outlinedPillButtonStyle(context),
                onPressed: state.isTestingConnection ? null : _testConnection,
                child: state.isTestingConnection
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const _ButtonLabel('测试连接'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: FilledButton(
                style: _filledPillButtonStyle(context),
                onPressed: _save,
                child: const _ButtonLabel('保存配置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSM),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: _outlinedPillButtonStyle(
                  context,
                  foregroundColor: context.favoriteRedColor,
                ),
                onPressed: () async {
                  await ref
                      .read(musicClassificationProvider.notifier)
                      .clearApiKey();
                  if (mounted) showAppToast(context, 'API Key 已清除');
                },
                child: const _ButtonLabel('清除 API Key'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: OutlinedButton(
                style: _outlinedPillButtonStyle(context),
                onPressed: () async {
                  await ref
                      .read(musicClassificationProvider.notifier)
                      .restoreDefaults();
                  if (!mounted) return;
                  setState(() => _initializedFields = false);
                  showAppToast(context, '已恢复默认配置');
                },
                child: const _ButtonLabel('恢复默认'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingLG),
        const _PrivacyNote(
          icon: Icons.shield_outlined,
          text: 'API Key 只存放在系统安全存储中，不会写入高潮记录或分类缓存。',
        ),
      ],
    );
  }

  String _coverUrl(Song song) {
    final api = ref.read(subsonicApiProvider);
    if (api == null || song.coverArt.isEmpty) return '';
    return api.getCoverArtUrl(song.coverArt);
  }

  String _statusText(MusicClassificationState state) {
    return switch (state.status) {
      ClassificationTaskStatus.running => '小Jo 正在整理你的曲库',
      ClassificationTaskStatus.paused => '标签整理已暂停',
      ClassificationTaskStatus.completed => '曲库标签已整理完成',
      ClassificationTaskStatus.failed => state.error ?? '分类失败',
      ClassificationTaskStatus.idle =>
        state.hasApiKey ? '小Jo 已准备好' : 'DeepSeek API 尚未配置',
    };
  }
}

class _JoHeader extends StatelessWidget {
  final int classifiedCount;
  final int totalCount;
  final int? highlightCount;

  const _JoHeader({
    required this.classifiedCount,
    required this.totalCount,
    required this.highlightCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFB5CEE2) : const Color(0xFF4B708D);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        AppTheme.spacingSM,
        AppTheme.spacingLG,
        AppTheme.spacingSM,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: CustomPaint(painter: _JoPulsePainter(color: accent)),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你的音乐整理台', style: context.textTitleLarge),
                const SizedBox(height: 3),
                Text('标签与高潮，都在本机有迹可循。', style: context.textBodySmall),
                const SizedBox(height: AppTheme.spacingSM),
                Row(
                  children: [
                    _HeaderMetric(
                      label: '标签',
                      value: '$classifiedCount/$totalCount',
                    ),
                    const SizedBox(width: AppTheme.spacingLG),
                    _HeaderMetric(
                      label: '高潮',
                      value: highlightCount?.toString() ?? '—',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: context.textCaption,
        children: [
          TextSpan(text: '$label  '),
          TextSpan(
            text: value,
            style: context.textTitleMedium.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoPulsePainter extends CustomPainter {
  final Color color;
  const _JoPulsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4;
    const heights = [12.0, 25.0, 40.0, 21.0, 31.0];
    final gap = size.width / (heights.length + 1);
    for (var index = 0; index < heights.length; index++) {
      final x = gap * (index + 1);
      canvas.drawLine(
        Offset(x, (size.height - heights[index]) / 2),
        Offset(x, (size.height + heights[index]) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JoPulsePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _JoTabBar extends StatelessWidget {
  const _JoTabBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
      child: TabBar(
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        tabs: const [
          Tab(text: '标签'),
          Tab(text: '高潮'),
          Tab(text: '服务'),
        ],
      ),
    );
  }
}

class _TaskStatusPanel extends StatelessWidget {
  final String statusText;
  final String detailText;
  final double progress;
  final bool isRunning;

  const _TaskStatusPanel({
    required this.statusText,
    required this.detailText,
    required this.progress,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText, style: context.textTitleMedium),
          const SizedBox(height: AppTheme.spacingSM),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: isRunning && progress <= 0 ? null : progress.clamp(0, 1),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(detailText, style: context.textBodySmall),
        ],
      ),
    );
  }
}

class _HighlightSongCard extends StatelessWidget {
  final RecognizedSongHighlight entry;
  final String coverUrl;
  final VoidCallback onDelete;

  const _HighlightSongCard({
    required this.entry,
    required this.coverUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final song = entry.song;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          AlbumCover(
            coverArtUrl: coverUrl,
            cacheKey: song.coverArt,
            size: 58,
            borderRadius: 18,
            showShadow: false,
          ),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTitleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist.isEmpty ? '未知歌手' : song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textBodySmall,
                ),
                const SizedBox(height: AppTheme.spacingSM),
                _ClimaxTrack(
                  duration: Duration(seconds: song.duration),
                  segments: entry.timeline.segments,
                ),
                const SizedBox(height: 5),
                Text(
                  entry.timeline.segments.map(_formatSegment).join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textCaption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '清除这首歌的高潮记录',
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ClimaxTrack extends StatelessWidget {
  final Duration duration;
  final List<SongHighlightSegment> segments;

  const _ClimaxTrack({required this.duration, required this.segments});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB5CEE2)
        : const Color(0xFF4B708D);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (duration > Duration.zero)
              for (final segment in segments)
                Positioned(
                  left:
                      constraints.maxWidth *
                      (segment.start.inMilliseconds / duration.inMilliseconds)
                          .clamp(0.0, 1.0),
                  width:
                      (constraints.maxWidth *
                              ((segment.end - segment.start).inMilliseconds /
                                  duration.inMilliseconds))
                          .clamp(4.0, constraints.maxWidth),
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHighlights extends StatelessWidget {
  const _EmptyHighlights();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLG,
        vertical: AppTheme.spacingXL,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            size: 42,
            color: context.secondaryColor,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text('播放带时间歌词的歌曲', style: context.textTitleMedium),
          const SizedBox(height: 4),
          Text(
            '进入“流光”歌词后，小Jo 会在需要时识别高潮，结果随后会出现在这里。',
            textAlign: TextAlign.center,
            style: context.textBodySmall,
          ),
        ],
      ),
    );
  }
}

class _HighlightsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _HighlightsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('高潮记录读取失败，重新加载'),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PrivacyNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: context.secondaryColor),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(child: Text(text, style: context.textCaption)),
      ],
    );
  }
}

String _formatSegment(SongHighlightSegment segment) {
  String format(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  return '${format(segment.start)}–${format(segment.end)}';
}

ButtonStyle _filledPillButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: const Size(0, 56),
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
    shape: const StadiumBorder(),
    textStyle: context.textTitleMedium,
  );
}

ButtonStyle _outlinedPillButtonStyle(
  BuildContext context, {
  Color? foregroundColor,
}) {
  final color = foregroundColor ?? context.primaryColor;
  return OutlinedButton.styleFrom(
    foregroundColor: color,
    minimumSize: const Size(0, 56),
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSM),
    shape: const StadiumBorder(),
    side: BorderSide(color: color, width: 1.2),
    textStyle: context.textTitleMedium,
  );
}

class _ButtonLabel extends StatelessWidget {
  final String text;
  const _ButtonLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _TextInput({
    required this.controller,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: label == 'API Key'
          ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixIcon: suffix,
        filled: true,
        fillColor: context.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: context.textTitleMedium),
      subtitle: Text(subtitle, style: context.textBodySmall),
      trailing: trailing,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: context.textTitleMedium),
      value: value,
      onChanged: onChanged,
    );
  }
}
