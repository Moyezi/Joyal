---
name: joyal-visual-glass-theme
description: "Visual, theme, and glass-effect memory for Joyal Music. Use when changing ThemeContext colors, AppTheme usage, page backgrounds, album palette extraction, FrostedGlass, liquid glass, MiniPlayer tint, DynamicAlbumBackground, lyrics stage effects, or visual-performance-sensitive UI."
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

## Performance Is A Design Constraint

- Treat battery use, thermals, and frame pacing as part of visual quality. A visually rich effect is not acceptable when it continuously repaints or recomputes while the user cannot see a meaningful change.
- Default to a static or cached composition. Continuous animation must have a visible purpose, a single owner, and a lifecycle that stops it when the surface is hidden, fully covered, or no longer interactive.
- Never stack duplicate full-screen dynamic backgrounds during page transitions. Now playing and lyrics share one `DynamicAlbumBackground`; child pages render only their foreground content.
- Hidden playback/lyrics pages must disable tickers, high-frequency position subscriptions, and painting. Every exit path — system back, button, and swipe — must restore the newly visible page's updates.
- Full-screen cover blur must use `CachedDiskImage` + `ImageFiltered` inside a `RepaintBoundary`; do not use a full-screen `BackdropFilter` as a replacement. Skip an ineffective blur entirely.
- Moving or dragging a large glass drawer must not keep a dynamic background or full-area refraction filter live underneath it. Freeze the background while the drawer is open; use a tinted no-blur transition treatment, then restore glass only after the route settles.
- High-frequency playback position may update only the smallest visual unit that needs it: active word timing, the progress control, or a changed MiniPlayer lyric pair. It must not rebuild whole pages, lyric lists, album palettes, backgrounds, or glass surfaces.
- For user-tunable continuous effects, update in memory during drag and persist on release. The flowing-halo frame rate is persisted through `flowingHaloBackgroundProvider`, defaults to 20 FPS, and offers 5–60 FPS in `FlowingHaloBackgroundTile`.

## Performance Rules

- Do not create a `BackdropFilter` when blur is ineffective or the mask is nearly opaque.
- If only blurring the widget's own image, use `ImageFiltered`.
- Avoid full-screen dynamic `BackdropFilter`.
- The flowing-halo painter is throttled through `_ThrottledRepaint`; do not restore a widget-level `AnimatedBuilder` that rebuilds its full background at display refresh rate.
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
- `BackgroundVisualStyle.albumCoverGlass` uses the current cover through
  `CachedDiskImage` + `ImageFiltered`; it applies to both now-playing and
  lyrics because they share `DynamicAlbumBackground`.
- Its blur and adaptive light/dark overlay are persisted by
  `coverGlassBackgroundProvider`. Slider updates are live; persist on drag
  end. Do not replace this with a full-screen `BackdropFilter`.

## Lyrics Stage Themes

- Independent full-screen lyrics stages are separate foreground renderers, not duplicate full-screen backgrounds. `流光` is implemented; `浮名` and `群唱` remain planned and are shown as unavailable settings entries.
- `流光` lives in `lib/widgets/lyrics_stage/flowing_light_lyrics_stage.dart`. Show only the active line. Split Chinese into graphemes and keep Latin runs as words; use the same scattered composition even when word timing is absent or word-by-word display is disabled.
- Build the scattered layout deterministically from token text so rebuilds never move glyphs. Common 6–12-token lines use 3–4 top-to-bottom rows with about 2–3 tokens per row, varied gaps/offsets/scales, and normally distributed rotation centered at 0° and clamped to ±25°. Keep responsive scale-down for long text and small viewports; do not restore a regular `Wrap`.
- With word timing, reserve every token's layout position invisibly. Each entering token starts at about 116% scale, settles to 100% over 520 ms, and owns a brief soft highlight halo plus outward ring. Do not add a dim pending-token mask.
- Float the settled composition upward by at most 10% of the configured font size and back over a smooth 3.6-second loop. Keep this local to a `RepaintBoundary`; start it only when `positionUpdatesEnabled` is true, stop/reset it while covered or hidden, and honor `MediaQuery.disableAnimationsOf(context)`.
- Reuse the one `DynamicAlbumBackground` already owned by the enclosing now-playing route. A shared stage shell may derive cached palette colors and static decorative layers, but each renderer owns only its distinctive typography, composition, and purposeful local motion.
- Each stage renderer needs an explicit visible/covered lifecycle and must stop tickers, playback-position subscriptions, and local effect painting while hidden, during a covered settings drawer, or after returning to now playing.
- Premeasure complex glyph or bubble layouts and cache the result. Playback position should drive only the smallest active reveal or camera transform; it must not rebuild the entire stage composition.
- Keep static and reduced-cost fallbacks for devices that cannot sustain the full effect. Do not add stacked full-screen blur, refraction, or continuously repainting backgrounds merely to imitate the reference project.

## Files To Check

- Theme and visual providers: `glass_effect_provider.dart`, `visual_effect_provider.dart`, `page_background_provider.dart`, `mini_player_color_provider.dart`.
- Glass widgets: `frosted_glass.dart`, `liquid_glass_overlay.dart`.
- Backgrounds and palettes: `page_custom_background.dart`, `dynamic_album_background.dart`, `album_visual_palette.dart`.
- MiniPlayer chrome: `mini_player_chrome.dart`.
- Personalization: `page_background_settings.dart`, `glass_effect_tile.dart`, `liquid_glass_toggle_tile.dart`, `mini_player_color_tile.dart`, `flowing_halo_background_tile.dart`, `personalization_choice_tile.dart`.
