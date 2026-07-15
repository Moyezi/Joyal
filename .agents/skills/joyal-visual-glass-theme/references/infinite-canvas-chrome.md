# Infinite Canvas And Chrome

## Infinite Library Canvas

- Treat the hexagon as the logical outline of scattered song positions. Do not clip the viewport to a hexagon or draw a fixed hexagonal screen border.
- Place songs in complete axial rings. Distribute an incomplete final ring evenly so the collection remains approximately hexagonal.
- Keep cards separated. Drag freely, snap the nearest song to center on release, and animate tapped songs to center.
- Use one fixed `224` logical-pixel card layout. Derive apparent size/opacity continuously from center distance through `Transform.scale` and `Opacity`; do not resize layout, padding, typography, or `Positioned` bounds per pan update.
- Render only cells near the viewport. Use `CachedDiskImage` and isolate each card with `RepaintBoundary`.
- Drive pan/snap offsets through local `ValueNotifier<Offset>` or another small listenable subtree so pointer events do not rebuild the scaffold, header, providers, or unrelated UI.
- Keep visible child order stable while panning and lift only the nearest card when focus changes. Key positioned cards by stable song ID so cached covers never move between songs or flash.
- Keep fixed cover `decodeWidth` across focus scaling; do not derive it from animated card width.
- Keep one stable `ImageFiltered` node across clear/blur transitions and change only sigma/`enabled`. Disable per-card blur during direct drag and snap animation, restoring distance blur after settling.
- Keep the canvas header title capsule on the viewport's horizontal center. Put Back on its left and the matching recenter control on its right, with equal-width outer control slots so either action cannot shift or squeeze the title.
- For playback behavior and queue construction, also read [library and playback](../../joyal-library-playback-lyrics/references/library-playback.md).

## Borders And MiniPlayer Chrome

- Do not add bright/gray strokes to floating rounded glass elements such as search boxes, Dock, MiniPlayer, `SongTile`, and `QueueSongCard`.
- When `FrostedGlass.borderOpacity` is 0, create no border. Personalization previews must follow real border behavior.
- Control MiniPlayer color through `mini_player_color_provider.dart`; default background is `AppTheme.miniPlayerBg`.
- Reuse `AlbumVisualPalette` for dynamic tint. Keep capsule tint and collapsed-cover outer frame matched while respecting glass blur/opacity.
- Share `mini_player_chrome.dart` between the real MiniPlayer and personalization preview.
- Dynamic preview follows the current playing cover. If no palette exists, use a neutral fallback; never fake color from `coverArtId.hashCode`.
