# Dark Mode Color Refinement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all AppTheme color and text-style references context-aware so widgets automatically adapt to dark/light mode.

**Architecture:** Add brightness-aware static resolver methods to `AppTheme`, create a `BuildContext` extension (`ThemeContext`) with concise getters for colors and text styles, then migrate all widget files from `AppTheme.xxx` static references to `context.xxx`.

**Tech Stack:** Flutter / Dart, Material 3 theming, no new dependencies.

## Global Constraints

- `Theme.of(context).brightness` is the single source of truth for dark/light
- `mini_player.dart` uses `AppTheme.miniPlayerBg` (`#151922`) — intentionally theme-independent, do NOT migrate
- `spacing*`, `radius*`, `softShadow`, `diffuseShadow` constants are layout-only — do NOT migrate
- `album_visual_palette.dart` is already brightness-aware via `resolve(brightness:)` — only migrate `AppTheme.primaryText` fallback usage
- After each batch: `flutter analyze lib test` must pass with zero errors
- No new tests required (color mapping is declarative; `Theme.of(context).brightness` is framework-guaranteed)

---

### Task 1: Theme Infrastructure — Color Constants & Resolvers

**Files:**
- Modify: `lib/config/theme.dart`

**Interfaces:**
- Produces: `AppTheme.darkBodyPrimary` (new constant), updated `darkPrimaryText`, `darkSecondaryText` values, updated dark textStyles, 6 new static resolver methods: `primaryColorOf(BuildContext)`, `secondaryColorOf(BuildContext)`, `surfaceColorOf(BuildContext)`, `backgroundColorOf(BuildContext)`, `surfaceHighlightColorOf(BuildContext)`, `favoriteRedColorOf(BuildContext)`

- [ ] **Step 1: Update dark color constants in `lib/config/theme.dart`**

Replace the dark colors section (lines ~28-34) with refined values and add `darkBodyPrimary`:

```dart
  // ━━━ Dark Mode Colors ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkFavoriteRed = Color(0xFFEF5350);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkBodyPrimary = Color(0xFFE0E0E0);
  static const Color darkSecondaryText = Color(0xFF9E9E9E);
  static const Color darkBodyText = Color(0xFF616161);
```

Remove the old `darkPrimaryText`, `darkSecondaryText`, `darkBodyText` getters that used `Colors.white.withValues(alpha: ...)`.

- [ ] **Step 2: Update dark text styles in `lib/config/theme.dart`**

Replace the dark typography section (lines ~100-108) so headline/title styles use `darkPrimaryText`, body uses `darkBodyPrimary`, secondary uses `darkSecondaryText`:

```dart
  // ━━━ Dark Typography ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static final TextStyle darkHeadlineLarge = headlineLarge.copyWith(color: darkPrimaryText);
  static final TextStyle darkHeadlineMedium = headlineMedium.copyWith(color: darkPrimaryText);
  static final TextStyle darkTitleLarge = titleLarge.copyWith(color: darkPrimaryText);
  static final TextStyle darkTitleMedium = titleMedium.copyWith(color: darkPrimaryText);
  static final TextStyle darkBodyLarge = bodyLarge.copyWith(color: darkBodyPrimary);
  static final TextStyle darkBodyMedium = bodyMedium.copyWith(color: darkSecondaryText);
  static final TextStyle darkBodySmall = bodySmall.copyWith(color: darkSecondaryText);
  static final TextStyle darkCaption = caption.copyWith(color: darkSecondaryText);
```

- [ ] **Step 3: Add resolver methods to `AppTheme` class**

Add the following 6 static methods inside the `AppTheme` class (before the `ThemeData` getters):

```dart
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
```

- [ ] **Step 4: Verify clean compile**

Run: `flutter analyze lib/config/theme.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/config/theme.dart
git commit -m "feat: refine dark mode color constants and add context-aware resolvers"
```

---

### Task 2: Theme Infrastructure — BuildContext Extension

**Files:**
- Create: `lib/config/theme_context.dart`

