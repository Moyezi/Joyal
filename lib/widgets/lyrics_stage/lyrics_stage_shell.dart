import 'dart:async';

import 'package:flutter/material.dart';

/// Shared full-screen shell for independent lyrics stages.
///
/// The song header is deliberately an overlay so every stage can compose
/// itself against the complete phone viewport. A two-finger pinch opens the
/// existing in-place personalization drawer.
class LyricsStageShell extends StatefulWidget {
  final String title;
  final String artist;
  final Color foreground;
  final VoidCallback onOpenSettings;
  final Widget child;
  final Duration? headerVisibleDuration;
  final EdgeInsetsGeometry contentPadding;

  const LyricsStageShell({
    super.key,
    required this.title,
    required this.artist,
    required this.foreground,
    required this.onOpenSettings,
    required this.child,
    this.headerVisibleDuration,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 18),
  });

  @override
  State<LyricsStageShell> createState() => _LyricsStageShellState();
}

class _LyricsStageShellState extends State<LyricsStageShell> {
  final Map<int, Offset> _pointers = {};
  double? _startDistance;
  bool _opened = false;

  double? get _distance {
    if (_pointers.length < 2) return null;
    final points = _pointers.values.take(2).toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _startDistance = _distance;
      _opened = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length < 2 || _opened) return;
    final start = _startDistance;
    final current = _distance;
    if (start == null || current == null || start < 24) return;
    if ((current - start).abs() < 28 && (current / start - 1).abs() < 0.12) {
      return;
    }
    _opened = true;
    widget.onOpenSettings();
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _startDistance = null;
      _opened = false;
    } else {
      _startDistance = _distance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(padding: widget.contentPadding, child: widget.child),
          LyricsStageHeader(
            title: widget.title,
            artist: widget.artist,
            foreground: widget.foreground,
            visibleDuration: widget.headerVisibleDuration,
            padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 18),
          ),
        ],
      ),
    );
  }
}

/// Shared song/artist overlay used by every lyrics presentation mode.
///
/// A null [visibleDuration] keeps the header visible. This is also used while
/// the lyrics surface is still transitioning in; changing to a duration starts
/// the countdown only after the surface becomes the settled foreground.
class LyricsStageHeader extends StatefulWidget {
  final String title;
  final String artist;
  final Color foreground;
  final Duration? visibleDuration;
  final EdgeInsetsGeometry padding;

  const LyricsStageHeader({
    super.key,
    required this.title,
    required this.artist,
    required this.foreground,
    this.visibleDuration,
    required this.padding,
  });

  @override
  State<LyricsStageHeader> createState() => _LyricsStageHeaderState();
}

class _LyricsStageHeaderState extends State<LyricsStageHeader> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleFade();
  }

  @override
  void didUpdateWidget(covariant LyricsStageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibleDuration != widget.visibleDuration) {
      _visible = true;
      _scheduleFade();
    }
  }

  void _scheduleFade() {
    _timer?.cancel();
    final duration = widget.visibleDuration;
    if (duration == null) return;
    _timer = Timer(duration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeInOutCubic,
      child: IgnorePointer(
        child: Padding(
          padding: widget.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: widget.foreground.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: widget.foreground.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
