import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A standard top-bar search action that opens [pageBuilder] with a ripple.
class SearchRippleIconButton extends StatefulWidget {
  final WidgetBuilder pageBuilder;

  const SearchRippleIconButton({super.key, required this.pageBuilder});

  @override
  State<SearchRippleIconButton> createState() => _SearchRippleIconButtonState();
}

class _SearchRippleIconButtonState extends State<SearchRippleIconButton> {
  final GlobalKey _buttonKey = GlobalKey();
  bool _routeOpen = false;

  Future<void> _openSearch() async {
    if (_routeOpen) return;
    final buttonBox = _buttonKey.currentContext?.findRenderObject();
    final size = MediaQuery.sizeOf(context);
    final origin = buttonBox is RenderBox && buttonBox.hasSize
        ? buttonBox.localToGlobal(buttonBox.size.center(Offset.zero))
        : Offset(size.width - 40, MediaQuery.viewPaddingOf(context).top + 38);

    _routeOpen = true;
    try {
      await Navigator.of(context).push(
        buildSearchRippleRoute<void>(
          origin: origin,
          builder: widget.pageBuilder,
        ),
      );
    } finally {
      _routeOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _buttonKey,
      tooltip: '搜索',
      onPressed: _openSearch,
      icon: const Icon(Icons.search_rounded),
    );
  }
}

/// Builds a search route that reveals itself as a ripple from [origin].
Route<T> buildSearchRippleRoute<T>({
  required Offset origin,
  required WidgetBuilder builder,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final reveal = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: reveal,
        child: RepaintBoundary(child: child),
        builder: (context, child) {
          final progress = reveal.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipBehavior: Clip.antiAlias,
                clipper: _RippleRevealClipper(
                  origin: origin,
                  progress: progress,
                ),
                child: child,
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _RippleEdgePainter(
                    origin: origin,
                    progress: progress,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

double _maximumRevealRadius(Size size, Offset origin) {
  final horizontal = math.max(origin.dx, size.width - origin.dx);
  final vertical = math.max(origin.dy, size.height - origin.dy);
  return math.sqrt(horizontal * horizontal + vertical * vertical) + 2;
}

class _RippleRevealClipper extends CustomClipper<Path> {
  final Offset origin;
  final double progress;

  const _RippleRevealClipper({required this.origin, required this.progress});

  @override
  Path getClip(Size size) {
    final radius = _maximumRevealRadius(size, origin) * progress;
    return Path()..addOval(Rect.fromCircle(center: origin, radius: radius));
  }

  @override
  bool shouldReclip(covariant _RippleRevealClipper oldClipper) {
    return oldClipper.origin != origin || oldClipper.progress != progress;
  }
}

class _RippleEdgePainter extends CustomPainter {
  final Offset origin;
  final double progress;
  final Color color;

  const _RippleEdgePainter({
    required this.origin,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final radius = _maximumRevealRadius(size, origin) * progress;
    final fade = math.sin(progress * math.pi);
    final primaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: .16 * fade);
    final trailingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: .07 * fade);

    canvas.drawCircle(origin, radius, primaryPaint);
    canvas.drawCircle(origin, math.max(0, radius - 12), trailingPaint);
  }

  @override
  bool shouldRepaint(covariant _RippleEdgePainter oldDelegate) {
    return oldDelegate.origin != origin ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