**Interfaces:**
- Consumes: `AppTheme.primaryColorOf()`, `secondaryColorOf()`, `surfaceColorOf()`, `backgroundColorOf()`, `surfaceHighlightColorOf()`, `favoriteRedColorOf()` (from Task 1); `Theme.of(context).textTheme` (from Material)
- Produces: Extension `ThemeContext` on `BuildContext` with getters: `primaryColor`, `secondaryColor`, `surfaceColor`, `backgroundColor`, `surfaceHighlightColor`, `favoriteRedColor`, `textHeadlineLarge`, `textHeadlineMedium`, `textTitleLarge`, `textTitleMedium`, `textBodyLarge`, `textBodyMedium`, `textBodySmall`, `textCaption`

- [ ] **Step 1: Create `lib/config/theme_context.dart`**

```dart
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
```

- [ ] **Step 2: Verify clean compile**

Run: `flutter analyze lib/config/`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/config/theme_context.dart
git commit -m "feat: add BuildContext extension for theme-aware colors and text styles"
```

---

### Task 3: Migrate Shared Widgets — glass_top_bar, song_tile

**Files:**
- Modify: `lib/widgets/glass_top_bar.dart` (1 site: line 82)
- Modify: `lib/widgets/song_tile.dart` (multiple sites)

**Note:** `lib/widgets/bottom_nav.dart` already uses `Theme.of(context).colorScheme.onSurface` — no migration needed.

**Interfaces:**
- Consumes: `ThemeContext` extension (from Task 2)
- Produces: Widgets now use `context.primaryColor`, `context.secondaryColor`, `context.text*` instead of `AppTheme.*`

- [ ] **Step 1: Migrate `lib/widgets/glass_top_bar.dart`**

Add import:
```dart
import '../config/theme_context.dart';
```

Line 82, change:
```dart
// Before:
color: AppTheme.primaryText,
// After:
color: context.primaryColor,
```

- [ ] **Step 2: Migrate `lib/widgets/song_tile.dart`**

Add import `'../config/theme_context.dart'`. Replace:
- `AppTheme.surfaceHighlight` → `context.surfaceHighlightColor`
- `AppTheme.bodyMedium` → `context.textBodyMedium`
- `AppTheme.titleMedium` → `context.textTitleMedium`
- `AppTheme.primaryText` → `context.primaryColor`
- `AppTheme.bodyLarge` → `context.textBodyLarge`
- `AppTheme.secondaryText` → `context.secondaryColor`

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/widgets/glass_top_bar.dart lib/widgets/song_tile.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/glass_top_bar.dart lib/widgets/song_tile.dart
git commit -m "refactor: migrate glass_top_bar, song_tile to context-aware theme"
```

---

### Task 4: Migrate Shared Widgets — album_cover, song_actions_sheet, home_sidebar

**Files:**
- Modify: `lib/widgets/album_cover.dart`
- Modify: `lib/widgets/song_actions_sheet.dart`
- Modify: `lib/widgets/home_sidebar.dart`

- [ ] **Step 1: Migrate `lib/widgets/album_cover.dart`**

The `_PlaceholderCover` uses hardcoded gradient `Color(0xFFE0E0E0)` / `Color(0xFFBDBDBD)`. Make it context-aware:

Add import `'../config/theme_context.dart'`. Change the `_PlaceholderCover.build` to use theme-aware colors for the gradient. Since it's a `StatelessWidget` without direct context in `build`, pass brightness from parent `AlbumCover` (which has context):

