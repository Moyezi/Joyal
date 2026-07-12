---
name: joyal-library-playback-lyrics
description: "Library, playback, and lyrics memory for Joyal Music. Use when changing Navidrome credential restore, refreshLibrary, library sorting, the infinite library canvas, favorites, queue construction, PlayerNotifier, just_audio source sequences, listening stats, lyrics cache/prefetch, LyricsScreen, lyrics stage renderers, or MiniPlayer lyrics."
---

# Joyal Library Playback Lyrics

## Startup And Library Refresh

- On startup, restore Navidrome credentials from secure storage.
- After authentication restore, wait for dependent providers to rebuild before refreshing the library.
- Startup overlay covers credential reads and local playback-session restore so MiniPlayer and Dock do not flash.
- `refreshLibrary()` refreshes albums, full songs, and favorites in parallel.
- Albums use paged `getAlbumList2.view`.
- Full songs use empty-query `search3.view` with `songOffset` paging.
- Library page refresh calls `refreshLibrary()`.
- Discovery page refresh first refreshes local "为你发现" seeds, then tries `fetchStarred()` for favorites.
- If not connected, discovery refresh only updates local recommendations and tells the user favorite refresh needs a server connection.

## Library UI And Sorting

- The library song sort button sits at the upper right in the same row as locate-current-song and refresh.
- Persist sort condition to secure storage.
- Sort Chinese song names and artists by the pinyin first letter of the initial Han character.
- The library songs tab may progressively reveal items in the UI.
- Playback, locating the current song, and queue construction must always use the full sorted list, not the visible subset.

## Infinite Library Canvas Playback

- Build `LibraryCanvasScreen` from the full `libraryProvider.songs` collection while rendering only the visible spatial neighborhood.
- Center-card play must start the full library queue at that song; toggling the already-current song may use play/pause. "下一首播放" must call `PlayerNotifier.playNext()`.
- Keep playback actions available on the cards, but do not embed a MiniPlayer capsule in the canvas route.

## Favorites

- Favorite state is shared.
- Apply favorite changes optimistically.
- Roll back on failure.
- Discovery favorites should update from shared state without manual refresh.

## Playback Queue Contract

- The player uses `just_audio` multi-track source sequences.
- Search, discovery carousel, favorites, albums, and full-library songs all build real queues from the current collection.
- `PlayerNotifier.playAtIndex()` is the unified entry for switching tracks and selecting queue items.
- The user explicitly requested no abnormal auto-next recovery, no jump-back behavior, and no extra seek protection logic.
- Keep playback as direct as possible through Navidrome `stream.view&format=raw`.
- Lock-screen/background stop issues should be handled through platform audio support, not fake auto-next recovery: Android uses `JoyalPlaybackService` as a `mediaPlayback` foreground service and iOS declares `UIBackgroundModes/audio`.

## Listening Stats

- `ListeningStatsNotifier` records locally listened unique song IDs and an ordered recent-played song ID list.
- Recent-played IDs are local-only, deduped by moving repeat plays to the front, capped at 24, and persisted in secure storage with the unique heard IDs.
- Sidebar "听歌概览" progress equals listened unique songs divided by current total library songs.

## Lyrics Cache And Prefetch

