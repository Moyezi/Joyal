---
name: joyal-visual-glass-theme
description: "Visual, theme, and glass-effect memory for Joyal Music. Use when changing ThemeContext colors, AppTheme usage, page backgrounds, album palette extraction, FrostedGlass, liquid glass, MiniPlayer tint, DynamicAlbumBackground, or visual-performance-sensitive UI."
---

# Joyal Visual Glass Theme

## Theme And Color

- `ThemeNotifier` cycles `light -> dark -> system`.
- First launch defaults to `system`.
- Widgets should prefer `ThemeContext` for colors and text styles.
- Avoid direct use of static colors such as `AppTheme.primaryText` unless there is a strong local reason.
- Dark backgrounds are `#121212` / `#1E1E1E`; avoid pure black.
- `context.primaryColor` is the primary text color.
- Do not use `context.primaryColor` as a button background, icon container background, or circular base color.
- In dark mode, use `context.surfaceColor` for the surface and `context.primaryColor` for the foreground.
- Toasts must use `showAppToast(...)`.
- Toast width should be constraint-driven; do not hand-calculate with `TextPainter`.

## Album Palette And Background Identity

- Album color extraction belongs to `AlbumVisualPalette`.
- Palette cache keys include brightness.
- Dynamic background and provider identity should use stable `coverArtId/baseUrl/username`.
- Do not use random-token-bearing `coverUrl` for equality or hash.
- Main page backgrounds are owned by `PageBackgroundProvider` and `PageCustomBackground`.
- Home, library, and discovery share local images.
- The internal enum `PageBackgroundTarget.favorites` displays as `发现`.

## Frosted Glass

- Glass parameters go through `glass_effect_provider.dart`.
- General-purpose glass containers should use `FrostedGlass`.
- New frosted-glass UI must be integrated into the personalization "毛玻璃" horizontal preview.
- Support both blur and opacity sliders.
- Slider dragging should update in memory live and persist only on release.
- New floating glass components should reuse `FrostedGlass` first.
- Do not scatter direct `LiquidGlassLens` parameters throughout the app.
- If custom tuning is needed, extend `LiquidGlassOverlay` while preserving shared blur/opacity and liquid-toggle behavior.

## Liquid Glass

- Liquid glass depends on `liquid_glass_easy`.
- The personalization "液态玻璃" switch controls it.
- Preference key: `glass_effect_liquid_enabled`.
- When enabled, `FrostedGlass` uses `LiquidGlassLens` / `OpticalRefraction` through `liquid_glass_overlay.dart` for real refraction.
- When disabled, `FrostedGlass` keeps the original `BackdropFilter` path.

## Performance Rules

- Do not create a `BackdropFilter` when blur is ineffective or the mask is nearly opaque.
- If only blurring the widget's own image, use `ImageFiltered`.
- Avoid full-screen dynamic `BackdropFilter`.
- High-frequency playback position must not rebuild whole pages, whole lists, backgrounds, palette extraction, or glass surfaces.
- Prefer `provider.select` or local `Consumer` for high-frequency position UI.

## Borders And Chrome

- Floating rounded glass components such as search boxes, Dock, MiniPlayer, `SongTile`, and `QueueSongCard` should not draw bright or gray strokes that create edge lines.
- When `FrostedGlass.borderOpacity` is 0, do not create a border at all.
- The personalization preview must follow the same real border rules.
- MiniPlayer color is controlled by `mini_player_color_provider.dart`.
- Default MiniPlayer background is `AppTheme.miniPlayerBg`.
- Dynamic MiniPlayer tint reuses `AlbumVisualPalette`.
- Capsule tint and collapsed-cover outer frame should match and still respect glass blur/opacity.
- Real MiniPlayer and personalization preview share `mini_player_chrome.dart`.
- Dynamic-color preview follows the current playing cover. If no palette is available, use a neutral fallback; do not fake color from `coverArtId.hashCode`.

## Now Playing Backgrounds

- Now playing and lyrics backgrounds use `DynamicAlbumBackground`.
- Moving light should be implemented with `CustomPainter` plus `sin/cos`.
- Stop animation controllers for static gradients.

## Files To Check

- Theme and visual providers: `glass_effect_provider.dart`, `visual_effect_provider.dart`, `page_background_provider.dart`, `mini_player_color_provider.dart`.
- Glass widgets: `frosted_glass.dart`, `liquid_glass_overlay.dart`.
- Backgrounds and palettes: `page_custom_background.dart`, `dynamic_album_background.dart`, `album_visual_palette.dart`.
- MiniPlayer chrome: `mini_player_chrome.dart`.
- Personalization: `page_background_settings.dart`, `glass_effect_tile.dart`, `liquid_glass_toggle_tile.dart`, `mini_player_color_tile.dart`, `personalization_choice_tile.dart`.
