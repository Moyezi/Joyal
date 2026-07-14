import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/music_classification.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/lyrics_ai_palette_provider.dart';
import '../providers/music_classification_provider.dart';
import '../providers/player_provider.dart';
import '../providers/song_highlight_provider.dart';
import '../services/app_cache_service.dart';
import '../utils/app_toast.dart';
import '../widgets/classification/classification_screen_sections.dart';

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

  Future<void> _deleteLyricsPalette(RecognizedLyricsAiPalette entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除歌词配色'),
        content: Text('清除《${entry.song.title}》的本地 AI 歌词配色？'),
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
        .read(lyricsAiPaletteRepositoryProvider)
        .delete(scope, entry.song.id);
    ref.invalidate(lyricsAiPaletteProvider);
    ref.invalidate(recognizedLyricsAiPalettesProvider);
    if (mounted) showAppToast(context, '已清除《${entry.song.title}》的歌词配色');
  }

  Future<void> _deleteAllLyricsPalettes(
    List<RecognizedLyricsAiPalette> entries,
  ) async {
    if (entries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除全部歌词配色'),
        content: Text(
          '将清除 ${entries.length} 首歌曲的本地 AI 歌词配色。标签、高潮记录和歌词缓存不会受影响。',
        ),
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
        .read(lyricsAiPaletteRepositoryProvider)
        .deleteAll(scope, entries.map((entry) => entry.song.id));
    ref.invalidate(lyricsAiPaletteProvider);
    ref.invalidate(recognizedLyricsAiPalettesProvider);
    if (mounted) showAppToast(context, '全部歌词配色已清除');
  }

  @override
  Widget build(BuildContext context) {
    _syncFields();
    final state = ref.watch(musicClassificationProvider);
    final library = ref.watch(libraryProvider);
    final highlights = ref.watch(recognizedSongHighlightsProvider);
    final palettes = ref.watch(recognizedLyricsAiPalettesProvider);
    final pendingCount = ref
        .read(musicClassificationProvider.notifier)
        .pendingCount(library.songs);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(title: const Text('小Jo同学')),
        body: Column(
          children: [
            JoHeader(
              classifiedCount: state.classifiedCount,
              totalCount: library.songs.length,
              highlightCount: highlights.asData?.value.length,
              paletteCount: palettes.asData?.value.length,
            ),
            const JoTabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildClassificationTab(
                    state,
                    pendingCount,
                    library.songs.length,
                  ),
                  _buildHighlightsTab(highlights),
                  _buildLyricsPalettesTab(palettes),
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
        TaskStatusPanel(
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
          style: classificationFilledPillButtonStyle(context),
          onPressed: state.isRunning ? null : () => _startClassification(),
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: const ButtonLabel('整理待处理歌曲'),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: classificationOutlinedPillButtonStyle(context),
                onPressed: state.isRunning
                    ? () =>
                          ref.read(musicClassificationProvider.notifier).pause()
                    : state.isPaused
                    ? () => ref
                          .read(musicClassificationProvider.notifier)
                          .resume()
                    : null,
                child: ButtonLabel(state.isPaused ? '继续' : '暂停'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: OutlinedButton(
                style: classificationOutlinedPillButtonStyle(context),
                onPressed: state.isRunning || state.isPaused
                    ? () => ref
                          .read(musicClassificationProvider.notifier)
                          .cancel()
                    : null,
                child: const ButtonLabel('取消'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: OutlinedButton(
                style: classificationOutlinedPillButtonStyle(context),
                onPressed: state.isRunning
                    ? null
                    : () => _startClassification(force: true),
                child: const ButtonLabel('全部重分'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingLG),
        PrivacyNote(
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
      error: (_, _) => HighlightsError(
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
            const EmptyHighlights()
          else
            for (final entry in entries) ...[
              HighlightSongCard(
                entry: entry,
                coverUrl: _coverUrl(entry.song),
                onDelete: () => _deleteHighlight(entry),
              ),
              const SizedBox(height: AppTheme.spacingSM),
            ],
          const SizedBox(height: AppTheme.spacingSM),
          const PrivacyNote(
            icon: Icons.lyrics_outlined,
            text: '高潮分析来自带时间歌词；这里展示和清除的都是当前服务器在本机保存的结果。',
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPalettesTab(
    AsyncValue<List<RecognizedLyricsAiPalette>> palettes,
  ) {
    return palettes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => LyricsPalettesError(
        onRetry: () => ref.invalidate(recognizedLyricsAiPalettesProvider),
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
                    Text('AI 歌词配色', style: context.textTitleLarge),
                    const SizedBox(height: 4),
                    Text(
                      entries.isEmpty
                          ? '还没有本地生成记录'
                          : '已生成 ${entries.length} 首，按最近生成排序',
                      style: context.textBodySmall,
                    ),
                  ],
                ),
              ),
              if (entries.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _deleteAllLyricsPalettes(entries),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('全部清除'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (entries.isEmpty)
            const EmptyLyricsPalettes()
          else
            for (final entry in entries) ...[
              LyricsPaletteSongCard(
                entry: entry,
                coverUrl: _coverUrl(entry.song),
                onDelete: () => _deleteLyricsPalette(entry),
              ),
              const SizedBox(height: AppTheme.spacingSM),
            ],
          const SizedBox(height: AppTheme.spacingSM),
          const PrivacyNote(
            icon: Icons.palette_outlined,
            text: '这里只读取和清除本机缓存，不会触发新的 AI 请求；生成时仅发送歌曲文字信息和纯歌词文本。',
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
        Text('标签整理、歌词高潮分析与 AI 歌词配色共用这套连接设置。', style: context.textBodySmall),
        const SizedBox(height: AppTheme.spacingMD),
        ClassificationTextInput(
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
        ClassificationTextInput(
          controller: _apiUrlController,
          label: 'API 地址',
          hintText: 'https://api.deepseek.com',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ClassificationTextInput(
          controller: _modelController,
          label: '模型名称',
          hintText: 'deepseek-chat',
        ),
        const SizedBox(height: AppTheme.spacingSM),
        ClassificationSettingTile(
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
        ClassificationSwitchTile(
          title: '仅使用 Wi-Fi',
          value: _wifiOnly,
          onChanged: (value) => setState(() => _wifiOnly = value),
        ),
        ClassificationSwitchTile(
          title: '分类通知',
          value: _notificationsEnabled,
          onChanged: (value) => setState(() => _notificationsEnabled = value),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: classificationOutlinedPillButtonStyle(context),
                onPressed: state.isTestingConnection ? null : _testConnection,
                child: state.isTestingConnection
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const ButtonLabel('测试连接'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: FilledButton(
                style: classificationFilledPillButtonStyle(context),
                onPressed: _save,
                child: const ButtonLabel('保存配置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSM),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: classificationOutlinedPillButtonStyle(
                  context,
                  foregroundColor: context.favoriteRedColor,
                ),
                onPressed: () async {
                  await ref
                      .read(musicClassificationProvider.notifier)
                      .clearApiKey();
                  if (mounted) showAppToast(context, 'API Key 已清除');
                },
                child: const ButtonLabel('清除 API Key'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: OutlinedButton(
                style: classificationOutlinedPillButtonStyle(context),
                onPressed: () async {
                  await ref
                      .read(musicClassificationProvider.notifier)
                      .restoreDefaults();
                  if (!mounted) return;
                  setState(() => _initializedFields = false);
                  showAppToast(context, '已恢复默认配置');
                },
                child: const ButtonLabel('恢复默认'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingLG),
        const PrivacyNote(
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
