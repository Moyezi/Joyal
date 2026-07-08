import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../config/theme_context.dart';
import '../models/song.dart';
import '../providers/glass_effect_provider.dart';
import 'frosted_glass.dart';

/// A single row in a tracklist, following the design spec:
/// - Track number or animated spectrum icon when playing
/// - Song title (bold) and artist (grey)
/// - Duration on the right
/// - Highlighted background when this song is currently playing
class SongTile extends ConsumerWidget {
  final Song song;
  final int index;
  final bool isPlaying;
  final bool isDownloaded;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const SongTile({
    super.key,
    required this.song,
    required this.index,
    this.isPlaying = false,
    this.isDownloaded = false,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blurSigma = ref.watch(
      glassEffectProvider.select(
        (state) => state.blurFor(GlassEffectTarget.songCard),
      ),
    );
    final tintOpacity = ref.watch(
      glassEffectProvider.select(
        (state) => state.opacityFor(GlassEffectTarget.songCard),
      ),
    );
    final borderRadius = BorderRadius.circular(AppTheme.radiusMedium);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: isPlaying
                ? const _PlayingIndicator()
                : Text(
                    '${index + 1}'.padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: context.textBodyMedium,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: isPlaying
                      ? context.textTitleMedium.copyWith(
                          color: context.primaryColor,
                        )
                      : context.textBodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${song.artist}  •  ${song.formattedDuration}',
                  style: context.textBodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDownloaded) ...[
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF24A148),
              size: 19,
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                Icons.more_horiz,
                color: context.secondaryColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(borderRadius: borderRadius),
        child: isPlaying
            ? FrostedGlass(
                blurSigma: blurSigma,
                borderRadius: borderRadius,
                tintColor: context.surfaceColor,
                tintOpacity: tintOpacity,
                borderColor: context.primaryColor,
                borderOpacity: isDark ? 0.08 : 0.06,
                child: content,
              )
            : content,
      ),
    );
  }
}

/// Animated vertical bar spectrum indicator for the currently playing song.
///
/// Mimics a 4-bar equaliser bouncing animation.
class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(0, 0.6 + 0.4 * _controller.value),
            const SizedBox(width: 2),
            _bar(1, 0.3 + 0.7 * (1 - _controller.value)),
            const SizedBox(width: 2),
            _bar(2, 0.4 + 0.6 * _controller.value),
            const SizedBox(width: 2),
            _bar(3, 0.2 + 0.8 * (1 - _controller.value)),
          ],
        );
      },
    );
  }

  Widget _bar(int index, double fraction) {
    return Container(
      width: 3,
      height: 14 * fraction.clamp(0.2, 1.0),
      decoration: BoxDecoration(
        color: context.primaryColor,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
