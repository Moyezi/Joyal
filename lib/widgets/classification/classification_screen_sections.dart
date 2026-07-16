import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../models/song_highlight.dart';
import '../../providers/lyrics_ai_palette_provider.dart';
import '../../providers/song_highlight_provider.dart';
import '../album_cover.dart';

class JoHeader extends StatelessWidget {
  final int classifiedCount;
  final int totalCount;
  final int? highlightCount;
  final int? paletteCount;

  const JoHeader({
    super.key,
    required this.classifiedCount,
    required this.totalCount,
    required this.highlightCount,
    required this.paletteCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconDecodeSize = (60 * MediaQuery.devicePixelRatioOf(context))
        .round();
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
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              isDark ? 'Night_Joicon.png' : 'Day_Joicon.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              cacheWidth: iconDecodeSize,
              cacheHeight: iconDecodeSize,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你的音乐整理台', style: context.textTitleLarge),
                const SizedBox(height: 3),
                Text('标签、高潮与歌词配色均保存在本机。', style: context.textBodySmall),
                const SizedBox(height: AppTheme.spacingSM),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _HeaderMetric(
                        label: '标签',
                        value: '$classifiedCount/$totalCount',
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      flex: 3,
                      child: _HeaderMetric(
                        label: '高潮',
                        value: highlightCount?.toString() ?? '—',
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      flex: 3,
                      child: _HeaderMetric(
                        label: '配色',
                        value: paletteCount?.toString() ?? '—',
                      ),
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
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        maxLines: 1,
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
      ),
    );
  }
}

class JoTabBar extends StatelessWidget {
  final TabController controller;

  const JoTabBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
      child: TabBar(
        controller: controller,
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
          Tab(text: '配色'),
          Tab(text: '服务'),
        ],
      ),
    );
  }
}

class RecordsLoading extends StatelessWidget {
  final String label;

  const RecordsLoading({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(label, style: context.textBodySmall),
          ],
        ),
      ),
    );
  }
}

class RecordsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const RecordsSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      style: context.textBodyLarge.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: context.textBodyMedium,
        prefixIcon: Icon(Icons.search_rounded, color: context.secondaryColor),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清空搜索',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
        filled: true,
        fillColor: context.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class EmptyRecordsSearch extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const EmptyRecordsSearch({
    super.key,
    required this.query,
    required this.onClear,
  });

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
            Icons.search_off_rounded,
            size: 42,
            color: context.secondaryColor,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text('没有找到相关记录', style: context.textTitleMedium),
          const SizedBox(height: 4),
          Text(
            '没有与“$query”匹配的歌曲、歌手或专辑',
            textAlign: TextAlign.center,
            style: context.textBodySmall,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          TextButton(onPressed: onClear, child: const Text('清空搜索')),
        ],
      ),
    );
  }
}

class TaskStatusPanel extends StatelessWidget {
  final String statusText;
  final String detailText;
  final double progress;
  final bool isRunning;

  const TaskStatusPanel({
    super.key,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTitleMedium,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                detailText,
                maxLines: 1,
                style: context.textBodySmall.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: isRunning && progress <= 0 ? null : progress.clamp(0, 1),
            ),
          ),
        ],
      ),
    );
  }
}

class HighlightSongCard extends StatelessWidget {
  final RecognizedSongHighlight entry;
  final String coverUrl;
  final VoidCallback onDelete;

  const HighlightSongCard({
    super.key,
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

class EmptyHighlights extends StatelessWidget {
  const EmptyHighlights({super.key});

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

class HighlightsError extends StatelessWidget {
  final VoidCallback onRetry;
  const HighlightsError({super.key, required this.onRetry});

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

class LyricsPaletteSongCard extends StatelessWidget {
  final RecognizedLyricsAiPalette entry;
  final String coverUrl;
  final VoidCallback onDelete;

  const LyricsPaletteSongCard({
    super.key,
    required this.entry,
    required this.coverUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final song = entry.song;
    final palette = entry.palette;
    final visibleKeywords = palette.keywords.take(6).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                if (visibleKeywords.isNotEmpty) ...[
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final keyword in visibleKeywords)
                        _KeywordColorChip(
                          text: keyword.text,
                          color: Color(keyword.color),
                        ),
                      if (palette.keywords.length > visibleKeywords.length)
                        _KeywordColorChip(
                          text:
                              '+${palette.keywords.length - visibleKeywords.length}',
                          color: context.secondaryColor,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${palette.keywords.length} 个关键词 · ${palette.model} · ${_formatPaletteDate(palette.generatedAt)}',
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
            tooltip: '清除这首歌的 AI 歌词配色',
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _KeywordColorChip extends StatelessWidget {
  final String text;
  final Color color;

  const _KeywordColorChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(text, style: context.textCaption.copyWith(color: color)),
    );
  }
}

class EmptyLyricsPalettes extends StatelessWidget {
  const EmptyLyricsPalettes({super.key});

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
          Icon(Icons.palette_outlined, size: 42, color: context.secondaryColor),
          const SizedBox(height: AppTheme.spacingSM),
          Text('还没有 AI 歌词配色', style: context.textTitleMedium),
          const SizedBox(height: 4),
          Text(
            '在歌词个性化的“文字”栏开启 AI 文字配色后，生成结果会保存在本机并显示在这里。',
            textAlign: TextAlign.center,
            style: context.textBodySmall,
          ),
        ],
      ),
    );
  }
}

class LyricsPalettesError extends StatelessWidget {
  final VoidCallback onRetry;
  const LyricsPalettesError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('歌词配色记录读取失败，重新加载'),
      ),
    );
  }
}

class PrivacyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const PrivacyNote({super.key, required this.icon, required this.text});

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

String _formatPaletteDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

ButtonStyle classificationPrimaryActionButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    backgroundColor: context.surfaceHighlightColor,
    foregroundColor: context.primaryColor,
    disabledBackgroundColor: context.surfaceHighlightColor.withValues(
      alpha: 0.52,
    ),
    disabledForegroundColor: context.secondaryColor.withValues(alpha: 0.62),
    minimumSize: const Size(0, 50),
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
    elevation: 0,
    textStyle: context.textTitleMedium,
  );
}

ButtonStyle classificationSecondaryActionButtonStyle(
  BuildContext context, {
  Color? foregroundColor,
}) {
  final color = foregroundColor ?? context.secondaryColor;
  return TextButton.styleFrom(
    foregroundColor: color,
    disabledForegroundColor: color.withValues(alpha: 0.38),
    minimumSize: const Size(0, 42),
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSM),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    textStyle: context.textBodyMedium.copyWith(fontWeight: FontWeight.w600),
  );
}

class ButtonLabel extends StatelessWidget {
  final String text;
  const ButtonLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

class ClassificationTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const ClassificationTextInput({
    super.key,
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

class ClassificationSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const ClassificationSettingTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Text(title, style: context.textTitleMedium),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textBodySmall,
            ),
          ),
        ],
      ),
      trailing: trailing,
    );
  }
}

class ClassificationSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ClassificationSwitchTile({
    super.key,
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
