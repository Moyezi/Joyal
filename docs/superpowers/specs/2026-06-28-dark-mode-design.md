# Dark Mode Design — Joyal Music

**Date:** 2026-06-28  
**Status:** Approved  
**Approach:** Riverpod ThemeProvider + Brightness-aware Palette

---

## 1. Overview

Add dark mode support to Joyal Music with three-mode cycling: ☀️ Light → 🌙 Dark → 🅰️ Auto (system) → ☀️ Light. The implementation uses Material 3 dark color scheme, brightness-aware album cover color extraction, and theme-aware widget adaptations.

## 2. Decisions Summary

| Decision | Choice |
|---|---|
| Toggle entry | Sidebar bottom-right (next to settings) + SettingsHub "外观" row |
| Toggle behavior | Single tap cycles ☀️→🌙→🅰️→☀️ |
| First launch default | Auto (system) |
| Auto mode | Real-time follow system brightness via `ThemeMode.system` |
| MiniPlayer | Always `#151922`, excluded from theme |
| Album palette darkening | `Color.lerp` with `Colors.black` at factor 0.5 |
| Transition animation | Flutter built-in theme transition + light opacity overlay (~200ms) |
| Approach | Riverpod `StateNotifier<ThemeMode>`, persisted to `flutter_secure_storage` |

## 3. Color System

### 3.1 Dark Theme Colors

```dart
static const Color darkBackground      = Color(0xFF121212);  // Global scaffold
static const Color darkSurface         = Color(0xFF1E1E1E);  // Cards, nav
static const Color darkSurfaceVariant  = Color(0xFF2C2C2C);  // Elevated surfaces

// Text — no pure white
// Primary text:   Colors.white.withOpacity(0.87)  ~ #DEDEDE (headlines)
// Secondary text: Colors.white.withOpacity(0.60)  ~ #999999 (subtitles)
// Body text:      Colors.white.withOpacity(0.38)  ~ #616161 (inactive lyrics)

static const Color darkFavoriteRed     = Color(0xFFEF5350);  // Brighter red for dark bg
```

### 3.2 Material 3 ColorScheme.dark

```dart
ColorScheme.dark(
  surface:         darkBackground,    // #121212
  onSurface:       white87,
  primary:         white87,
  secondary:       white60,
  surfaceVariant:  darkSurfaceVariant, // #2C2C2C
);
```

### 3.3 Light Theme (Unchanged)

All existing `AppTheme.lightTheme`, static color constants, and `ColorScheme.light(...)` remain exactly as they are today.

## 4. State Management — ThemeProvider

### 4.1 New File: `lib/providers/theme_provider.dart`

- `ThemeNotifier` extends `StateNotifier<ThemeMode>`
- Initial state: read `theme_mode` from `flutter_secure_storage`; default `ThemeMode.system`
- `cycleMode()`: `light → dark → system → light`
- On each change: write to `flutter_secure_storage` key `theme_mode`

```dart
final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});

final isDarkProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  switch (mode) {
    case ThemeMode.light: return false;
    case ThemeMode.dark:  return true;
    case ThemeMode.system: return platformBrightness == Brightness.dark;
  }
});
```

### 4.2 `app.dart` Changes

```dart
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,              // NEW
  themeMode: ref.watch(themeModeProvider),    // NEW
  home: const MainShell(),
);
```

No `WidgetsBindingObserver` needed — `ThemeMode.system` handles real-time system follow natively.

## 5. Album Cover Palette — Brightness-aware

### 5.1 `AlbumVisualPalette.resolve()` Signature Change

```dart
// Add Brightness parameter (default Brightness.light for backward compat)
static Future<AlbumVisualPalette> resolve({
  required String coverArtId,
  required String coverUrl,
  Brightness brightness = Brightness.light,
});
```

### 5.2 Extraction Logic

```dart
final scheme = await ColorScheme.fromImageProvider(
  provider: provider,
  brightness: brightness,  // Dynamic, not hardcoded
  dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
);
```

### 5.3 `fromScheme()` — Dark Mode Path

```dart
static AlbumVisualPalette fromScheme(ColorScheme scheme, Brightness brightness) {
  if (brightness == Brightness.dark) {
    return AlbumVisualPalette(
      top:    Color.lerp(scheme.primaryContainer, Colors.black, 0.50)!,
      bottom: Color.lerp(scheme.secondaryContainer, Colors.black, 0.50)!,
      waveformAccent: Color.lerp(scheme.primary, Colors.white, 0.24)!,
      waveformAccentSoft: Color.lerp(waveformAccent, Colors.black, 0.38)!,
      waveformTrack: Color.lerp(AppTheme.darkSurfaceVariant, top, 0.16)!,
    );
  }
  // Light mode: existing logic unchanged
}
```

### 5.4 Cache Key

Cache key includes brightness: `${coverArtId}_${brightness.name}`. Light and dark palettes are cached independently.

### 5.5 Fallback

```dart
static AlbumVisualPalette fallbackFor(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return AlbumVisualPalette(
      top: AppTheme.darkBackground,
      bottom: AppTheme.darkBackground,
      waveformAccent: Colors.white70,
      waveformAccentSoft: Colors.white38,
      waveformTrack: AppTheme.darkSurfaceVariant,
    );
  }
  return AlbumVisualPalette.fallback; // existing light fallback
}
```

