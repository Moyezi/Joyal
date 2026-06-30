import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ━━━ Colors ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const Color background = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF8A8A8E);
  static const Color surfaceLight = Color(0xFFF3F4F6);
  static const Color surfaceHighlight = Color(0xFFF0F1F3);
  static const Color miniPlayerBg = Color(0xFF151922);
  static const Color miniPlayerText = Color(0xFFFFFFFF);
  static const Color favoriteRed = Color(0xFFE53935);
  static const Color waveformPlayed = Color(0xFF1A1A1A);
  static const Color waveformUnplayed = Color(0xFFD1D1D6);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // ━━━ Dark Mode Colors ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkFavoriteRed = Color(0xFFEF5350);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkBodyPrimary = Color(0xFFE0E0E0);
  static const Color darkSecondaryText = Color(0xFF9E9E9E);
  static const Color darkBodyText = Color(0xFF616161);

  // ━━━ Radii ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const double radiusLarge = 28.0;
  static const double radiusMedium = 18.0;
  static const double radiusSmall = 12.0;
  static const double radiusMini = 28.0;

  // ━━━ Spacing ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;

  // ━━━ Typography ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const TextStyle headlineLarge = TextStyle(
    color: primaryText,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    letterSpacing: -0.8,
  );

  static const TextStyle headlineMedium = TextStyle(
    color: primaryText,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    color: primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 18,
  );

  static const TextStyle titleMedium = TextStyle(
    color: primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  static const TextStyle bodyLarge = TextStyle(
    color: primaryText,
    fontSize: 16,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: secondaryText,
    fontSize: 14,
  );

  static const TextStyle bodySmall = TextStyle(
    color: secondaryText,
    fontSize: 12,
  );

  static const TextStyle caption = TextStyle(
    color: secondaryText,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  // ━━━ Dark Typography ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static final TextStyle darkHeadlineLarge = headlineLarge.copyWith(
    color: darkPrimaryText,
  );
  static final TextStyle darkHeadlineMedium = headlineMedium.copyWith(
    color: darkPrimaryText,
  );
  static final TextStyle darkTitleLarge = titleLarge.copyWith(
    color: darkPrimaryText,
  );
  static final TextStyle darkTitleMedium = titleMedium.copyWith(
    color: darkPrimaryText,
  );
  static final TextStyle darkBodyLarge = bodyLarge.copyWith(
    color: darkBodyPrimary,
  );
  static final TextStyle darkBodyMedium = bodyMedium.copyWith(
    color: darkSecondaryText,
  );
  static final TextStyle darkBodySmall = bodySmall.copyWith(
    color: darkSecondaryText,
  );
  static final TextStyle darkCaption = caption.copyWith(
    color: darkSecondaryText,
  );

  // ━━━ Context-Aware Color Resolution ━━━━━━━━━━━━━━━━━━━━━━

  static Color primaryColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkPrimaryText
      : primaryText;

  static Color secondaryColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSecondaryText
      : secondaryText;

  static Color surfaceColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSurface
      : surfaceLight;

  static Color backgroundColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkBackground
      : background;

  static Color surfaceHighlightColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSurfaceVariant
      : surfaceHighlight;

  static Color favoriteRedColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkFavoriteRed
      : favoriteRed;

  static SnackBarThemeData _snackBarTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
      backgroundColor: dark ? darkSurfaceVariant : background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      contentTextStyle: TextStyle(
        color: dark ? darkBodyPrimary : primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      actionTextColor: dark ? darkPrimaryText : primaryText,
      disabledActionTextColor: dark ? darkSecondaryText : secondaryText,
      closeIconColor: dark ? darkPrimaryText : primaryText,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  // ━━━ Theme Data ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        surface: background,
        onSurface: primaryText,
        primary: primaryText,
        onPrimary: Colors.white,
        secondary: secondaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: primaryText,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          color: primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primaryText,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      iconTheme: const IconThemeData(color: primaryText, size: 24),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: primaryText),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryText,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      textTheme: const TextTheme(
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      snackBarTheme: _snackBarTheme(Brightness.light),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        surface: darkBackground,
        onSurface: darkPrimaryText,
        primary: darkPrimaryText,
        onPrimary: Colors.black,
        secondary: darkSecondaryText,
        surfaceContainerHighest: darkSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkPrimaryText,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          color: darkPrimaryText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
        selectedItemColor: darkPrimaryText,
        unselectedItemColor: darkSecondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: IconThemeData(color: darkPrimaryText),
      textTheme: TextTheme(
        headlineLarge: darkHeadlineLarge,
        headlineMedium: darkHeadlineMedium,
        titleLarge: darkTitleLarge,
        titleMedium: darkTitleMedium,
        bodyLarge: darkBodyLarge,
        bodyMedium: darkBodyMedium,
        bodySmall: darkBodySmall,
        labelSmall: darkCaption,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      dividerColor: darkSurfaceVariant,
      snackBarTheme: _snackBarTheme(Brightness.dark),
    );
  }

  // ━━━ Shadows ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 30,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get diffuseShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 60,
      offset: const Offset(0, 20),
      spreadRadius: 5,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
