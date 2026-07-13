import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_context.dart';
import '../../models/music_classification.dart';
import '../../models/song.dart';
import '../../providers/music_classification_provider.dart';
import '../../utils/app_toast.dart';

enum _ClassificationTagKind { genres, moods, scenes }

class SongDetailDialog extends ConsumerWidget {
  final String songTitle;
  final String songArtist;
  final Song? song;
  final SongClassification? classification;
  final bool isClassificationLoading;

  const SongDetailDialog({
    super.key,
    required this.songTitle,
    required this.songArtist,
    required this.song,
    required this.classification,
    required this.isClassificationLoading,
  });

  List<String> _valuesFor(
    SongClassification item,
    _ClassificationTagKind kind,
  ) {
    return switch (kind) {
      _ClassificationTagKind.genres => item.genres,
      _ClassificationTagKind.moods => item.moods,
      _ClassificationTagKind.scenes => item.scenes,
    };
  }

  List<String> _vocabularyFor(_ClassificationTagKind kind) {
    return switch (kind) {
      _ClassificationTagKind.genres => ClassificationVocabulary.genres,
      _ClassificationTagKind.moods => ClassificationVocabulary.moods,
      _ClassificationTagKind.scenes => ClassificationVocabulary.scenes,
    };
  }

  String _titleFor(_ClassificationTagKind kind) {
    return switch (kind) {
      _ClassificationTagKind.genres => '修正风格',
      _ClassificationTagKind.moods => '修正情绪',
      _ClassificationTagKind.scenes => '修正场景',
    };
  }

