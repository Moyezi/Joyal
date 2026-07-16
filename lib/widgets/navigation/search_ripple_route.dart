import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef SearchCurtainPageBuilder =
    Widget Function(BuildContext context, Animation<double> animation);

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

/// Builds the large home-search transition.
///
/// The search capsule becomes a quiet "curtain rail": its top and bottom
/// edges travel to the screen edges while the destination search field keeps
/// the capsule's geometry. The destination owns the field's internal motion;
/// this route only clips the expanding page.
Route<T> buildSearchCurtainRoute<T>({
  required Rect sourceRect,
  required SearchCurtainPageBuilder builder,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(
      context,
      MediaQuery.disableAnimationsOf(context)
          ? const AlwaysStoppedAnimation<double>(1)
          : animation,
    ),
    transitionDuration: const Duration(milliseconds: 620),
    reverseTransitionDuration: const Duration(milliseconds: 480),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final reveal = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubicEmphasized,
        reverseCurve: Curves.easeInOutCubic,
      );
      return AnimatedBuilder(
        animation: reveal,
        child: RepaintBoundary(child: child),
        builder: (context, child) => ClipPath(
          clipBehavior: Clip.antiAlias,
          clipper: _SearchCurtainClipper(
            sourceRect: sourceRect,
            progress: reveal.value,
          ),
          child: child,
        ),
      );
    },
  );
}

class _SearchCurtainClipper extends CustomClipper<Path> {
  final Rect sourceRect;
  final double progress;

  const _SearchCurtainClipper({
    required this.sourceRect,
    required this.progress,
  });

  @override
  Path getClip(Size size) {
    final topProgress = Curves.easeOutCubic.transform(
      ((progress - .02) / .78).clamp(0.0, 1.0),
    );
    final bottomProgress = Curves.easeInOutCubic.transform(
      ((progress - .04) / .96).clamp(0.0, 1.0),
    );
    final sideProgress = Curves.easeInOutCubic.transform(
      ((progress - .18) / .72).clamp(0.0, 1.0),
    );
    final radiusProgress = Curves.easeInCubic.transform(
      ((progress - .42) / .58).clamp(0.0, 1.0),
    );

    final rect = Rect.fromLTRB(
      sourceRect.left * (1 - sideProgress),
      sourceRect.top * (1 - topProgress),
      sourceRect.right + (size.width - sourceRect.right) * sideProgress,
      sourceRect.bottom + (size.height - sourceRect.bottom) * bottomProgress,
    );
    final radius = Radius.circular(18 * (1 - radiusProgress));
    return Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
  }

  @override
  bool shouldReclip(covariant _SearchCurtainClipper oldClipper) {
    return oldClipper.sourceRect != sourceRect ||
        oldClipper.progress != progress;
  }
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
