import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../config/theme_context.dart';
import '../../models/song_highlight.dart';
import '../../providers/song_highlight_provider.dart';
import '../album_cover.dart';

class JoHeader extends StatelessWidget {
  final int classifiedCount;
  final int totalCount;
  final int? highlightCount;

  const JoHeader({
    super.key,
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

class JoTabBar extends StatelessWidget {
  const JoTabBar({super.key});

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

ButtonStyle classificationFilledPillButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: const Size(0, 56),
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
    shape: const StadiumBorder(),
    textStyle: context.textTitleMedium,
  );
}

ButtonStyle classificationOutlinedPillButtonStyle(
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
      title: Text(title, style: context.textTitleMedium),
      subtitle: Text(subtitle, style: context.textBodySmall),
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