- On track change, prefetch current and next lyrics in the background and write them to local JSON cache.
- Do not promise full queue and progress restoration after the app is completely closed.
- Lyrics cache keys are scoped by `baseUrl + username + song.id`.
- Empty lyrics are cached only short-term.
- On lyrics failure, remove the in-memory Future cache.
- `raw-lyrics-index.jsonl` is bundled as a Flutter asset. `LyricsService` loads it once and conservatively matches title plus artist, preferring a matching album.
- AMLL source priority is `qq-lyrics`, `ncm-lyrics`, `spotify-lyrics`, then `am-lyrics`; download URLs use `https://raw.githubusercontent.com/amll-dev/amll-ttml-db/refs/heads/main/<source>/<id>.ttml`.
- Parse TTML `<p>` and timed foreground `<span>` elements into `LyricLine.words`, cache the parsed timing with the lyric JSON, and fall back to Navidrome structured/legacy embedded lyrics whenever index matching, download, or parsing fails.
- Fetch embedded lyrics through enhanced OpenSubsonic `getLyricsBySongId.view?id=<songId>&enhanced=true`, with legacy `getLyrics.view` as the compatibility fallback.
- Automatic source priority is embedded word-by-word, AMLL TTML, embedded synchronized line-by-line, then embedded plain text. The per-song `embedded` source setting skips AMLL but still accepts embedded word-by-word and line-by-line lyrics.
- Enhanced embedded word timing can arrive as OpenSubsonic `cueLine`/`cue` data or LDDC enhanced LRC using `[line time]` plus `<word time>` markers. Convert both forms into complete `LyricLine` rows with `LyricWord` timing; never expose one character as a separate lyric row.
- For `cueLine`, keep the first vocal agent for each line index, use the combined `line` value as fallback text, and interpret `byteStart`/`byteEnd` as inclusive UTF-8 byte ranges so multibyte lyrics and gaps are reconstructed exactly.
- Only use structured entries whose `kind` is absent/empty or `main`. If several line-level candidates remain, prefer synchronized content and then the more complete text. Reject suspicious fragmented line sets dominated by single-character rows.
- Embedded LRC parsing supports hour-bearing timestamps, comma or period fractions, multiple word markers, and `[offset:+/-milliseconds]`; clamp negative adjusted times to zero.
- `LyricsData.source` persists the resolved content type: none, embedded word-by-word, AMLL TTML, embedded synchronized, or embedded plain text. The personalization drawer shows this resolved source separately from the user's source-mode setting.
- Lyrics cache names use the `lyrics_v2_` prefix because parsed source metadata and enhanced embedded timing are part of the cached schema.
- The lyrics personalization drawer can re-fetch or clear the current song's cache. Clearing keeps the visible lyric until the next request; re-fetch bypasses fresh cache.

## Lyrics Screen

- `LyricsScreen` loads immediately after initialization; do not wait for horizontal swipe animation to finish.
- The lyrics page shows no back button and no title `歌词`.
- The fixed top area shows only the current song name and artist.
- Treat the fixed song/artist header as an overlay. Center the default active lyric against the full phone-screen viewport, not the remaining area below the header; keep symmetric vertical list breathing room so removing the header reserve does not crowd edge lines.
- When the lyrics page is visible or during the horizontal transition, disable the outer now-playing downward-close gesture.
- Exiting the lyrics page uses the existing horizontal swipe/switching flow.
- The default scrolling renderer has a Folia-inspired focus transition in `_FoliaLineFocus`: the active line returns to full scale while passed and upcoming lines recede slightly to opposite horizontal sides. Keep this as the default renderer rather than treating it as one of the future full-screen stage modes.
- Word-by-word presentation uses `lyricGlyphProgress()` to distribute each `LyricWord` time range across Unicode grapheme clusters. `_TimedLyricText` renders a glyph-level color sweep with a short glow only at the reveal frontier.
- Only the active timed line may watch high-frequency player position. Inactive lines, the whole list, the background, and future stage shells must not rebuild for every position update.

## Independent Lyrics Stages

