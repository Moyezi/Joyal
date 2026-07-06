import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/music_classification.dart';
import '../providers/library_provider.dart';
import '../providers/music_classification_provider.dart';
import '../utils/app_toast.dart';

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
    if (mounted) showAppToast(context, 'AI 服务设置已保存');
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
      showAppToast(context, '请先填写并保存 DeepSeek API Key');
      return;
    }
    if (_apiKeyController.text.trim().isNotEmpty) {
      await _save();
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('准备分类曲库'),
        content: Text(
          '待分类歌曲：$pending 首\n'
          '预计请求批次：${(pending / _batchSize).ceil()} 批\n'
          '每批歌曲：$_batchSize 首\n\n'
          '分类过程将使用你的 DeepSeek API 额度，结果只保存在当前设备。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('开始分类'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await notifier.startClassification(library.songs, force: force);
      if (mounted) showAppToast(context, '曲库分类已完成');
    } catch (_) {
      if (!mounted) return;
      final error = ref.read(musicClassificationProvider).error ?? '分类失败';
      showAppToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncFields();
    final state = ref.watch(musicClassificationProvider);
    final library = ref.watch(libraryProvider);
    final pendingCount = ref
        .read(musicClassificationProvider.notifier)
        .pendingCount(library.songs);

    return Scaffold(
      appBar: AppBar(title: const Text('智能分类')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          _StatusCard(
            totalSongs: library.songs.length,
            pendingSongs: pendingCount,
            classifiedSongs: state.classifiedCount,
            progress: state.progress,
            statusText: _statusText(state),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          _SectionTitle('AI 服务设置'),
          const SizedBox(height: AppTheme.spacingSM),
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
          const SizedBox(height: AppTheme.spacingMD),
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
          const SizedBox(height: AppTheme.spacingLG),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isTestingConnection ? null : _testConnection,
                  child: state.isTestingConnection
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('测试连接'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    await ref
                        .read(musicClassificationProvider.notifier)
                        .clearApiKey();
                    if (!context.mounted) return;
                    showAppToast(context, 'API Key 已清除');
                  },
                  child: Text(
                    '清除 API Key',
                    style: TextStyle(color: context.favoriteRedColor),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    await ref
                        .read(musicClassificationProvider.notifier)
                        .restoreDefaults();
                    if (!context.mounted) return;
                    setState(() => _initializedFields = false);
                    showAppToast(context, '已恢复默认配置');
                  },
                  child: const Text('恢复默认配置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          _SectionTitle('分类任务'),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.isRunning
                      ? null
                      : () => _startClassification(),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('开始智能分类'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isRunning
                      ? () => ref
                            .read(musicClassificationProvider.notifier)
                            .pause()
                      : state.isPaused
                      ? () => ref
                            .read(musicClassificationProvider.notifier)
                            .resume()
                      : null,
                  child: Text(state.isPaused ? '继续' : '暂停'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isRunning || state.isPaused
                      ? () => ref
                            .read(musicClassificationProvider.notifier)
                            .cancel()
                      : null,
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isRunning
                      ? null
                      : () => _startClassification(force: true),
                  child: const Text('全部重分'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            '只会向 DeepSeek 发送歌曲名、歌手和专辑等文字元数据，不上传音乐文件；API Key 存放在系统安全存储中。',
            style: context.textCaption,
          ),
        ],
      ),
    );
  }

  String _statusText(MusicClassificationState state) {
    return switch (state.status) {
      ClassificationTaskStatus.running => '正在整理你的曲库',
      ClassificationTaskStatus.paused => '分类任务已暂停',
      ClassificationTaskStatus.completed => '曲库分类已完成',
      ClassificationTaskStatus.failed => state.error ?? '分类失败',
      ClassificationTaskStatus.idle =>
        state.hasApiKey ? '准备开始智能分类' : 'DeepSeek API 尚未配置',
    };
  }
}

class _StatusCard extends StatelessWidget {
  final int totalSongs;
  final int pendingSongs;
  final int classifiedSongs;
  final double progress;
  final String statusText;

  const _StatusCard({
    required this.totalSongs,
    required this.pendingSongs,
    required this.classifiedSongs,
    required this.progress,
    required this.statusText,
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
          Text(statusText, style: context.textTitleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          LinearProgressIndicator(value: progress == 0 ? null : progress),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            '已分类 $classifiedSongs / $totalSongs 首 · 待分类 $pendingSongs 首',
            style: context.textBodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.textTitleLarge);
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
