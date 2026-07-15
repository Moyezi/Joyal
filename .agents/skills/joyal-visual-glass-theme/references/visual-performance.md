# Visual Performance

## Lifecycle And Update Scope

- Treat battery use, thermals, and frame pacing as part of visual quality. Reject effects that continuously repaint or recompute without a meaningful visible change.
- Default to static or cached compositions. Give continuous animation one visible purpose, one owner, and a lifecycle that stops while hidden, fully covered, or non-interactive.
- Never stack duplicate full-screen backgrounds during transitions. Now playing and lyrics share one `DynamicAlbumBackground`; child pages render foreground only.
- Disable tickers, high-frequency position subscriptions, and painting on hidden playback/lyrics pages. System back, buttons, and swipe exits must restore the newly visible page's updates.
- While moving a large glass drawer, freeze the dynamic background and full-area refraction below it. Use a tinted no-blur transition treatment and restore glass after the route settles.
- Limit playback-position updates to the active word, progress control, or changed MiniPlayer lyric pair. Never rebuild whole pages, lyric lists, palettes, backgrounds, or glass surfaces per tick.
- For tunable continuous effects, update in memory during drag and persist on release. `flowingHaloBackgroundProvider` defaults to 20 FPS and offers 5–60 FPS through `FlowingHaloBackgroundTile`.

## Blur And Compositing

- Do not create `BackdropFilter` when blur is ineffective or the mask is nearly opaque.
- Use `ImageFiltered` when blurring a widget's own image. Avoid dynamic full-screen `BackdropFilter`.
- For large static backgrounds that intentionally destroy detail, decode/render at reduced logical size, apply `ImageFiltered`, then compositor-scale the finished layer up. Multiply sigma by the raster scale so final blur radius remains equivalent. Clip and isolate in a `RepaintBoundary`.
- `DynamicAlbumBackground._CoverGlassBackground` is the reference: raster scale `0.32`, correspondingly reduced `decodeWidth` and sigma, then scale by `1 / rasterScale`. Preserve the full-resolution bypass when blur is ineffective.
- Use reduced-raster blur only for large, heavily blurred self-images such as cover backgrounds—not text, sharp chrome, lightly blurred surfaces, or fine-detail content.
- Optimize raster area, repaint isolation, lifecycle, and compositing before throttling. Do not lower foreground/interaction frame rate merely to mask expensive blur.
- Keep flowing-halo painting throttled through `_ThrottledRepaint`; do not restore a widget-level `AnimatedBuilder` that rebuilds the whole background at display refresh rate.
- Prefer `provider.select` or a local `Consumer` for high-frequency UI.
