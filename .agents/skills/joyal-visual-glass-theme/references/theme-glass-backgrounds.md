# Theme, Glass, And Backgrounds

## Theme And Color

- `ThemeNotifier` cycles `light -> dark -> system`; first launch defaults to `system`.
- Prefer `ThemeContext` colors and text styles. Avoid static colors such as `AppTheme.primaryText` without a strong local reason.
- Use `#121212` / `#1E1E1E` dark backgrounds; avoid pure black.
- `context.primaryColor` is primary text color. Do not use it as a button background, icon-container background, or circular base color.
- In dark mode, use `context.surfaceColor` for surfaces and `context.primaryColor` for foreground.
- Use `showAppToast(...)`. Keep toast width constraint-driven; do not hand-calculate it with `TextPainter`.

## Album Palette And Page Background Identity

- Keep album color extraction in `AlbumVisualPalette`; include brightness in palette cache keys.
- Identify dynamic backgrounds/providers with stable `coverArtId/baseUrl/username`, not random-token-bearing `coverUrl` equality or hashes.
- Let `PageBackgroundProvider` and `PageCustomBackground` own main-page backgrounds.
- Home, library, and discovery share local images. Internal `PageBackgroundTarget.favorites` displays as `发现`.

## Frosted And Liquid Glass

- Route parameters through `glass_effect_provider.dart` and use `FrostedGlass` for general glass containers.
- Add every new frosted-glass UI target to the personalization “毛玻璃” horizontal preview.
- Support blur and opacity sliders. Update in memory while dragging and persist on release.
- Reuse `FrostedGlass` for new floating glass components. Do not scatter `LiquidGlassLens` parameters throughout the app.
- For custom tuning, extend `LiquidGlassOverlay` while preserving shared blur/opacity and liquid-toggle behavior.
- Liquid glass uses `liquid_glass_easy`; preference `glass_effect_liquid_enabled` controls the personalization “液态玻璃” switch.
- When enabled, `FrostedGlass` uses `LiquidGlassLens` / `OpticalRefraction` through `liquid_glass_overlay.dart`. When disabled, retain the original `BackdropFilter` path.

## Now Playing Backgrounds

- Now playing and lyrics use one shared `DynamicAlbumBackground`.
- Implement moving light with `CustomPainter` plus `sin/cos`; stop controllers for static gradients.
- `BackgroundVisualStyle.albumCoverGlass` uses the current cover through `CachedDiskImage` + `ImageFiltered` for both now-playing and lyrics.
- Keep its full-screen blur a static reduced-raster composition, not a full-resolution filtered texture. Isolate `_CoverGlassBackground` from high-frequency lyric foregrounds so lyric ticks do not reraster the cover.
- Persist blur and adaptive light/dark overlay through `coverGlassBackgroundProvider`. Slider changes are live and persist on drag end. Never replace this with a full-screen `BackdropFilter`.
