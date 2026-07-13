---
name: joyal-visual-glass-theme
description: "Visual, theme, and glass-effect memory for Joyal Music. Use when changing ThemeContext colors, AppTheme usage, page backgrounds, album palette extraction, FrostedGlass, liquid glass, MiniPlayer tint, DynamicAlbumBackground, the infinite library canvas and its cover-depth transitions, lyrics stage effects, or visual-performance-sensitive UI."
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
- For a large static background that intentionally destroys image detail, render and decode the source at reduced logical size, apply `ImageFiltered` there, then compositor-scale the finished layer back up. Multiply the blur sigma by the same raster scale so the final visual radius stays equivalent. Keep the result clipped and inside a `RepaintBoundary`.
- `DynamicAlbumBackground` cover glass is the reference implementation: `_CoverGlassBackground` uses a `0.32` raster scale, a correspondingly reduced `decodeWidth` and blur sigma, then scales by `1 / rasterScale`. Preserve the full-resolution bypass when blur is ineffective.
- Do not apply reduced-raster blur to text, sharp chrome, lightly blurred surfaces, or content whose fine detail must remain visible. It is intended for large, heavily blurred self-images such as cover-derived page backgrounds.
- Optimize blur cost through raster area, repaint isolation, lifecycle, and compositing before considering animation throttling. Do not lower an interaction or foreground animation's frame rate merely to hide expensive blur work.
- The flowing-halo painter is throttled through `_ThrottledRepaint`; do not restore a widget-level `AnimatedBuilder` that rebuilds its full background at display refresh rate.
- Prefer `provider.select` or local `Consumer` for high-frequency position UI.

## Infinite Library Canvas

- Treat the hexagon as the logical outline formed by the scattered song positions. Do not clip the viewport to a hexagon or draw a fixed hexagonal screen border.
- Place songs in complete axial hex rings. If the final ring is incomplete, distribute its cells evenly around the ring so the whole collection remains approximately hexagonal.
- Keep cards spatially separated. Drag freely, snap the nearest song to center on release, and animate tapped songs to center.
- Use one fixed `224` logical-pixel card layout and derive its apparent size and opacity continuously from center distance through `Transform.scale` and `Opacity`. Do not resize card layout, padding, typography, or `Positioned` bounds on every pan update.
- Render only cells near the viewport. Keep cover loading on `CachedDiskImage` and isolate each card with `RepaintBoundary`.
- Drive pan and snap offsets through a local `ValueNotifier<Offset>`/small listenable subtree so the scaffold, header, providers, and unrelated UI do not rebuild for pointer events.
- Keep visible child order stable while panning and only lift the nearest card when focus crosses to another cell. Key every positioned card by stable song ID so cached cover state never moves between songs or flashes.
- Keep a fixed cover `decodeWidth` across focus scaling. Do not derive decode size from the animated card width.
- Keep the cover under one stable `ImageFiltered` node across the clear/blur transition; change sigma or `enabled` instead of inserting or removing the filter wrapper. Disable per-card blur during both direct dragging and the snap animation, then restore distance-derived blur after settling. This prevents raster-filter work from competing with interaction while preserving the stationary look.

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
- Its full-screen blur is a static reduced-raster composition rather than a
  full-resolution filtered texture. Keep `_CoverGlassBackground` isolated from
  the high-frequency flowing-lyrics foreground so lyric ticks do not reraster
  the cover.
- Its blur and adaptive light/dark overlay are persisted by
  `coverGlassBackgroundProvider`. Slider updates are live; persist on drag
  end. Do not replace this with a full-screen `BackdropFilter`.

## Lyrics Stage Themes