### 5.6 Callers Updated

- `DynamicAlbumBackground._loadPalette()` — reads `Theme.of(context).brightness`
- `NowPlayingScreen._syncVisualPalette()` — passes `Theme.of(context).brightness`

## 6. UI Components — Theme Adaptations

### 6.1 GlassTopBar

Background gradient: replace `AppTheme.background` (white) with theme-aware color.
- Light: existing white → transparent gradient
- Dark: `#121212` → transparent gradient

### 6.2 BottomNav

- Light: white background + light shadow (unchanged)
- Dark: `#1E1E1E` background
- When song playing: dark Dock stays `miniPlayerBg` (#151922) regardless of theme

### 6.3 MiniPlayer

- **Unchanged.** Always `#151922` background, white text.

### 6.4 HomeSidebar

- Light: `surfaceLight` (#F3F4F6) / `surfaceHighlight` (#F0F1F3)
- Dark: use `darkSurface` (#1E1E1E) / `darkSurfaceVariant` (#2C2C2C)

### 6.5 SettingsHubScreen

- Backgrounds: theme-aware surfaces
- **New entry "外观"**: `Icons.palette_outlined`, title "外观", subtitle shows current mode in Chinese ("浅色模式"/"深色模式"/"跟随系统"), tap calls `cycleMode()`

### 6.6 NowPlayingScreen

- Background: `DynamicAlbumBackground` with brightness-aware palette
- Text: light mode `primaryText` (#1A1A1A) / dark mode `white87`
- Controls: theme-aware colors via `ColorScheme`

### 6.7 LyricsScreen

- Active line: `white87` + `FontWeight.w800` (dark) / existing (light)
- Inactive lines: `white38` (dark, was 42% black) / existing (light)

### 6.8 WaveformProgress

When no per-song palette (static defaults):
- Light: `waveformPlayed` (#1A1A1A) / `waveformUnplayed` (#D1D1D6)
- Dark: `white70` / `darkSurfaceVariant` (#2C2C2C)
- When palette available: use `palette.waveformAccent` / `palette.waveformTrack` (already brightness-correct)

### 6.9 Progress Slider

- Active track: `colorScheme.primary` (bright/visible on dark)
- Inactive track: `white24` opacity

### 6.10 Search/Library/Favorites Lists

- Card backgrounds: `darkSurface` instead of white

## 7. Theme Toggle UI

### 7.1 Sidebar Button

`HomeSidebar` bottom area: `Row` containing settings button + theme button.

```dart
Row(
  children: [
    IconButton.filledTonal(icon: Icons.settings_outlined, ...), // existing
    SizedBox(width: 12),
    _ThemeModeButton(),  // new
  ],
)
```

`_ThemeModeButton`: `IconButton.filledTonal` with dynamic icon:
- `ThemeMode.light` → `Icons.sunny`
- `ThemeMode.dark` → `Icons.dark_mode`
- `ThemeMode.system` → `Icons.brightness_auto`

### 7.2 Transition Animation

Simplified approach: rely on Flutter's built-in `ThemeData` transition when `themeMode` changes (`MaterialApp` internally handles ~200ms crossfade). No custom `ClipOval` reveal necessary at this stage.

## 8. Files to Create / Modify

### New Files
- `lib/providers/theme_provider.dart` — ThemeNotifier + providers

### Modified Files
| File | Changes |
|---|---|
| `lib/config/theme.dart` | Add dark color constants, `darkTheme` getter |
| `lib/app.dart` | Add `darkTheme:` and `themeMode:` to MaterialApp |
| `lib/widgets/album_visual_palette.dart` | Add `brightness` param, dark `fromScheme()` path, `fallbackFor()` |
| `lib/widgets/dynamic_album_background.dart` | Pass brightness from context |
| `lib/screens/now_playing_screen.dart` | Pass brightness to palette resolve |
| `lib/widgets/home_sidebar.dart` | Add `_ThemeModeButton` in Row |
| `lib/screens/settings_hub_screen.dart` | Add "外观" entry |
| `lib/screens/lyrics_screen.dart` | Dark-aware text colors |
| `lib/widgets/glass_top_bar.dart` | Theme-aware background gradient |
| `lib/widgets/bottom_nav.dart` | Theme-aware background |
| `lib/widgets/waveform_progress.dart` | Dark static defaults |

## 9. Testing

- `test/now_playing_visual_song_test.dart` — add brightness variant tests
- New `test/theme_provider_test.dart` — cycleMode(), persistence, default
- New `test/album_visual_palette_dark_test.dart` — dark extraction produces correct blending
- `flutter test` full suite must pass

## 10. Scope Boundaries

- **In scope:** ThemeData generation, ThemeMode state, brightness-aware palette, all widget adaptations listed in §6.
- **Out of scope:** Design token refactoring, Android system status bar theming, adaptive icon changes, Web/CORS dark mode testing, iOS system appearance integration (already handled by `ThemeMode.system`).
