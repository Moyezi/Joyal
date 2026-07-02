import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/theme_context.dart';

/// Shared fixed header used by the three primary navigation destinations.
///
/// Optionally accepts [searchAnimation] + [onSearchTap] to render an
/// animated search icon on the right side (used by HomeScreen).
class GlassTopBar extends StatelessWidget {
  final double height;
  final Widget child;
  final Animation<double>? searchAnimation;
  final VoidCallback? onSearchTap;
  final bool hasPageBackground;

  const GlassTopBar({
    super.key,
    required this.height,
    required this.child,
    this.searchAnimation,
    this.onSearchTap,
    this.hasPageBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final showSearch = searchAnimation != null && onSearchTap != null;
    final topInset = MediaQuery.paddingOf(context).top;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final topColor = hasPageBackground ? bg.withValues(alpha: .72) : bg;
    final middleColor = hasPageBackground ? bg.withValues(alpha: .64) : bg;
    final lowerColor = bg.withValues(alpha: hasPageBackground ? .42 : .76);
    final bottomColor = bg.withValues(alpha: hasPageBackground ? .20 : .54);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height + topInset,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.expand(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topColor, middleColor, lowerColor, bottomColor],
                  stops: const [0, .18, .56, 1],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: .3),
                  ),
                ),
              ),
            ),
            // Left: original child (greeting)
            Positioned(
              top: topInset,
              left: 0,
              right: 0,
              bottom: 0,
              child: child,
            ),
            // Right: search icon (only when searchAnimation is provided)
            if (showSearch)
              Positioned(
                right: 16,
                top: topInset,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: searchAnimation!,
                  builder: (context, _) {
                    final p = searchAnimation!.value;
                    return Opacity(
                      opacity: p,
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * p,
                        child: IconButton(
                          icon: Icon(
                            Icons.search_rounded,
                            color: context.primaryColor,
                          ),
                          onPressed: p > 0.01 ? onSearchTap : null,
                          tooltip: '搜索',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GlassTopBarTitleRow extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final double height;

  const GlassTopBarTitleRow({
    super.key,
    required this.title,
    this.actions = const [],
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
        child: Row(
          children: [
            Expanded(child: Text(title, style: context.textHeadlineLarge)),
            ...actions,
          ],
        ),
      ),
    );
  }
}
