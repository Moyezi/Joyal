import 'dart:async';

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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              ),
        title: const Text('\u6b4c\u8bcd'),
      ),
      body: DynamicAlbumBackground(
        coverArtId: song?.coverArt ?? '',
        coverUrl: coverUrl,
        motionSeed: song?.id,
        child: SafeArea(
          child: song == null
              ? const Center(
                  child: Text('\u6682\u65e0\u64ad\u653e\u6b4c\u66f2'),
                )
              : ref
                    .watch(lyricsProvider(song))
                    .when(
                      loading: () {
                        return const Center(child: CircularProgressIndicator());
                      },
                      error: (error, stackTrace) {
                        return _Message(
                          icon: Icons.cloud_off_outlined,
                          text: '\u6b4c\u8bcd\u52a0\u8f7d\u5931\u8d25',
                          detail: error.toString(),
                        );
                      },
                      data: (lyrics) {
                        if (lyrics.isEmpty) {
                          return const _Message(
                            icon: Icons.lyrics_outlined,
                            text: '\u6682\u65e0\u6b4c\u8bcd',
                            detail:
                                '\u5f53\u524d\u670d\u52a1\u5668\u672a\u63d0\u4f9b\u8fd9\u9996\u6b4c\u7684\u6b4c\u8bcd',
                          );
                        }
                        return _LyricsList(
                          data: lyrics,
                          position: player.position,
                          title: song.title,
                          artist: song.artist,
                        );
                      },
                    ),
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

  const _LyricsList({
    required this.data,
    required this.position,
    required this.title,
    required this.artist,
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

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final activeColor = context.primaryColor;
    final inactiveColor = isDark
        ? context.secondaryColor
        : context.primaryColor.withValues(alpha: 0.42);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          28,
          24,
          28,
          MediaQuery.sizeOf(context).height * 0.42,
        ),
        itemCount: data.lines.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: context.textHeadlineLarge),
                  const SizedBox(height: 6),
                  Text(
                    widget.artist,
                    style: context.textTitleMedium.copyWith(
                      color: context.secondaryColor,
                    ),
                  ),
                ],
              ),
            );
          }
          final lineIndex = index - 1;
          final line = data.lines[lineIndex];
          final isActive = lineIndex == active;
          final text = line.text.isEmpty ? ' ' : line.text;
          final activeStyle = context.textHeadlineMedium.copyWith(
            fontSize: 30,
            height: 1.35,
            color: activeColor,
            fontWeight: FontWeight.w800,
          );
          final inactiveScale = 21 / activeStyle.fontSize!;
          return Padding(
            key: _lineKeys[lineIndex],
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AnimatedScale(
              scale: isActive ? 1 : inactiveScale,
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              child: Text(
                text,
                style: activeStyle.copyWith(
                  color: isActive ? activeColor : inactiveColor,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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