  SongClassification _manualUpdate(
    SongClassification item, {
    List<String>? genres,
    List<String>? moods,
    List<String>? scenes,
    String? language,
  }) {
    return item.copyWith(
      genres: genres,
      moods: moods,
      scenes: scenes,
      language: language,
      confidence: 1,
      source: ClassificationSource.manual,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _saveManual(
    WidgetRef ref,
    SongClassification classification,
  ) async {
    await ref
        .read(musicClassificationProvider.notifier)
        .updateManualClassification(classification);
  }

  Future<void> _showTagPicker(
    BuildContext dialogContext,
    WidgetRef ref,
    SongClassification item,
    _ClassificationTagKind kind,
  ) async {
    HapticFeedback.mediumImpact();
    final vocabulary = _vocabularyFor(kind);
    final selected = _valuesFor(item, kind).toSet();
    await showModalBottomSheet<void>(
      context: dialogContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: context.backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                MediaQuery.of(context).padding.bottom + 18,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.secondaryColor.withAlpha(80),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titleFor(kind),
                            style: context.textTitleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final values = selected.toList(growable: false);
                            final updated = switch (kind) {
                              _ClassificationTagKind.genres => _manualUpdate(
                                item,
                                genres: values,
                              ),
                              _ClassificationTagKind.moods => _manualUpdate(
                                item,
                                moods: values,
                              ),
                              _ClassificationTagKind.scenes => _manualUpdate(
                                item,
                                scenes: values,
                              ),
                            };
                            await _saveManual(ref, updated);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                            if (dialogContext.mounted) {
                              showAppToast(dialogContext, '已保存手动修正');
                            }
                          },
                          child: const Text('完成'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: vocabulary
                          .map((value) {
                            final isSelected = selected.contains(value);
                            return FilterChip(
                              label: Text(value),
                              selected: isSelected,
                              onSelected: (next) {
                                HapticFeedback.selectionClick();
                                setSheetState(() {
                                  if (next) {
                                    if (selected.length >= 3) {
                                      showAppToast(context, '每类最多选择 3 个标签');
                                      return;
                                    }
                                    selected.add(value);
                                  } else {
                                    selected.remove(value);
                                  }
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showLanguagePicker(
    BuildContext dialogContext,
    WidgetRef ref,
    SongClassification item,
  ) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: dialogContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: sheetContext.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: EdgeInsets.only(
            top: 10,
            bottom: MediaQuery.of(sheetContext).padding.bottom + 12,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.secondaryColor.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('修正语言', style: sheetContext.textTitleLarge),
                  ),
                ),
                const SizedBox(height: 6),
                ...ClassificationVocabulary.languages.map((language) {
                  final selected = language == item.language;
                  return ListTile(
                    title: Text(language, style: sheetContext.textBodyLarge),
                    trailing: selected
                        ? Icon(
                            Icons.check_rounded,
                            color: sheetContext.primaryColor,
                          )
                        : null,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await _saveManual(
                        ref,
                        _manualUpdate(item, language: language),
                      );
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      if (dialogContext.mounted) {
                        showAppToast(dialogContext, '已保存语言修正');
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final currentClassification = song == null
        ? classification
        : ref.watch(musicClassificationProvider).classifications[song!.id] ??
              classification;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: media.size.height * 0.82,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.secondaryColor.withAlpha(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            songTitle,
                            style: context.textTitleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            songArtist.isEmpty ? '未知艺术家' : songArtist,
                            style: context.textBodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close_rounded),
                      color: context.primaryColor,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ClassificationSection(
                        song: song,
                        classification: currentClassification,
                        isLoading: isClassificationLoading,
                        onEditTags: currentClassification == null
                            ? null
                            : (kind) => _showTagPicker(
                                context,
                                ref,
                                currentClassification,
                                kind,
                              ),
                        onEditLanguage: currentClassification == null
                            ? null
                            : () => _showLanguagePicker(
                                context,
                                ref,
                                currentClassification,
                              ),
                      ),
                      const SizedBox(height: 18),
                      _DetailSection(
                        title: '歌曲信息',
                        children: [
                          _DetailRow('专辑', _emptyAsUnknown(song?.album)),
                          _DetailRow('艺术家', _emptyAsUnknown(song?.artist)),
                          _DetailRow('时长', song?.formattedDuration ?? '--'),
                          _DetailRow(
                            '音轨',
                            song?.track == null ? '--' : '${song!.track}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _DetailSection(
                        title: '文件信息',
                        children: [
                          _DetailRow('格式', _emptyAsUnknown(song?.suffix)),
                          _DetailRow('类型', _emptyAsUnknown(song?.contentType)),
                          _DetailRow('大小', _formatBytes(song?.size ?? 0)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _DetailSection(
                        title: '曲库标识',
                        children: [
                          _DetailRow('歌曲 ID', song?.id ?? '--'),
                          _DetailRow('专辑 ID', _emptyAsUnknown(song?.parent)),
                          _DetailRow('封面 ID', _emptyAsUnknown(song?.coverArt)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassificationSection extends StatelessWidget {
  final Song? song;
  final SongClassification? classification;
  final bool isLoading;
  final ValueChanged<_ClassificationTagKind>? onEditTags;
  final VoidCallback? onEditLanguage;

  const _ClassificationSection({
    required this.song,
    required this.classification,
    required this.isLoading,
    this.onEditTags,
    this.onEditLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final item = classification;
    if (item == null) {
      return _DetailSection(
        title: '小Jo标签',
        children: [
          Text(
            isLoading ? '分类信息加载中' : '这首歌还没有分类结果',
            style: context.textBodyMedium,
          ),
        ],
      );
    }

    return _DetailSection(
      title: '小Jo标签',
      children: [
        _TagWrap(
          label: '风格',
          values: item.genres,
          onLongPress: onEditTags == null
              ? null
              : () => onEditTags!(_ClassificationTagKind.genres),
        ),
        _TagWrap(
          label: '情绪',
          values: item.moods,
          onLongPress: onEditTags == null
              ? null
              : () => onEditTags!(_ClassificationTagKind.moods),
        ),
        _TagWrap(
          label: '场景',
          values: item.scenes,
          onLongPress: onEditTags == null
              ? null
              : () => onEditTags!(_ClassificationTagKind.scenes),
        ),
        _DetailRow(
          '语言',
          item.language,
          onTap: onEditLanguage,
          trailingIcon: Icons.expand_more_rounded,
        ),
        _DetailRow('年代', song == null ? '年份未知' : decadeLabelForSong(song!)),
        const SizedBox(height: 10),
        _EnergyBar(value: item.energy),
        const SizedBox(height: 10),
        _DetailRow('置信度', '${(item.confidence * 100).round()}%'),
        _DetailRow(
          '来源',
          item.source == ClassificationSource.manual ? '手动修正' : 'AI 分类',
        ),
        _DetailRow('模型', item.model),
        _DetailRow('更新时间', _formatDateTime(item.updatedAt)),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor.withAlpha(190),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textTitleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  const _DetailRow(this.label, this.value, {this.onTap, this.trailingIcon});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: context.textBodyMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '--' : value,
              style: context.textBodyMedium.copyWith(
                color: context.primaryColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 18, color: context.secondaryColor),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: content,
    );
  }
}

class _TagWrap extends StatelessWidget {
  final String label;
  final List<String> values;
  final VoidCallback? onLongPress;

  const _TagWrap({required this.label, required this.values, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.textBodyMedium),
          const SizedBox(height: 8),
          if (values.isEmpty)
            Text('--', style: context.textBodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map(
                    (value) => GestureDetector(
                      onLongPress: onLongPress,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.backgroundColor.withAlpha(170),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: context.secondaryColor.withAlpha(36),
                          ),
                        ),
                        child: Text(value, style: context.textBodySmall),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _EnergyBar extends StatelessWidget {
  final int value;

  const _EnergyBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0, 100) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('能量', style: context.textBodyMedium),
            const Spacer(),
            Text('$value/100', style: context.textBodyMedium),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 6,
            backgroundColor: context.backgroundColor.withAlpha(160),
            color: context.primaryColor,
          ),
        ),
      ],
    );
  }
}

String _emptyAsUnknown(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? '--' : text;
}

String _formatDateTime(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '--';
  final local = value.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '--';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final digits = unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