In `AlbumCover.build`, capture brightness:
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
```

Pass `isDark` to `_PlaceholderCover`. In `_PlaceholderCover`, use:
```dart
gradient: LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: isDark
      ? const [Color(0xFF2C2C2C), Color(0xFF1E1E1E)]
      : const [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
),
```

- [ ] **Step 2: Migrate `lib/widgets/song_actions_sheet.dart`**

Add import `'../config/theme_context.dart'`. Replace:
- `AppTheme.primaryText` → `context.primaryColor`
- `AppTheme.bodyLarge` → `context.textBodyLarge`
- `AppTheme.secondaryText` → `context.secondaryColor`
- `AppTheme.titleLarge` → `context.textTitleLarge`
- `AppTheme.bodyMedium` → `context.textBodyMedium`
- `AppTheme.favoriteRed` → `context.favoriteRedColor`
- `AppTheme.surfaceLight` → `context.surfaceColor`

- [ ] **Step 3: Migrate `lib/widgets/home_sidebar.dart`**

Add import `'../config/theme_context.dart'`. Replace:
- `AppTheme.headlineLarge` → `context.textHeadlineLarge`
- `AppTheme.bodyMedium` → `context.textBodyMedium`
- `AppTheme.secondaryText` → `context.secondaryColor`
- `AppTheme.primaryText` → `context.primaryColor`
- `AppTheme.surfaceLight` → `context.surfaceColor`
- `AppTheme.titleMedium` → `context.textTitleMedium`
- `AppTheme.bodySmall` → `context.textBodySmall`
- `AppTheme.surfaceHighlight` → `context.surfaceHighlightColor`
- `AppTheme.caption` → `context.textCaption`

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/widgets/album_cover.dart lib/widgets/song_actions_sheet.dart lib/widgets/home_sidebar.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/album_cover.dart lib/widgets/song_actions_sheet.dart lib/widgets/home_sidebar.dart
git commit -m "refactor: migrate album_cover, song_actions_sheet, home_sidebar to context-aware theme"
```

---

### Task 5: Migrate Shared Widgets — artist_content, play_queue_sheet, artist_sheet, waveform_progress

**Files:**
- Modify: `lib/widgets/artist_content.dart`
- Modify: `lib/widgets/play_queue_sheet.dart`
- Modify: `lib/widgets/artist_sheet.dart`
- Modify: `lib/widgets/waveform_progress.dart`

- [ ] **Step 1: Migrate all four files**

For each file, add import `'../config/theme_context.dart'` and apply the standard migration pattern:

`lib/widgets/artist_content.dart`:
- `AppTheme.headlineMedium` → `context.textHeadlineMedium`
- `AppTheme.secondaryText` → `context.secondaryColor`
- `AppTheme.bodyLarge` → `context.textBodyLarge`
- `AppTheme.primaryText` → `context.primaryColor`
- `AppTheme.surfaceLight` → `context.surfaceColor`
- `AppTheme.background` → `context.backgroundColor`
- `AppTheme.titleMedium` → `context.textTitleMedium`
- `AppTheme.bodyMedium` → `context.textBodyMedium`
- `AppTheme.caption` → `context.textCaption`

`lib/widgets/play_queue_sheet.dart`:
- `AppTheme.background` → `context.backgroundColor`
- `AppTheme.headlineMedium` → `context.textHeadlineMedium`
- `AppTheme.bodyMedium` → `context.textBodyMedium`
- `AppTheme.titleMedium` → `context.textTitleMedium`
- `AppTheme.surfaceLight` → `context.surfaceColor`
- `AppTheme.bodySmall` → `context.textBodySmall`
- `AppTheme.primaryText` → `context.primaryColor`
- `AppTheme.caption` → `context.textCaption`

`lib/widgets/artist_sheet.dart`:
- `AppTheme.background` → `context.backgroundColor`
- `AppTheme.secondaryText` → `context.secondaryColor`

`lib/widgets/waveform_progress.dart`:
- `AppTheme.primaryText` → `context.primaryColor`
- `AppTheme.caption` → `context.textCaption`
- Keep `AppTheme.waveformPlayed` and `AppTheme.waveformUnplayed` (they are fallback values, not theme-sensitive text)

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/widgets/artist_content.dart lib/widgets/play_queue_sheet.dart lib/widgets/artist_sheet.dart lib/widgets/waveform_progress.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/artist_content.dart lib/widgets/play_queue_sheet.dart lib/widgets/artist_sheet.dart lib/widgets/waveform_progress.dart
git commit -m "refactor: migrate artist_content, play_queue_sheet, artist_sheet, waveform_progress to context-aware theme"
```

---

### Task 6: Migrate Primary Screens — home_screen

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Migrate `lib/screens/home_screen.dart`**

Add import `'../config/theme_context.dart'`.

Replace ALL color/text-style references (leave spacing/radius untouched):

```
AppTheme.headlineLarge  → context.textHeadlineLarge
AppTheme.bodyMedium     → context.textBodyMedium
AppTheme.secondaryText  → context.secondaryColor
AppTheme.titleMedium    → context.textTitleMedium
AppTheme.bodySmall      → context.textBodySmall
AppTheme.caption        → context.textCaption
AppTheme.surfaceLight   → context.surfaceColor
AppTheme.primaryText    → context.primaryColor
AppTheme.titleLarge     → context.textTitleLarge
```

This file has ~15 color/text references across multiple private widget classes. Each needs the import and context accessor.

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "refactor: migrate home_screen to context-aware theme"
```

