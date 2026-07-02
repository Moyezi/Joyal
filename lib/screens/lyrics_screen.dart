import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_context.dart';
import '../models/lyrics.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/dynamic_album_background.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const LyricsScreen({super.key, this.onBack});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final song = player.currentSong;
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = song != null && api != null && song.coverArt.isNotEmpty
        ? api.getCoverArtUrl(song.coverArt)
        : '';

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: DynamicAlbumBackground(
        coverArtId: song?.coverArt ?? '',
        coverUrl: coverUrl,
        motionSeed: song?.id,
        child: song == null
            ? const SafeArea(
                child: Center(
                  child: Text('\u6682\u65e0\u64ad\u653e\u6b4c\u66f2'),
                ),
              )
            : ref
                  .watch(lyricsProvider(song))
                  .when(
                    loading: () {
                      return const SafeArea(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    error: (error, stackTrace) {
                      return SafeArea(
                        child: _Message(
                          icon: Icons.cloud_off_outlined,
                          text: '\u6b4c\u8bcd\u52a0\u8f7d\u5931\u8d25',
                          detail: error.toString(),
                        ),
                      );
                    },
                    data: (lyrics) {
                      if (lyrics.isEmpty) {
                        return const SafeArea(
                          child: _Message(
                            icon: Icons.lyrics_outlined,
                            text: '\u6682\u65e0\u6b4c\u8bcd',
                            detail:
                                '\u5f53\u524d\u670d\u52a1\u5668\u672a\u63d0\u4f9b\u8fd9\u9996\u6b4c\u7684\u6b4c\u8bcd',
                          ),
                        );
                      }
                      return _LyricsList(
                        data: lyrics,
                        position: player.position,
                        title: song.title,
                        artist: song.artist,
                        onSeek: (position) {
                          unawaited(
                            ref.read(playerProvider.notifier).seek(position),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

class _LyricsList extends StatefulWidget {
  final LyricsData data;
  final Duration position;
  final String title;
  final String artist;
  final ValueChanged<Duration> onSeek;

  const _LyricsList({
    required this.data,
    required this.position,
    required this.title,
    required this.artist,
    required this.onSeek,
  });

  @override
  State<_LyricsList> createState() => _LyricsListState();
}

class _LyricsListState extends State<_LyricsList> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _lineKeys;
  Timer? _resumeTimer;
  bool _userBrowsing = false;
  int _lastCenteredIndex = -1;

  LyricsData get data => widget.data;
  Duration get position => widget.position;

  int get _activeIndex => activeLyricIndex(data, position);

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(data.lines.length, (_) => GlobalKey());
    _scheduleCenter();
  }

  @override
  void didUpdateWidget(covariant _LyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != data) {
      _lineKeys = List.generate(data.lines.length, (_) => GlobalKey());
      _lastCenteredIndex = -1;
    }
    if (!_userBrowsing && _activeIndex != _lastCenteredIndex) {
      _scheduleCenter();
    }
  }

  void _scheduleCenter({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (_userBrowsing && !force)) return;
      _centerActiveLine();
    });
  }

  void _centerActiveLine() {
    final index = _activeIndex;
    if (index < 0 || index >= _lineKeys.length) return;
    final lineContext = _lineKeys[index].currentContext;
    if (lineContext == null) {
      if (!_scrollController.hasClients || data.lines.length < 2) return;
      final approximate =
          _scrollController.position.maxScrollExtent *
          index /
          (data.lines.length - 1);
      _scrollController
          .animateTo(
            approximate.clamp(
              _scrollController.position.minScrollExtent,
              _scrollController.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (!mounted) return;
            final resolvedContext = _lineKeys[index].currentContext;
            if (resolvedContext != null && resolvedContext.mounted) {
              Scrollable.ensureVisible(
                resolvedContext,
                alignment: 0.5,
                duration: const Duration(milliseconds: 180),
              );
            }
          });
      _lastCenteredIndex = index;
      return;
    }
    _lastCenteredIndex = index;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _resumeTimer?.cancel();
      _userBrowsing = true;
    } else if (notification is ScrollEndNotification && _userBrowsing) {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _userBrowsing = false);
        _scheduleCenter(force: true);
      });
    }
    return false;
  }

  void _seekToLine(LyricLine line) {
    final start = line.start;
    if (start == null) return;
    _resumeTimer?.cancel();
    _userBrowsing = false;
    widget.onSeek(start);
    _scheduleCenter(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final activeColor = context.primaryColor;
    final inactiveColor = isDark
        ? context.secondaryColor
        : context.primaryColor.withValues(alpha: 0.42);
    final topInset = MediaQuery.paddingOf(context).top;
    final headerReserve = MediaQuery.textScalerOf(context).scale(52) + 64;
    final lyricsTop = topInset + headerReserve;
    final titleTop = topInset + 18;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          top: lyricsTop,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                22,
                0,
                22,
                MediaQuery.sizeOf(context).height * 0.42,
              ),
              itemCount: data.lines.length,
              itemBuilder: (context, lineIndex) {
                final line = data.lines[lineIndex];
                final isActive = lineIndex == active;
                final text = line.text.isEmpty ? ' ' : line.text;
                final canSeek = line.start != null;
                final activeStyle = context.textHeadlineMedium.copyWith(
                  fontSize: 30,
                  height: 1.35,
                  color: activeColor,
                  fontWeight: FontWeight.w800,
                );
                final inactiveScale = 21 / activeStyle.fontSize!;
                final distance = active < 0
                    ? 0
                    : (lineIndex - active).abs().clamp(0, 6);
                final blurSigma = isActive
                    ? 0.0
                    : (distance * 0.95).clamp(0.0, 4.8);
                return GestureDetector(
                  key: _lineKeys[lineIndex],
                  behavior: HitTestBehavior.translucent,
                  onTap: canSeek ? () => _seekToLine(line) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: AnimatedScale(
                      scale: isActive ? 1 : inactiveScale,
                      alignment: Alignment.centerLeft,
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      child: _LyricDepthFilteredLine(
                        blurSigma: blurSigma,
                        child: Text(
                          text,
                          style: activeStyle.copyWith(
                            color: isActive ? activeColor : inactiveColor,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const _LyricsGlassDepthOverlay(),
        Padding(
          padding: EdgeInsets.fromLTRB(22, titleTop, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTitleLarge.copyWith(
                  color: activeColor.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textBodyMedium.copyWith(
                  color: activeColor.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

class _LyricDepthFilteredLine extends StatelessWidget {
  final double blurSigma;
  final Widget child;

  const _LyricDepthFilteredLine({required this.blurSigma, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: blurSigma),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, sigma, child) {
        if (sigma <= 0.05) return child!;
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _LyricsGlassDepthOverlay extends StatelessWidget {
  const _LyricsGlassDepthOverlay();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark ? Colors.black : Colors.white;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final bandHeight = (height * 0.34).clamp(120.0, 220.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _GlassFadeBand(
                  height: bandHeight,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  sigma: 13,
                  tint: tint,
                  tintAlpha: isDark ? 0.22 : 0.18,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _GlassFadeBand(
                  height: bandHeight,
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  sigma: 15,
                  tint: tint,
                  tintAlpha: isDark ? 0.30 : 0.26,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassFadeBand extends StatelessWidget {
  final double height;
  final Alignment begin;
  final Alignment end;
  final double sigma;
  final Color tint;
  final double tintAlpha;

  const _GlassFadeBand({
    required this.height,
    required this.begin,
    required this.end,
    required this.sigma,
    required this.tint,
    required this.tintAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: begin,
              end: end,
              colors: const [Colors.white, Colors.transparent],
              stops: const [0.12, 1],
            ).createShader(bounds);
          },
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: [
                    tint.withValues(alpha: tintAlpha),
                    tint.withValues(alpha: 0),
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String detail;

  const _Message({
    required this.icon,
    required this.text,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: context.secondaryColor),
            const SizedBox(height: 16),
            Text(text, style: context.textHeadlineMedium),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: context.textBodyMedium.copyWith(
                color: context.secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
