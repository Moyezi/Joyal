# Dark Mode Color Adaptation — Joyal Music

**Date:** 2026-06-28  
**Status:** Design Approved  
**Builds on:** `2026-06-28-dark-mode-design.md` (theme toggle infrastructure)  
**Approach:** BuildContext extension + AppTheme brightness-aware resolvers

---

## 1. Problem

The dark mode infrastructure (`theme_provider.dart`, `darkTheme`, `AlbumVisualPalette` brightness-aware) is in place, but most widgets reference static `AppTheme` constants that are hardcoded to light-mode colors:

- `AppTheme.primaryText` → always `#1A1A1A` (black)
- `AppTheme.secondaryText` → always `#8A8A8E` (gray)
- `AppTheme.surfaceLight` → always `#F3F4F6` (light gray, looks white)
- `AppTheme.headlineLarge` → always `color: primaryText`

Search box, text, icons, and chips appear white/black regardless of theme mode.

## 2. Solution

### 2.1 Color Palette Refinement

| Semantic | Old Value | New Value | Usage |
|---|---|---|---|
| `darkPrimaryText` | `white 87%` (~`#DEDEDE`) | `#FFFFFF` | Headlines, emphasis |
| `darkBodyPrimary` (new) | — | `#E0E0E0` | Body text |
| `darkSecondaryText` | `white 60%` (~`#999999`) | `#9E9E9E` | Subtitles, hints, unselected tabs |
| `darkBodyText` | `white 38%` (~`#616161`) | *(retained)* | Tertiary / inactive |
| `darkBackground` | `#121212` | *(unchanged)* | Page background |
| `darkSurface` | `#1E1E1E` | *(unchanged)* | Cards, search box, chips |
| `darkSurfaceVariant` | `#2C2C2C` | *(unchanged)* | Dividers, elevated surfaces |

Dark text styles updated accordingly:
- `darkHeadlineLarge/Medium`, `darkTitleLarge/Medium` → `color: darkPrimaryText` (`#FFFFFF`)
- `darkBodyLarge` → `color: darkBodyPrimary` (`#E0E0E0`)
- `darkBodyMedium/Small`, `darkCaption` → `color: darkSecondaryText` (`#9E9E9E`)

### 2.2 Context-Aware Resolution

**`lib/config/theme.dart`** — new static resolver methods in `AppTheme`:

```dart
static Color primaryColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryText : primaryText;

static Color secondaryColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? darkSecondaryText : secondaryText;

static Color surfaceColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? darkSurface : surfaceLight;

static Color backgroundColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? darkBackground : background;

static Color surfaceHighlightColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? darkSurfaceVariant : surfaceHighlight;

static Color favoriteRedColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? darkFavoriteRed : favoriteRed;
```

**`lib/config/theme_context.dart`** (new file) — `BuildContext` extension:

```dart
import 'package:flutter/material.dart';
import 'theme.dart';

extension ThemeContext on BuildContext {
  // ━━━ Colors ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Color get primaryColor => AppTheme.primaryColorOf(this);
  Color get secondaryColor => AppTheme.secondaryColorOf(this);
  Color get surfaceColor => AppTheme.surfaceColorOf(this);
  Color get backgroundColor => AppTheme.backgroundColorOf(this);
  Color get surfaceHighlightColor => AppTheme.surfaceHighlightColorOf(this);
  Color get favoriteRedColor => AppTheme.favoriteRedColorOf(this);

  // ━━━ Text Styles ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TextStyle get textHeadlineLarge => Theme.of(this).textTheme.headlineLarge!;
  TextStyle get textHeadlineMedium => Theme.of(this).textTheme.headlineMedium!;
  TextStyle get textTitleLarge => Theme.of(this).textTheme.titleLarge!;
  TextStyle get textTitleMedium => Theme.of(this).textTheme.titleMedium!;
  TextStyle get textBodyLarge => Theme.of(this).textTheme.bodyLarge!;
  TextStyle get textBodyMedium => Theme.of(this).textTheme.bodyMedium!;
  TextStyle get textBodySmall => Theme.of(this).textTheme.bodySmall!;
  TextStyle get textCaption => Theme.of(this).textTheme.labelSmall!;
}
```

Text styles delegate to `Theme.of(context).textTheme`, which `darkTheme` already populates with dark variants.

### 2.3 Migration Pattern

| Before | After |
|---|---|
| `AppTheme.primaryText` | `context.primaryColor` |
| `AppTheme.secondaryText` | `context.secondaryColor` |
| `AppTheme.surfaceLight` | `context.surfaceColor` |
| `AppTheme.background` | `context.backgroundColor` |
| `AppTheme.surfaceHighlight` | `context.surfaceHighlightColor` |
| `AppTheme.favoriteRed` | `context.favoriteRedColor` |
| `AppTheme.headlineLarge` | `context.textHeadlineLarge` |
| `AppTheme.bodyMedium` | `context.textBodyMedium` |
| `AppTheme.titleLarge` | `context.textTitleLarge` |

Import `'../config/theme_context.dart'` in each migrated file.

## 3. Migration Plan

### Batch 1 — Infrastructure
- `lib/config/theme.dart` — color constants + resolver methods
- `lib/config/theme_context.dart` — new file, BuildContext extension

### Batch 2 — Shared Widgets (global impact)
- `lib/widgets/glass_top_bar.dart`
- `lib/widgets/bottom_nav.dart`
- `lib/widgets/song_tile.dart`
- `lib/widgets/album_cover.dart`

### Batch 3 — Primary Screens
- `lib/screens/home_screen.dart`
- `lib/screens/library_screen.dart`
- `lib/screens/hotlist_screen.dart`
- `lib/screens/search_screen.dart`

### Batch 4 — Secondary Screens
- `lib/screens/album_detail_screen.dart`
- `lib/screens/artist_detail_screen.dart`
- `lib/screens/now_playing_screen.dart`
- `lib/screens/settings_hub_screen.dart`
- `lib/screens/lyrics_screen.dart`
- `lib/screens/download_manager_screen.dart`
- `lib/screens/cache_management_screen.dart`
- `lib/widgets/song_actions_sheet.dart`
- `lib/widgets/home_sidebar.dart`

After each batch: `flutter analyze lib test` — zero errors.

## 4. Exclusions

- `mini_player.dart` — hardcoded `#151922`, intentionally theme-independent
- `album_visual_palette.dart` — already brightness-aware via `resolve(brightness:)`
- `dynamic_album_background.dart` — already uses `scaffoldBackgroundColor`

## 5. Verification

- `flutter analyze` — zero errors
- `flutter test` — all existing tests pass
- `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons` — builds successfully
- Manual: toggle dark mode in app, verify search box is `#1E1E1E`, text is readable, all three main pages look correct
