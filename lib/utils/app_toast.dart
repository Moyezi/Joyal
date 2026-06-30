import 'dart:async';
import 'package:flutter/material.dart';

import '../config/theme.dart';

OverlayEntry? _currentToastEntry;

void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  bool replaceCurrent = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  if (replaceCurrent || _currentToastEntry != null) {
    _currentToastEntry?.remove();
    _currentToastEntry = null;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AppToastOverlay(
      message: message,
      duration: duration,
      onDismissed: () {
        if (_currentToastEntry == entry) {
          _currentToastEntry = null;
        }
        entry.remove();
      },
    ),
  );

  _currentToastEntry = entry;
  overlay.insert(entry);
}

class _AppToastOverlay extends StatefulWidget {
  const _AppToastOverlay({
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay> {
  static const Duration _fadeDuration = Duration(milliseconds: 180);

  bool _visible = false;
  bool _dismissed = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
      _dismissTimer = Timer(widget.duration, _hide);
    });
  }

  void _hide() {
    if (!mounted || _dismissed) return;
    setState(() => _visible = false);
  }

  void _dismiss() {
    if (_visible || _dismissed) return;
    _dismissed = true;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final textStyle = TextStyle(
      color: dark ? AppTheme.darkBodyPrimary : AppTheme.primaryText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxWidth = (screenWidth - 48.0).clamp(96.0, 360.0);
    final minWidth = maxWidth < 96.0 ? maxWidth : 96.0;
    final allowMultipleLines = widget.message.runes.length >= 10;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + 88,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _fadeDuration,
            curve: Curves.easeOut,
            onEnd: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: minWidth,
                  maxWidth: maxWidth,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? AppTheme.darkSurfaceVariant
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  widget.message,
                  style: textStyle,
                  textAlign: TextAlign.center,
                  maxLines: allowMultipleLines ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
