import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_context.dart';
import '../../models/song.dart';
import '../../providers/glass_effect_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/lyrics_ai_palette_provider.dart';
import '../../providers/lyrics_personalization_provider.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/lyrics_source_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/lyrics_service.dart';
import '../../utils/app_toast.dart';
import 'lyrics_settings_controls.dart';

class LyricsPersonalizationSheet extends ConsumerWidget {
  const LyricsPersonalizationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(lyricsPersonalizationProvider);
    final currentSong = ref.watch(
      playerProvider.select((state) => state.currentSong),
    );
    final api = ref.watch(subsonicApiProvider);
    final hasLyricsTarget = currentSong != null && api != null;
    final lyricsSource = currentSong == null
        ? LyricsSource.amll
        : ref.watch(lyricsSourceForSongProvider(currentSong));
    final currentLyrics = currentSong == null
        ? null
        : ref.watch(lyricsProvider(currentSong));
    final resolvedLyrics = currentLyrics?.asData?.value;
    final aiPaletteState =
        preferences.aiColorEnabled &&
            currentSong != null &&
            resolvedLyrics != null
        ? ref.watch(
            lyricsAiPaletteProvider(
              LyricsAiPaletteRequest(currentSong, resolvedLyrics),
            ),
          )
        : null;
    final resolvedLyricsSource = resolvedLyrics?.source;
    const inactiveLyricsTarget = GlassEffectTarget.lyricsPage;
    const drawerGlassTarget = GlassEffectTarget.lyricsDrawer;
    final inactiveBlur = ref
        .watch(
          glassEffectProvider.select(
            (state) => state.blurFor(inactiveLyricsTarget),
          ),
        )
        .clamp(0.0, 12.0)
        .toDouble();
    final inactiveOpacity = ref
        .watch(
          glassEffectProvider.select(
            (state) => state.opacityFor(inactiveLyricsTarget),
          ),
        )
        .clamp(0.0, 1.0)
        .toDouble();
    final drawerBlur = ref.watch(
      glassEffectProvider.select((state) => state.blurFor(drawerGlassTarget)),
    );
    final drawerTintOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(drawerGlassTarget),
      ),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.84,
      ),
      child: LyricsDrawerGlass(
        blurSigma: drawerBlur,
        tintColor: context.surfaceColor,
        tintOpacity: drawerTintOpacity,
        borderColor: context.primaryColor,
        borderOpacity: isDark ? 0.08 : 0.06,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.secondaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '歌词个性化',
                      style: context.textTitleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '恢复默认',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      unawaited(
                        ref
                            .read(lyricsPersonalizationProvider.notifier)
                            .reset(),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setBlur(
                              inactiveLyricsTarget,
                              inactiveLyricsTarget.defaultBlur,
                            ),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setOpacity(
                              inactiveLyricsTarget,
                              inactiveLyricsTarget.defaultOpacity,
                            ),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setBlur(
                              drawerGlassTarget,
                              drawerGlassTarget.defaultBlur,
                            ),
                      );
                      unawaited(
                        ref
                            .read(glassEffectProvider.notifier)
                            .setOpacity(
                              drawerGlassTarget,
                              drawerGlassTarget.defaultOpacity,
                            ),
                      );
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '双指捏合可再次打开；所有更改会立即生效。',
                style: context.textBodySmall.copyWith(
                  color: context.secondaryColor,
                ),
              ),
              const SizedBox(height: 22),
              LyricsSettingsSection(
                title: '歌词内容',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasLyricsTarget) ...[
                      const LyricsOptionLabel(title: '歌词来源'),
                      const SizedBox(height: 4),
                      Text(
                        '当前歌曲：${resolvedLyricsSource?.label ?? '正在识别…'}',
                        style: context.textBodySmall.copyWith(
                          color: context.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lyricsSource.description,
                        style: context.textBodySmall.copyWith(
                          color: context.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LyricsChoiceGrid(
                        children: [
                          for (final source in LyricsSource.values)
                            LyricsChoiceButton(
                              label: _lyricsSourceLabel(source),
                              icon: source == LyricsSource.amll
                                  ? Icons.auto_awesome_rounded
                                  : Icons.storage_rounded,
                              selected: lyricsSource == source,
                              onTap: () {
                                if (lyricsSource == source) return;
                                HapticFeedback.selectionClick();
                                unawaited(
                                  _setCurrentLyricsSource(context, ref, source),
                                );
                              },
                            ),
                        ],
                      ),
                      const LyricsSectionDivider(),
                    ],
                    LyricsToggleTile(
                      title: '逐字高亮',
                      subtitle: '内嵌逐字或 TTML 含字级时间轴时生效',
                      value: preferences.wordByWordEnabled,
                      onChanged: (enabled) {
                        HapticFeedback.selectionClick();
                        unawaited(
                          ref
                              .read(lyricsPersonalizationProvider.notifier)
                              .setWordByWordEnabled(enabled),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LyricsSettingsSection(
                title: '歌词舞台',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '舞台会保留当前歌词来源、逐字时间轴与显示颜色。',
                      style: context.textBodySmall.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LyricsChoiceGrid(
                      children: [
                        for (final mode in LyricsStageMode.values)
                          LyricsChoiceButton(
                            label: mode.isAvailable
                                ? mode.label
                                : '${mode.label} · 待完成',
                            icon: _iconForStageMode(mode),
                            selected: preferences.stageMode == mode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (!mode.isAvailable) {
                                showAppToast(
                                  context,
                                  '${mode.label}舞台将在后续完成',
                                  replaceCurrent: true,
                                );
                                return;
                              }
                              unawaited(
                                ref
                                    .read(
                                      lyricsPersonalizationProvider.notifier,
                                    )
                                    .setStageMode(mode),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LyricsSettingsSection(
                title: '文字',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preferences.stageMode ==
                        LyricsStageMode.defaultScroll) ...[
                      const LyricsOptionLabel(title: '对齐'),
                      const SizedBox(height: 8),
                      LyricsChoiceGrid(
                        columns: 3,
                        children: [
                          for (final alignment in LyricsAlignmentMode.values)
                            LyricsChoiceButton(
                              label: _lyricsAlignmentLabel(alignment),
                              icon: _iconForAlignment(alignment),
                              selected: preferences.alignment == alignment,
                              compact: true,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                unawaited(
                                  ref
                                      .read(
                                        lyricsPersonalizationProvider.notifier,
                                      )
                                      .setAlignment(alignment),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    LyricsOptionLabel(
                      title: switch (preferences.stageMode) {
                        LyricsStageMode.flowingLight => '流光字号',
                        LyricsStageMode.floatingName => '浮名字号',
                        _ => '默认滚动字号',
                      },
                    ),
                    const SizedBox(height: 4),
                    LyricsSliderRow(
                      icon: Icons.format_size_rounded,
                      value: switch (preferences.stageMode) {
                        LyricsStageMode.flowingLight =>
                          preferences.flowingLightFontSize,
                        LyricsStageMode.floatingName =>
                          preferences.floatingNameFontSize,
                        _ => preferences.fontSize,
                      },
                      min: switch (preferences.stageMode) {
                        LyricsStageMode.flowingLight =>
                          LyricsPersonalizationState.minFlowingLightFontSize,
                        LyricsStageMode.floatingName =>
                          LyricsPersonalizationState.minFloatingNameFontSize,
                        _ => LyricsPersonalizationState.minFontSize,
                      },
                      max: switch (preferences.stageMode) {
                        LyricsStageMode.flowingLight =>
                          LyricsPersonalizationState.maxFlowingLightFontSize,
                        LyricsStageMode.floatingName =>
                          LyricsPersonalizationState.maxFloatingNameFontSize,
                        _ => LyricsPersonalizationState.maxFontSize,
                      },
                      divisions: switch (preferences.stageMode) {
                        LyricsStageMode.flowingLight => 28,
                        LyricsStageMode.floatingName => 28,
                        _ => 24,
                      },
                      label: switch (preferences.stageMode) {
                        LyricsStageMode.flowingLight =>
                          preferences.flowingLightFontSize.toStringAsFixed(0),
                        LyricsStageMode.floatingName =>
                          preferences.floatingNameFontSize.toStringAsFixed(0),
                        _ => preferences.fontSize.toStringAsFixed(0),
                      },
                      valueText: switch (preferences.stageMode) {
                        LyricsStageMode.flowingLight =>
                          preferences.flowingLightFontSize.toStringAsFixed(0),
                        LyricsStageMode.floatingName =>
                          preferences.floatingNameFontSize.toStringAsFixed(0),
                        _ => preferences.fontSize.toStringAsFixed(0),
                      },
                      onChanged: (value) {
                        final notifier = ref.read(
                          lyricsPersonalizationProvider.notifier,
                        );
                        if (preferences.stageMode ==
                            LyricsStageMode.flowingLight) {
                          unawaited(notifier.setFlowingLightFontSize(value));
                        } else if (preferences.stageMode ==
                            LyricsStageMode.floatingName) {
                          unawaited(notifier.setFloatingNameFontSize(value));
                        } else {
                          unawaited(notifier.setFontSize(value));
                        }
                      },
                      onChangeEnd: (_) {},
                    ),
                    const SizedBox(height: 8),
                    LyricsChoiceGrid(
                      children: [
                        LyricsChoiceButton(
                          label: '系统字体',
                          icon: _iconForFontFamily(LyricsFontFamily.system),
                          selected:
                              preferences.fontFamily == LyricsFontFamily.system,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            unawaited(
                              ref
                                  .read(lyricsPersonalizationProvider.notifier)
                                  .setFontFamily(LyricsFontFamily.system),
                            );
                          },
                        ),
                        LyricsChoiceButton(
                          label: _customFontLabel(preferences),
                          icon: _iconForFontFamily(LyricsFontFamily.custom),
                          selected:
                              preferences.fontFamily ==
                                  LyricsFontFamily.custom &&
                              preferences.hasCustomFont,
                          onTap: () {
                            unawaited(
                              _handleCustomFontTap(context, ref, preferences),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preferences.hasCustomFont
                          ? '已使用 ${preferences.customFontName}；点击可更换。'
                          : '可导入 .ttf 字体，仅用于歌词显示。',
                      style: context.textBodySmall.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LyricsToggleTile(
                      title: 'AI 文字配色',
                      subtitle: aiPaletteState?.isLoading == true
                          ? '正在分析歌词语义、情绪走向与歌曲氛围'
                          : aiPaletteState?.asData?.value != null
                          ? '已为歌词关键词生成情绪分层配色；关闭后恢复默认'
                          : switch (preferences.stageMode) {
                              LyricsStageMode.flowingLight =>
                                '当前字与光晕使用 primary，高潮圆环使用 stamp',
                              LyricsStageMode.floatingName =>
                                '当前字使用 primary，打印印章使用 stamp',
                              _ => '当前高亮字使用歌曲专属 primary 配色',
                            },
                      value: preferences.aiColorEnabled,
                      isLoading: aiPaletteState?.isLoading == true,
                      onChanged: (enabled) => unawaited(
                        _setAiColorEnabled(context, ref, currentSong, enabled),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LyricsSettingsSection(
                title: '显示样式',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LyricsOptionLabel(title: '颜色'),
                    const SizedBox(height: 8),
                    LyricsChoiceGrid(
                      children: [
                        for (final mode in LyricsColorMode.values)
                          LyricsChoiceButton(
                            label: mode.label,
                            icon: _iconForColorMode(mode),
                            selected: preferences.colorMode == mode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              unawaited(
                                ref
                                    .read(
                                      lyricsPersonalizationProvider.notifier,
                                    )
                                    .setColorMode(mode),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (preferences.stageMode == LyricsStageMode.defaultScroll) ...[
                const SizedBox(height: 24),
                LyricsSettingsSection(
                  title: '非当前行',
                  child: Column(
                    children: [
                      LyricsSliderRow(
                        icon: Icons.blur_on_rounded,
                        value: inactiveBlur,
                        max: 12,
                        divisions: 12,
                        label: inactiveBlur.toStringAsFixed(0),
                        valueText: inactiveBlur <= 0.05
                            ? '关闭'
                            : inactiveBlur.toStringAsFixed(0),
                        onChanged: (value) => ref
                            .read(glassEffectProvider.notifier)
                            .setBlur(
                              inactiveLyricsTarget,
                              value,
                              persist: false,
                            ),
                        onChangeEnd: (value) => ref
                            .read(glassEffectProvider.notifier)
                            .setBlur(inactiveLyricsTarget, value),
                      ),
                      LyricsSliderRow(
                        icon: Icons.opacity_rounded,
                        value: inactiveOpacity,
                        max: 1,
                        divisions: 20,
                        label: '${(inactiveOpacity * 100).round()}%',
                        valueText: '${(inactiveOpacity * 100).round()}%',
                        onChanged: (value) => ref
                            .read(glassEffectProvider.notifier)
                            .setOpacity(
                              inactiveLyricsTarget,
                              value,
                              persist: false,
                            ),
                        onChangeEnd: (value) => ref
                            .read(glassEffectProvider.notifier)
                            .setOpacity(inactiveLyricsTarget, value),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              LyricsSettingsSection(
                title: '设置面板',
                child: Column(
                  children: [
                    LyricsSliderRow(
                      icon: Icons.blur_on_rounded,
                      value: drawerBlur.clamp(0.0, 30.0).toDouble(),
                      max: 30,
                      divisions: 15,
                      label: drawerBlur.toStringAsFixed(0),
                      valueText: drawerBlur <= 0.05
                          ? '关闭'
                          : drawerBlur.toStringAsFixed(0),
                      onChanged: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setBlur(drawerGlassTarget, value, persist: false),
                      onChangeEnd: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setBlur(drawerGlassTarget, value),
                    ),
                    LyricsSliderRow(
                      icon: Icons.opacity_rounded,
                      value: drawerTintOpacity.clamp(0.0, 1.0).toDouble(),
                      max: 1,
                      divisions: 20,
                      label: '${(drawerTintOpacity * 100).round()}%',
                      valueText: '${(drawerTintOpacity * 100).round()}%',
                      onChanged: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setOpacity(drawerGlassTarget, value, persist: false),
                      onChangeEnd: (value) => ref
                          .read(glassEffectProvider.notifier)
                          .setOpacity(drawerGlassTarget, value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LyricsSettingsSection(
                title: '缓存管理',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLyricsTarget ? '仅操作当前歌词来源。' : '播放歌曲后可管理缓存。',
                      style: context.textBodySmall.copyWith(
                        color: context.secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: LyricsActionButton(
                            onPressed: hasLyricsTarget
                                ? () => unawaited(
                                    _refreshCurrentLyrics(context, ref),
                                  )
                                : null,
                            icon: Icons.refresh_rounded,
                            label: '刷新歌词',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LyricsActionButton(
                            onPressed: hasLyricsTarget
                                ? () => unawaited(
                                    _clearCurrentLyrics(context, ref),
                                  )
                                : null,
                            icon: Icons.delete_outline_rounded,
                            label: '清除缓存',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCustomFontTap(
    BuildContext context,
    WidgetRef ref,
    LyricsPersonalizationState preferences,
  ) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(lyricsPersonalizationProvider.notifier);
    if (preferences.hasCustomFont &&
        preferences.fontFamily != LyricsFontFamily.custom) {
      await notifier.setFontFamily(LyricsFontFamily.custom);
      if (context.mounted) {
        showAppToast(context, '已使用自定义字体', replaceCurrent: true);
      }
      return;
    }

    final picked = await notifier.pickCustomFont();
    if (!context.mounted || picked == null) return;
    showAppToast(
      context,
      picked ? '自定义字体已更新' : '字体加载失败，请选择有效的 .ttf 文件',
      replaceCurrent: true,
    );
  }

  Future<void> _setAiColorEnabled(
    BuildContext context,
    WidgetRef ref,
    Song? song,
    bool enabled,
  ) async {
    HapticFeedback.selectionClick();
    final controller = ref.read(lyricsAiPaletteControllerProvider);
    if (!enabled) {
      await controller.disable();
      return;
    }
    final result = await controller.enable(song);
    if (!context.mounted) return;
    final message = switch (result) {
      LyricsAiPaletteActivationResult.applied => '已应用当前歌曲的 AI 配色',
      LyricsAiPaletteActivationResult.noServer => '连接音乐服务器后才能生成 AI 配色',
      LyricsAiPaletteActivationResult.configurationLoading =>
        'DeepSeek 配置正在读取，请稍后重试',
      LyricsAiPaletteActivationResult.missingApiKey =>
        '请先在“小Jo同学”中配置 DeepSeek API Key',
      LyricsAiPaletteActivationResult.generationFailed => 'AI 配色生成失败，已继续使用默认颜色',
    };
    showAppToast(context, message, replaceCurrent: true);
  }

  Future<void> _refreshCurrentLyrics(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final song = ref.read(playerProvider).currentSong;
    final api = ref.read(subsonicApiProvider);
    if (song == null || api == null) return;
    final source = ref.read(lyricsSourceForSongProvider(song));
    try {
      await LyricsService(
        api: api,
        dio: ref.read(dioProvider),
      ).fetch(song, forceRefresh: true, source: source);
      invalidateLyricsMemoryCache(api, song, source: source);
      ref.invalidate(lyricsProvider(song));
      await ref.read(lyricsProvider(song).future);
      if (context.mounted) {
        showAppToast(context, '已重新获取${source.label}', replaceCurrent: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '歌词重新获取失败', replaceCurrent: true);
      }
    }
  }

  Future<void> _clearCurrentLyrics(BuildContext context, WidgetRef ref) async {
    final song = ref.read(playerProvider).currentSong;
    final api = ref.read(subsonicApiProvider);
    if (song == null || api == null) return;
    final source = ref.read(lyricsSourceForSongProvider(song));
    try {
      await LyricsService(
        api: api,
        dio: ref.read(dioProvider),
      ).clearCachedLyrics(song, source: source);
      invalidateLyricsMemoryCache(api, song, source: source);
      if (context.mounted) {
        showAppToast(context, '已清除${source.label}缓存', replaceCurrent: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '歌词缓存清除失败', replaceCurrent: true);
      }
    }
  }

  Future<void> _setCurrentLyricsSource(
    BuildContext context,
    WidgetRef ref,
    LyricsSource source,
  ) async {
    final song = ref.read(playerProvider).currentSong;
    final api = ref.read(subsonicApiProvider);
    if (song == null || api == null) return;
    try {
      await ref
          .read(lyricsSourceOverridesProvider.notifier)
          .setSourceFor(api, song, source);
      await ref.read(lyricsProvider(song).future);
      if (context.mounted) {
        showAppToast(context, '本首歌已切换为${source.label}', replaceCurrent: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '歌词来源切换失败', replaceCurrent: true);
      }
    }
  }

  String _customFontLabel(LyricsPersonalizationState preferences) {
    final name = preferences.customFontName;
    if (name == null || name.isEmpty) return '选择 .ttf';
    const maxLength = 14;
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength - 1)}…';
  }

  String _lyricsSourceLabel(LyricsSource source) {
    return switch (source) {
      LyricsSource.amll => '自动优选',
      LyricsSource.embedded => '仅内嵌',
    };
  }

  String _lyricsAlignmentLabel(LyricsAlignmentMode alignment) {
    return switch (alignment) {
      LyricsAlignmentMode.center => '居中',
      LyricsAlignmentMode.left => '左对齐',
      LyricsAlignmentMode.right => '右对齐',
    };
  }

  IconData _iconForColorMode(LyricsColorMode mode) {
    return switch (mode) {
      LyricsColorMode.system => Icons.brightness_auto_rounded,
      LyricsColorMode.black => Icons.circle_rounded,
      LyricsColorMode.white => Icons.circle_outlined,
      LyricsColorMode.dynamicLight => Icons.palette_outlined,
    };
  }

  IconData _iconForAlignment(LyricsAlignmentMode alignment) {
    return switch (alignment) {
      LyricsAlignmentMode.center => Icons.format_align_center_rounded,
      LyricsAlignmentMode.left => Icons.format_align_left_rounded,
      LyricsAlignmentMode.right => Icons.format_align_right_rounded,
    };
  }

  IconData _iconForStageMode(LyricsStageMode mode) {
    return switch (mode) {
      LyricsStageMode.defaultScroll => Icons.view_agenda_outlined,
      LyricsStageMode.flowingLight => Icons.auto_awesome_rounded,
      LyricsStageMode.floatingName => Icons.blur_circular_rounded,
      LyricsStageMode.chorus => Icons.groups_2_outlined,
    };
  }

  IconData _iconForFontFamily(LyricsFontFamily family) {
    return switch (family) {
      LyricsFontFamily.system => Icons.text_fields_rounded,
      LyricsFontFamily.custom => Icons.upload_file_rounded,
    };
  }
}
