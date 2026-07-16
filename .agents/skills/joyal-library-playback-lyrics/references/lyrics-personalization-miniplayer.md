# Lyrics Personalization And MiniPlayer

## Personalization

- Pinch with two fingers on the lyrics page to open the in-place personalization drawer.
- Persist preferences through `lyrics_personalization_provider.dart` in secure storage.
- Persist color, renderer-specific font sizes, font family, and alignment. Color offers only `白色字体` and the dark-mode-oriented `动态浅色`; migrate removed system/black values to white. Keep default-scroll size, `flowingLightFontSize`, and `floatingNameFontSize` independent.
- Apply text alignment only to the default renderer. Offer exactly left, center, and right; migrate legacy `justify` to right. Do not show or apply alignment in `流光`.
- Persist `wordByWordEnabled`. It controls default timed highlighting and whether `流光` uses token motion or a complete-line fallback; lyrics download/cache continues while off.
- Apply `GlassEffectTarget.lyricsPage` non-current lyric fogging only to the default renderer. Hide those blur/opacity controls for independent stages.
- Keep the current lyric clear. Use `lyricsDrawer` as the drawer glass target.
- For custom `.ttf`, use `file_picker`, copy the font to app support storage, and register it through `FontLoader`.
- Fall legacy blackbody/rounded/handwriting values back to system fonts.
- Order the drawer as lyrics content (source and word highlighting), typography (alignment, size, font), display color, visual effects, then cache management. Keep copy brief and state that changes apply immediately.
- Use equal-width two-column choice grids; use a compact three-column alignment grid. Pair cache actions as equal-width buttons at the bottom. Do not alter source/cache behavior while reshaping the UI.

## MiniPlayer Lyrics

- Show the current and next lyric lines in the MiniPlayer middle area, not song title or artist.
- Reuse one vertical track for line changes and derive animation duration from the delta between adjacent lyric lines.
- Do not place the lyrics layout in a `ClipRect` with a negative offset that clips the left side.
- Keep lookup, pair timing, rolling animation, and text measurement in `lib/widgets/mini_player/mini_player_lyrics.dart`; the outer MiniPlayer only supplies the resulting widget to its morphing chrome.
