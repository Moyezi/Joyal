import 'package:flutter/material.dart';

import 'theme.dart';

/// Context-aware theme accessors.
///
/// Use these instead of `AppTheme.primaryText` / `AppTheme.headlineLarge` etc.
/// so colors and text styles automatically adapt to the current brightness.
extension ThemeContext on BuildContext {
  // ━━━ Colors ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Color get primaryColor => AppTheme.primaryColorOf(this);
  Color get secondaryColor => AppTheme.secondaryColorOf(this);
  Color get surfaceColor => AppTheme.surfaceColorOf(this);
  Color get backgroundColor => AppTheme.backgroundColorOf(this);
  Color get surfaceHighlightColor =>
      AppTheme.surfaceHighlightColorOf(this);
  Color get favoriteRedColor => AppTheme.favoriteRedColorOf(this);

  // ━━━ Text Styles ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  TextStyle get textHeadlineLarge =>
      Theme.of(this).textTheme.headlineLarge!;
  TextStyle get textHeadlineMedium =>
      Theme.of(this).textTheme.headlineMedium!;
  TextStyle get textTitleLarge =>
      Theme.of(this).textTheme.titleLarge!;
  TextStyle get textTitleMedium =>
      Theme.of(this).textTheme.titleMedium!;
  TextStyle get textBodyLarge =>
      Theme.of(this).textTheme.bodyLarge!;
  TextStyle get textBodyMedium =>
      Theme.of(this).textTheme.bodyMedium!;
  TextStyle get textBodySmall =>
      Theme.of(this).textTheme.bodySmall!;
  TextStyle get textCaption =>
      Theme.of(this).textTheme.labelSmall!;
}
