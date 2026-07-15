---
name: joyal-visual-glass-theme
description: "Visual, theme, and glass-effect memory for Joyal Music. Use when changing ThemeContext colors, AppTheme usage, page backgrounds, album palette extraction, FrostedGlass, liquid glass, MiniPlayer tint, DynamicAlbumBackground, the infinite library canvas and its cover-depth transitions, lyrics stage effects, or visual-performance-sensitive UI."
---

# Joyal Visual Glass Theme

## Core Contracts

- Preserve the minimal, immersive, cool black/white/gray direction with large radii and soft layering.
- Prefer `ThemeContext` tokens over static `AppTheme` colors. Treat `context.primaryColor` as foreground text color, not a generic surface fill.
- Route shared glass behavior through `FrostedGlass`, `glass_effect_provider.dart`, and `liquid_glass_overlay.dart`.
- Use stable `coverArtId/baseUrl/username` identity for cover-derived palettes and backgrounds; never hash random-token-bearing cover URLs.
- Treat battery, thermals, and frame pacing as visual quality. Continuous animation needs a visible purpose, one owner, and a lifecycle that stops while hidden or covered.
- Never stack duplicate full-screen dynamic backgrounds. Now playing and lyrics share the enclosing route's single `DynamicAlbumBackground`.
- Restrict high-frequency playback-position rebuilds to the smallest active visual unit.

## Reference Routing

Read only the references needed for the task:

- [Theme, glass, and backgrounds](references/theme-glass-backgrounds.md): theme colors, album palette identity, page backgrounds, frosted/liquid glass, and now-playing cover backgrounds.
- [Visual performance](references/visual-performance.md): blur/compositing rules, repaint isolation, animation lifecycle, and high-frequency update constraints.
- [Infinite canvas and chrome](references/infinite-canvas-chrome.md): infinite-library geometry/rendering, borders, MiniPlayer tint, and shared chrome.
- Lyrics stages use canonical shared references instead of duplicate visual memory: read [stage foundations](../joyal-library-playback-lyrics/references/lyrics-stage-foundations.md) plus [Flowing Light](../joyal-library-playback-lyrics/references/flowing-light-stage.md), [Floating Name](../joyal-library-playback-lyrics/references/floating-name-stage.md), and/or [lyrics AI analysis](../joyal-library-playback-lyrics/references/lyrics-ai-analysis.md) according to the task.

## File Routing

- Theme/visual providers: `lib/providers/glass_effect_provider.dart`, `lib/providers/visual_effect_provider.dart`, `lib/providers/page_background_provider.dart`, `lib/providers/mini_player_color_provider.dart`.
- Glass widgets: `lib/widgets/frosted_glass.dart`, `lib/widgets/liquid_glass_overlay.dart`.
- Backgrounds/palettes: `lib/widgets/page_custom_background.dart`, `lib/widgets/dynamic_album_background.dart`, `lib/widgets/album_visual_palette.dart`.
- Infinite canvas: `lib/screens/library_canvas_screen.dart`.
- MiniPlayer chrome: `lib/widgets/mini_player_chrome.dart`.
- Personalization: `lib/widgets/personalization/page_background_settings.dart`, `glass_effect_tile.dart`, `liquid_glass_toggle_tile.dart`, `mini_player_color_tile.dart`, `flowing_halo_background_tile.dart`, `personalization_choice_tile.dart`.
- Lyrics stage visuals: `lib/widgets/lyrics_stage/`, plus the shared UI helpers under `lib/widgets/lyrics/`.