- The independent lyrics stage selector is persisted through `lyrics_personalization_provider.dart`. The stable default scrolling renderer remains available.
- `流光` is implemented as its own renderer in `lib/widgets/lyrics_stage/flowing_light_lyrics_stage.dart`. It displays only the active line, splitting Chinese into graphemes and Latin runs into whole words. Use a deterministic scattered layout: common lines form 3–4 vertical rows with about 2–3 tokens per row, irregular spacing and offsets, and normally distributed token rotation clamped to ±25°. Untimed lyrics and disabled word-by-word display keep the same scattered layout but reveal statically.
- With word timing, future tokens reserve invisible positions so revealed text never shifts. Each token appears at about 116% scale and settles to 100% over 520 ms. Keep the outward entrance ring short, but make the soft highlight interval adaptive: hold full brightness from this token's start until the next Chinese grapheme or Latin word starts, including timing gaps, then overlap the next token with a smooth 520 ms fade-out instead of clearing the previous halo immediately. For the final token, use the line end and keep its soft highlight breathing until the next lyric line activates; never repeat its outward ring or render a dim pending-text mask. Drive this from the active playback-position updates instead of adding another persistent controller; reduced-motion/covered states keep only a static highlight.
- Center independent stage compositions against the full phone screen as well. The fixed header remains an overlay and must not shift the stage center downward.
- The whole settled composition loops upward by at most 10% of font size and back over 3.6 seconds. Keep its controller and painting inside the active composition `RepaintBoundary`; settings coverage, hidden lyrics pages, disabled position updates, and reduced-motion settings must stop/reset it. Only the active token composition watches playback position.
- `浮名` and `群唱` remain planned. Their disabled `待完成` entries stay visible in the lyrics personalization drawer, but selecting them must not persist an unavailable renderer.
- These themes are not skins over `_LyricsList`. Give each theme its own renderer and animation grammar, while sharing a small stage shell, lyric timing runtime, theme/palette inputs, empty states, gestures, and lifecycle handling.
- Keep the current scrolling lyrics renderer available as the stable default. Persist available stage modes through `lyrics_personalization_provider.dart` in secure storage and expose them through the existing in-place personalization flow.
- Stage renderers must accept the same `LyricsData` model and degrade gracefully for synchronized line lyrics or plain lyrics when `LyricLine.words` has no timing.
- Precompute and cache expensive text layout by song identity, viewport, font, font size, and renderer settings. Prepare the active and upcoming line before a transition instead of measuring the full composition on every playback tick.
- Avoid one giant renderer with mode branches. Keep the shared stage shell/runtime and each finished renderer under `lib/widgets/lyrics_stage/`, with one file or folder per `浮名`, `流光`, and `群唱` renderer.
- Preserve Joyal's visual identity and implement the concepts cleanly in Flutter; do not copy AGPL Folia source code into this project.

## Lyrics Personalization

- Pinch with two fingers on the lyrics page opens the in-place personalization drawer.
- Preferences are stored by `lyrics_personalization_provider.dart` in secure storage.
- Preferences include color, alignment, renderer-specific font sizes, and font family. Persist default-scroll size and `flowingLightFontSize` independently; changing one renderer's size must not alter the other.
- Apply text alignment only to the default scrolling renderer. Expose exactly left, center, and right alignment; migrate the legacy stored `justify` value to right. Do not apply or show alignment controls in `流光`.
- Preferences also include the persisted `wordByWordEnabled` switch. It affects the default renderer's timed highlight and whether `流光` uses token-by-token motion or its complete-line fallback; downloading and caching still proceed while it is off.
- Non-current lyric fogging is controlled by `GlassEffectTarget.lyricsPage` and applies only to the default scrolling renderer. Hide the non-current-line blur/opacity section while `流光` is selected.
- The current lyric remains clear.
- The drawer glass target is `lyricsDrawer`.
- Custom `.ttf` selection uses `file_picker`, then copies the font to app support storage and registers it through `FontLoader`.
- Legacy blackbody/rounded/handwriting font values fall back to system fonts.
- Keep the drawer order as: lyrics content (source and word highlighting), typography (alignment, size, font), display color, visual effects, then cache management. Keep copy brief and state that changes apply immediately.
- Use equal-width two-column choice grids; alignment is a compact three-column grid. Cache actions are paired equal-width buttons at the bottom. Do not change source/cache behavior when reshaping this UI.

## MiniPlayer Lyrics

- The MiniPlayer middle area shows the current lyric line and next lyric line.
- It does not show song title or artist there.
- Line changes reuse one vertical track.
- Animation duration follows the time delta between adjacent lyric lines.
- Do not place the lyrics layout inside a `ClipRect` with negative offset that clips the left side.

## Files To Check

- API and library: `lib/services/subsonic_api.dart`, `library_provider.dart`.
- Player: `audio_player_service.dart`, `lib/providers/player_provider.dart`, `play_queue_sheet.dart`.
- Stats: `listening_stats_provider.dart`.
- Lyrics: `lyrics_screen.dart`, `lyrics_provider.dart`, `lyrics_personalization_provider.dart`, `widgets/lyrics_stage/flowing_light_lyrics_stage.dart`.
- MiniPlayer: `mini_player.dart`, `mini_player_chrome.dart`.
- Infinite library canvas: `library_canvas_screen.dart`.