- Independent full-screen lyrics stages are separate foreground renderers, not duplicate full-screen backgrounds. `流光` and `浮名` are implemented and selectable; `群唱` remains planned and stays visible as a disabled `待完成` entry.
- `流光` lives in `lib/widgets/lyrics_stage/flowing_light_lyrics_stage.dart`. Show only the active line. Split Chinese into graphemes and keep Latin runs as words; use the same scattered composition even when word timing is absent or word-by-word display is disabled.
- Build the scattered layout deterministically from token text so rebuilds never move glyphs. Common 6–12-token lines use 3–4 top-to-bottom rows with about 2–3 tokens per row, varied gaps/offsets/scales, and normally distributed rotation centered at 0° and clamped to ±20°. Keep responsive scale-down for long text and small viewports; do not restore a regular `Wrap`.
- With word timing, reserve every token's layout position invisibly. Each entering token starts at about 116% scale and settles to 100% over 520 ms. Keep its entrance ring short, but hold the soft halo at full brightness until the next Chinese grapheme or Latin word appears, then overlap it with a smooth 520 ms fade-out; derive the hold interval from token starts rather than a fixed glow duration. Do not add a dim pending-token mask.
- Gate the outward entrance ring with the cached DeepSeek climax timeline. Tokens outside a returned climax segment must have zero ring intensity; loading/error/no-key/untimed states also render no ring while preserving the ordinary token reveal and soft halo.
- Keep the final timed token's soft halo breathing until the next line activates. Let the entrance ring finish once, derive the breath from the already-scoped active playback position, and fall back to a static highlight when motion is disabled or the stage is covered.
- `浮名` uses a cached world-space three-column snake layout with sparse hero lines, allowing the article and camera path to expand left and right before moving into the next row. Block transitions and single-visual-line camera follow must remain continuous: interpolate between cached grapheme-box centers from fractional print progress instead of snapping on completed glyphs. When one lyric wraps into multiple visual rows, lock the camera's horizontal focus to the block center and retain only subtle vertical following so line wraps never cause left-right sweeps. The visible ink still lands as one whole Chinese grapheme or Latin letter at a time. Its subtle paper tint is an edge-to-edge screen-space layer; never restore a finite world-space mask whose left/right/top/bottom edge can enter the camera. Lines overlapping a cached/recognized DeepSeek climax segment are prelaid out at about 116% of their normal floating-name size.
- The shared song/artist header stays overlaid and must not move the composition. In default scrolling, `流光`, and `浮名`, start its five-second visible period only after the lyrics surface becomes the settled foreground, then fade it over about 720 ms; opening the settings drawer must not restart that timer.
- Keep `浮名`'s original full blurred print stamp. Reveal typed text with per-grapheme span colors instead of clipping one fully bright painter with glyph selection rectangles; tight line metrics can otherwise expose the tops of the next visual row.
- Let default scrolling lyrics and `浮名` share `lyrics/lyric_print_effect.dart`: the active timed grapheme keeps the blurred print stamp and follows a baseline-to-10%-up-to-baseline bounce. Preserve the default renderer's color sweep/frontier glow, use no extra persistent controller, and keep motion off for whitespace, covered/disabled updates, and reduced-motion states.
- Treat non-current-line blur/opacity as a default-scroll-only visual effect. Do not show or apply `GlassEffectTarget.lyricsPage` controls in independent stages such as `流光`.
- Center lyrics-stage foreground compositions on the full phone-screen geometry. Render the song/artist header as an overlay; never use its reserved height to push the composition below screen center.
- Keep the settled `流光` composition vertically fixed without whole-composition floating or translation.
- Revealed `流光` tokens gently rock 1.8°–2.4° around their stable scattered angles over one 7.2-second controller cycle. Alternate the initial direction between neighboring tokens, reverse each token every half-cycle, ramp motion in with its reveal, leave future tokens still, and clamp the final angle to ±20°. Keep this local to the active composition `RepaintBoundary`; start it only when `positionUpdatesEnabled` is true, stop/reset it while covered or hidden, honor `MediaQuery.disableAnimationsOf(context)`, and restore every token to its base angle when disabled.
- Reuse the one `DynamicAlbumBackground` already owned by the enclosing now-playing route. A shared stage shell may derive cached palette colors and static decorative layers, but each renderer owns only its distinctive typography, composition, and purposeful local motion.
- Each stage renderer needs an explicit visible/covered lifecycle and must stop tickers, playback-position subscriptions, and local effect painting while hidden, during a covered settings drawer, or after returning to now playing.
- Premeasure complex glyph or bubble layouts and cache the result. Playback position should drive only the smallest active reveal or camera transform; it must not rebuild the entire stage composition.
- Keep static and reduced-cost fallbacks for devices that cannot sustain the full effect. Do not add stacked full-screen blur, refraction, or continuously repainting backgrounds merely to imitate the reference project.

## Files To Check

- Theme and visual providers: `glass_effect_provider.dart`, `visual_effect_provider.dart`, `page_background_provider.dart`, `mini_player_color_provider.dart`.
- Glass widgets: `frosted_glass.dart`, `liquid_glass_overlay.dart`.
- Backgrounds and palettes: `page_custom_background.dart`, `dynamic_album_background.dart`, `album_visual_palette.dart`.
- Infinite library canvas: `library_canvas_screen.dart`.
- MiniPlayer chrome: `mini_player_chrome.dart`.
- Personalization: `page_background_settings.dart`, `glass_effect_tile.dart`, `liquid_glass_toggle_tile.dart`, `mini_player_color_tile.dart`, `flowing_halo_background_tile.dart`, `personalization_choice_tile.dart`.
