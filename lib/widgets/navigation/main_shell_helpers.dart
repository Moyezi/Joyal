import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../cached_disk_image.dart';
import '../home_sidebar.dart';

class LibraryCanvasEdgeHero extends StatelessWidget {
  final String imagePath;
  final Alignment alignment;

  const LibraryCanvasEdgeHero({
    super.key,
    required this.imagePath,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    const width = 96.0;
    return Positioned(
      left: -width,
      top: MediaQuery.paddingOf(context).top + 104,
      width: width,
      height: 54,
      child: Hero(
        tag: libraryCanvasEdgeHeroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            alignment: alignment,
            cacheWidth: physicalImageCacheWidth(context, width),
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF282B2E)),
          ),
        ),
      ),
    );
  }
}

class StartupMask extends StatelessWidget {
  final bool isVisible;

  const StartupMask({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class VelocitySample {
  final Duration timestamp;
  final double deltaDx;
  const VelocitySample({required this.timestamp, required this.deltaDx});
}

class DrawerPane extends StatelessWidget {
  final Animation<double> animation;
  final double drawerWidth;
  final Widget child;

  const DrawerPane({
    super.key,
    required this.animation,
    required this.drawerWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final shouldPaint = animation.value > 0.001 || animation.isAnimating;
        return Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: drawerWidth,
          child: IgnorePointer(
            ignoring: !shouldPaint,
            child: TickerMode(
              enabled: shouldPaint,
              child: Offstage(offstage: !shouldPaint, child: child!),
            ),
          ),
        );
      },
    );
  }
}

class DrawerPreviewScrim extends StatelessWidget {
  final double progress;
  final double maxAlpha;
  final VoidCallback onTap;

  const DrawerPreviewScrim({
    super.key,
    required this.progress,
    required this.maxAlpha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: maxAlpha * progress),
      ),
    );
  }
}

class DrawerHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  bool Function(PointerDownEvent event)? shouldAcceptPointer;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event is! PointerDownEvent) return false;
    return (shouldAcceptPointer?.call(event) ?? false) &&
        super.isPointerAllowed(event);
  }
}

/// Wins the gesture arena as soon as a second finger is placed on the home
/// screen. Pointer positions are still observed by the surrounding [Listener]
/// for pinch detection, while descendant vertical and horizontal scrollables
/// are prevented from reacting to the same two-finger movement.
class TwoFingerBlockGestureRecognizer extends OneSequenceGestureRecognizer {
  bool Function(PointerDownEvent event)? shouldAcceptPointer;
  final Set<int> _pointers = <int>{};

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event is! PointerDownEvent) return false;
    return (shouldAcceptPointer?.call(event) ?? false) &&
        super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointers.add(event.pointer);
    if (_pointers.length >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers.clear();
    resolve(GestureDisposition.rejected);
  }

  @override
  String get debugDescription => 'home two-finger block';
}
