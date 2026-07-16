import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum DirectionalAnchorScrollDirection { up, down }

/// Paint-only viewport entry effect shared by library and home cards.
class DirectionalAnchorReveal extends StatefulWidget {
  static const double visibilityThreshold = .15;
  static const Duration duration = Duration(milliseconds: 520);
  static const Curve scaleCurve = Cubic(.2, .8, .2, 1);

  final ScrollController controller;
  final ValueListenable<DirectionalAnchorScrollDirection> scrollDirection;
  final Listenable visibilityRequest;
  final double topInset;
  final double? hiddenScale;
  final Widget child;

  const DirectionalAnchorReveal({
    super.key,
    required this.controller,
    required this.scrollDirection,
    required this.visibilityRequest,
    required this.topInset,
    required this.child,
    this.hiddenScale,
  });

  @override
  State<DirectionalAnchorReveal> createState() =>
      _DirectionalAnchorRevealState();
}

class _DirectionalAnchorRevealState extends State<DirectionalAnchorReveal> {
  bool _isVisible = false;
  bool _visibilityCheckScheduled = false;
  Alignment _scaleAlignment = Alignment.topCenter;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
    widget.visibilityRequest.addListener(_handleVisibilityRequest);
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant DirectionalAnchorReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
    if (oldWidget.visibilityRequest != widget.visibilityRequest) {
      oldWidget.visibilityRequest.removeListener(_handleVisibilityRequest);
      widget.visibilityRequest.addListener(_handleVisibilityRequest);
    }
    _scheduleVisibilityCheck();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    widget.visibilityRequest.removeListener(_handleVisibilityRequest);
    super.dispose();
  }

  void _handleScroll() => _scheduleVisibilityCheck();

  void _handleVisibilityRequest() => _scheduleVisibilityCheck();

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      _updateVisibility();
    });
  }

  void _updateVisibility() {
    if (!mounted || !widget.controller.hasClients) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final cardRect = origin & renderObject.size;
    final viewportRect = Rect.fromLTRB(
      0,
      widget.topInset,
      mediaQuery.size.width,
      mediaQuery.size.height,
    );
    final intersection = cardRect.intersect(viewportRect);
    final cardArea = cardRect.width * cardRect.height;
    final visibleArea = intersection.width <= 0 || intersection.height <= 0
        ? 0.0
        : intersection.width * intersection.height;
    final visibleFraction = cardArea <= 0 ? 0.0 : visibleArea / cardArea;

    // Reveal after 15% enters, then stay visible until fully outside.
    final shouldBeVisible = _isVisible
        ? visibleFraction > 0
        : visibleFraction >= DirectionalAnchorReveal.visibilityThreshold;
    if (shouldBeVisible == _isVisible) return;

    setState(() {
      if (shouldBeVisible) {
        _scaleAlignment =
            widget.scrollDirection.value ==
                DirectionalAnchorScrollDirection.down
            ? Alignment.topCenter
            : Alignment.bottomCenter;
      }
      _isVisible = shouldBeVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return RepaintBoundary(child: widget.child);
    }

    final hiddenScale = widget.hiddenScale;
    final revealedChild = hiddenScale == null
        ? widget.child
        : AnimatedScale(
            scale: _isVisible ? 1 : hiddenScale,
            alignment: _scaleAlignment,
            duration: DirectionalAnchorReveal.duration,
            curve: DirectionalAnchorReveal.scaleCurve,
            child: widget.child,
          );

    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: _isVisible ? 1 : 0,
        duration: DirectionalAnchorReveal.duration,
        curve: Curves.easeOut,
        child: revealedChild,
      ),
    );
  }
}
