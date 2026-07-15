# Lyrics Stage Foundations

Read this for changes shared by independent lyrics stages: shell architecture, route backgrounds, headers, lifecycle, geometry, or layout caching. Renderer-specific behavior lives in the sibling `flowing-light-stage.md` and `floating-name-stage.md`; DeepSeek climax/palette behavior lives in `lyrics-ai-analysis.md`.

## Architecture And Lifecycle

- Keep the default scrolling renderer available as the stable default. Persist only available stage modes through `lyrics_personalization_provider.dart`; `群唱` remains a disabled `待完成` entry and must not persist when selected.
- Treat independent stages as foreground renderers, not skins over `_LyricsList` and not duplicate full-screen backgrounds. Share a small `lyrics_stage_shell.dart`, lyric timing runtime, palette inputs, empty states, gestures, and lifecycle handling; keep each stage's typography, composition, animation, and painting in its own renderer.
- Reuse the single `DynamicAlbumBackground` owned by the enclosing now-playing route. Child stages render foreground only.
- Accept the same `LyricsData` model and degrade gracefully for synchronized line lyrics or plain lyrics without `LyricLine.words` timing.
- Give every stage an explicit visible/covered lifecycle. Stop tickers, high-frequency position subscriptions, camera motion, and local effect painting while hidden, covered by settings, after returning to now playing, or under reduced motion.
- Precompute and cache expensive text/bubble layouts by song identity, viewport, font, font size, renderer settings, and any layout-affecting analysis signature. Prepare active/upcoming lines before transitions; playback position updates only the smallest active reveal or camera transform.
- Keep static and reduced-cost fallbacks for devices that cannot sustain full effects. Do not stack full-screen blur/refraction or continuously repainting backgrounds.
- Preserve Joyal's visual identity; do not copy AGPL Folia source into this project.

## Shared Header And Composition

- Center default and independent-stage compositions against the full phone screen. Render song/artist as an overlay; never reserve header height that shifts content below center.
- Keep the header visible while the lyrics surface enters. Once settled, keep it for 5 seconds, then fade it over about 720 ms. Opening settings must not restart the timer.
- `流光` and `浮名` share `lib/widgets/lyrics_stage/lyrics_stage_shell.dart` for full-screen composition, the overlaid header, and pinch gesture.
