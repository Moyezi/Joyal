import 'package:flutter/material.dart';

import '../../config/theme_context.dart';
import '../frosted_glass.dart';

class LyricsDrawerGlass extends StatelessWidget {
  final double blurSigma;
  final Color tintColor;
  final double tintOpacity;
  final Color borderColor;
  final double borderOpacity;
  final Widget child;

  const LyricsDrawerGlass({
    super.key,
    required this.blurSigma,
    required this.tintColor,
    required this.tintOpacity,
    required this.borderColor,
    required this.borderOpacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) {
      return _buildGlass(filtersSettled: true, child: child);
    }
    return AnimatedBuilder(
      animation: routeAnimation,
      child: child,
      builder: (context, child) => _buildGlass(
        filtersSettled: routeAnimation.status == AnimationStatus.completed,
        child: child!,
      ),
    );
  }

  Widget _buildGlass({required bool filtersSettled, required Widget child}) {
    final movingTintOpacity = tintOpacity < 0.72 ? 0.72 : tintOpacity;
    return FrostedGlass(
      // A moving, nearly full-screen backdrop/refraction filter is the worst
      // case for the GPU. Keep the glass tint during route movement, then
      // restore the full blur/refraction as soon as the drawer settles.
      blurSigma: filtersSettled ? blurSigma : 0,
      liquidGlassEnabled: filtersSettled ? null : false,
      borderRadius: BorderRadius.circular(28),
      tintColor: tintColor,
      tintOpacity: filtersSettled ? tintOpacity : movingTintOpacity,
      borderColor: borderColor,
      borderOpacity: borderOpacity,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
      child: child,
    );
  }
}

class LyricsSettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const LyricsSettingsSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTitleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class LyricsOptionLabel extends StatelessWidget {
  final String title;

  const LyricsOptionLabel({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textBodyMedium.copyWith(
        color: context.secondaryColor,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class LyricsSectionDivider extends StatelessWidget {
  const LyricsSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        height: 1,
        color: context.primaryColor.withValues(alpha: 0.08),
      ),
    );
  }
}

class LyricsToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const LyricsToggleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textBodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.textBodySmall.copyWith(
                    color: context.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class LyricsChoiceGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;

  const LyricsChoiceGrid({super.key, required this.children, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class LyricsActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  const LyricsActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? context.primaryColor : context.secondaryColor;

    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: context.primaryColor.withValues(
            alpha: enabled ? 0.055 : 0.025,
          ),
          side: BorderSide(
            color: foreground.withValues(alpha: enabled ? 0.22 : 0.08),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: context.textBodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class LyricsSliderRow extends StatelessWidget {
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final String valueText;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const LyricsSliderRow({
    super.key,
    required this.icon,
    required this.value,
    this.min = 0,
    required this.max,
    required this.divisions,
    required this.label,
    required this.valueText,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.secondaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: context.textBodySmall.copyWith(
              color: context.secondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class LyricsChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const LyricsChoiceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? context.primaryColor : context.secondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: compact ? 42 : 48,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: selected
                ? context.primaryColor.withValues(alpha: 0.14)
                : context.primaryColor.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? context.primaryColor.withValues(alpha: 0.36)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              SizedBox(width: compact ? 5 : 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact ? context.textBodySmall : context.textBodyMedium)
                          .copyWith(
                            color: foreground,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
