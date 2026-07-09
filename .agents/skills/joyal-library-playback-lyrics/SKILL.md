---
name: joyal-library-playback-lyrics
description: "Library, playback, and lyrics memory for Joyal Music. Use when changing Navidrome credential restore, refreshLibrary, library sorting, favorites, queue construction, PlayerNotifier, just_audio source sequences, listening stats, lyrics cache/prefetch, LyricsScreen, or MiniPlayer lyrics."
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

- `ListeningStatsNotifier` records only locally listened unique song IDs.
- Sidebar "听歌概览" progress equals listened unique songs divided by current total library songs.

## Lyrics Cache And Prefetch

- On track change, prefetch current and next lyrics in the background and write them to local JSON cache.
- Do not promise full queue and progress restoration after the app is completely closed.
- Lyrics cache keys are scoped by `baseUrl + username + song.id`.
- Empty lyrics are cached only short-term.
- On lyrics failure, remove the in-memory Future cache.

## Lyrics Screen

- `LyricsScreen` loads immediately after initialization; do not wait for horizontal swipe animation to finish.
- The lyrics page shows no back button and no title `歌词`.
- The fixed top area shows only the current song name and artist.
- When the lyrics page is visible or during the horizontal transition, disable the outer now-playing downward-close gesture.
- Exiting the lyrics page uses the existing horizontal swipe/switching flow.

## Lyrics Personalization

- Pinch with two fingers on the lyrics page opens the in-place personalization drawer.
- Preferences are stored by `lyrics_personalization_provider.dart` in secure storage.
- Preferences include color, alignment, font size, and font family.
- Non-current lyric fogging is controlled by `GlassEffectTarget.lyricsPage`.
- The current lyric remains clear.
- The drawer glass target is `lyricsDrawer`.
- Custom `.ttf` selection uses `file_picker`, then copies the font to app support storage and registers it through `FontLoader`.
- Legacy blackbody/rounded/handwriting font values fall back to system fonts.

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
- Lyrics: `lyrics_screen.dart`, `lyrics_provider.dart`, `lyrics_personalization_provider.dart`.
- MiniPlayer: `mini_player.dart`, `mini_player_chrome.dart`.