---

### Task 7: Migrate Primary Screens — library_screen, hotlist_screen, search_screen

**Files:**
- Modify: `lib/screens/library_screen.dart`
- Modify: `lib/screens/hotlist_screen.dart`
- Modify: `lib/screens/search_screen.dart`

- [ ] **Step 1: Migrate `lib/screens/library_screen.dart`**

Add import `'../config/theme_context.dart'`. Replace:
```
AppTheme.headlineLarge  → context.textHeadlineLarge
AppTheme.primaryText    → context.primaryColor
AppTheme.secondaryText  → context.secondaryColor
AppTheme.titleMedium    → context.textTitleMedium
AppTheme.bodyMedium     → context.textBodyMedium
```

- [ ] **Step 2: Migrate `lib/screens/hotlist_screen.dart`**

Add import `'../config/theme_context.dart'`. Replace:
```
AppTheme.bodyMedium     → context.textBodyMedium
AppTheme.titleLarge     → context.textTitleLarge
AppTheme.headlineLarge  → context.textHeadlineLarge
```

- [ ] **Step 3: Migrate `lib/screens/search_screen.dart`**

Add import `'../config/theme_context.dart'`. Replace:
```
AppTheme.background     → context.backgroundColor
AppTheme.bodyLarge      → context.textBodyLarge
AppTheme.bodyMedium     → context.textBodyMedium
AppTheme.secondaryText  → context.secondaryColor
AppTheme.surfaceLight   → context.surfaceColor
AppTheme.titleLarge     → context.textTitleLarge
AppTheme.primaryText    → context.primaryColor
AppTheme.headlineMedium → context.textHeadlineMedium
AppTheme.titleMedium    → context.textTitleMedium
AppTheme.caption        → context.textCaption
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/screens/library_screen.dart lib/screens/hotlist_screen.dart lib/screens/search_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/library_screen.dart lib/screens/hotlist_screen.dart lib/screens/search_screen.dart
git commit -m "refactor: migrate library, hotlist, search screens to context-aware theme"
```

---

### Task 8: Migrate Secondary Screens — album_detail, artist_detail, now_playing

**Files:**
- Modify: `lib/screens/album_detail_screen.dart`
- Modify: `lib/screens/artist_detail_screen.dart`
- Modify: `lib/screens/now_playing_screen.dart`

- [ ] **Step 1: Migrate all three files**

Add import `'../config/theme_context.dart'` to each.

`lib/screens/album_detail_screen.dart`:
```
AppTheme.caption        → context.textCaption
AppTheme.headlineLarge  → context.textHeadlineLarge
AppTheme.titleMedium    → context.textTitleMedium
AppTheme.secondaryText  → context.secondaryColor
AppTheme.bodyMedium     → context.textBodyMedium
AppTheme.surfaceLight   → context.surfaceColor
AppTheme.primaryText    → context.primaryColor
```

`lib/screens/artist_detail_screen.dart`:
```
AppTheme.background     → context.backgroundColor
```

`lib/screens/now_playing_screen.dart`:
```
AppTheme.secondaryText  → context.secondaryColor
AppTheme.bodyMedium     → context.textBodyMedium
AppTheme.favoriteRed    → context.favoriteRedColor
AppTheme.headlineMedium → context.textHeadlineMedium
AppTheme.titleMedium    → context.textTitleMedium
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/album_detail_screen.dart lib/screens/artist_detail_screen.dart lib/screens/now_playing_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/album_detail_screen.dart lib/screens/artist_detail_screen.dart lib/screens/now_playing_screen.dart
git commit -m "refactor: migrate album_detail, artist_detail, now_playing to context-aware theme"
```

---

### Task 9: Migrate Secondary Screens — lyrics, settings, settings_hub, download_manager, cache_management, my_screen

**Files:**
- Modify: `lib/screens/lyrics_screen.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/screens/settings_hub_screen.dart`
- Modify: `lib/screens/download_manager_screen.dart`
- Modify: `lib/screens/cache_management_screen.dart`
- Modify: `lib/screens/my_screen.dart`

- [ ] **Step 1: Migrate `lib/screens/lyrics_screen.dart`**

This file already has manual brightness checks using `AppTheme.darkPrimaryText` / `AppTheme.primaryText` etc. Simplify by using the context extension:

Add import `'../config/theme_context.dart'`. Replace all manual dark/light branching with:
```
AppTheme.darkPrimaryText / AppTheme.primaryText ternary  → context.primaryColor
AppTheme.darkBodyText                                    → context.textBodySmall?.color (or keep as-is)
AppTheme.darkHeadlineLarge / AppTheme.headlineLarge      → context.textHeadlineLarge
AppTheme.darkTitleMedium / AppTheme.titleMedium          → context.textTitleMedium
AppTheme.darkSecondaryText / AppTheme.secondaryText      → context.secondaryColor
AppTheme.headlineMedium                                  → context.textHeadlineMedium
AppTheme.secondaryText                                   → context.secondaryColor
AppTheme.bodyMedium                                      → context.textBodyMedium
```

- [ ] **Step 2: Migrate `lib/screens/settings_screen.dart`**

Add import `'../config/theme_context.dart'`. Replace:
```
AppTheme.favoriteRed     → context.favoriteRedColor
AppTheme.surfaceLight    → context.surfaceColor
AppTheme.secondaryText   → context.secondaryColor
AppTheme.titleMedium     → context.textTitleMedium
AppTheme.bodyLarge       → context.textBodyLarge
AppTheme.bodyMedium      → context.textBodyMedium
AppTheme.primaryText     → context.primaryColor
AppTheme.caption         → context.textCaption
```

- [ ] **Step 3: Migrate `lib/screens/settings_hub_screen.dart`**

Add import `'../config/theme_context.dart'`. Replace:
```
AppTheme.surfaceLight    → context.surfaceColor
AppTheme.background      → context.backgroundColor
AppTheme.primaryText     → context.primaryColor
AppTheme.bodyLarge       → context.textBodyLarge
AppTheme.bodyMedium      → context.textBodyMedium
AppTheme.secondaryText   → context.secondaryColor
```

- [ ] **Step 4: Migrate remaining files**

`lib/screens/download_manager_screen.dart`:
```
AppTheme.titleLarge      → context.textTitleLarge
AppTheme.bodyMedium      → context.textBodyMedium
AppTheme.titleMedium     → context.textTitleMedium
AppTheme.secondaryText   → context.secondaryColor
AppTheme.surfaceLight    → context.surfaceColor
```

`lib/screens/cache_management_screen.dart`:
```
AppTheme.background      → context.backgroundColor
AppTheme.primaryText     → context.primaryColor
AppTheme.secondaryText   → context.secondaryColor
AppTheme.bodySmall       → context.textBodySmall
AppTheme.bodyMedium      → context.textBodyMedium
AppTheme.titleMedium     → context.textTitleMedium
AppTheme.bodyLarge       → context.textBodyLarge
AppTheme.caption         → context.textCaption
AppTheme.surfaceLight    → context.surfaceColor
```

`lib/screens/my_screen.dart`:
```
AppTheme.surfaceLight    → context.surfaceColor
AppTheme.secondaryText   → context.secondaryColor
AppTheme.titleMedium     → context.textTitleMedium
AppTheme.bodyMedium      → context.textBodyMedium
AppTheme.primaryText     → context.primaryColor
AppTheme.bodyLarge       → context.textBodyLarge
```

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/screens/`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/lyrics_screen.dart lib/screens/settings_screen.dart lib/screens/settings_hub_screen.dart lib/screens/download_manager_screen.dart lib/screens/cache_management_screen.dart lib/screens/my_screen.dart
git commit -m "refactor: migrate remaining screens to context-aware theme"
```

---

### Task 10: Final Verification & Build

- [ ] **Step 1: Full static analysis**

Run: `flutter analyze lib test`
Expected: No issues found.

- [ ] **Step 2: Run existing tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Build release APK**

Run: `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`
Expected: Build successful, output at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: final verification after dark mode color migration"
```
