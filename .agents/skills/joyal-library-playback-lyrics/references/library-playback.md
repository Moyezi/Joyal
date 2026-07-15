# Library And Playback

## Startup And Library Refresh

- On startup, restore Navidrome credentials from secure storage.
- After authentication restore, wait for dependent providers to rebuild before refreshing the library.
- Startup overlay covers credential reads and local playback-session restore so MiniPlayer and Dock do not flash.
- `refreshLibrary()` refreshes albums, full songs, and favorites in parallel.
- Albums use paged `getAlbumList2.view`.
- Full songs use empty-query `search3.view` with `songOffset` paging.
- Library page refresh calls `refreshLibrary()`.
- Discovery page refresh first refreshes local “为你发现” seeds, then tries `fetchStarred()` for favorites.
- If not connected, discovery refresh only updates local recommendations and tells the user favorite refresh needs a server connection.

## Library UI And Sorting

- Place the library song sort button at the upper right in the same row as locate-current-song and refresh.
- Persist the sort condition to secure storage.
- Sort Chinese song names and artists by the pinyin first letter of the initial Han character.
- The library songs tab may progressively reveal items in the UI.
- Playback, locating the current song, and queue construction must always use the full sorted list, not the visible subset.

## Infinite Library Canvas Playback

- Build `LibraryCanvasScreen` from the full `libraryProvider.songs` collection while rendering only the visible spatial neighborhood.
- Center-card play starts the full library queue at that song; toggling the already-current song may use play/pause. “下一首播放” calls `PlayerNotifier.playNext()`.
- Drive the center-card action icon and tooltip from whether that card is the current playing song: show pause only while actively playing, otherwise play. Select this state inside the action subtree so playback changes do not rebuild the whole canvas.
- The canvas recenter control locates the current playing song by stable song ID. If there is no current song or it is absent from the library, animate to index `0`, the canvas's logical origin.
- Keep playback actions on cards, but do not embed a MiniPlayer capsule in the canvas route.
- Read [infinite canvas and chrome](../../joyal-visual-glass-theme/references/infinite-canvas-chrome.md) when changing canvas geometry, cover-depth transitions, or rendering performance.

## Favorites

- Keep favorite state shared.
- Apply favorite changes optimistically and roll back on failure.
- Discovery favorites update from shared state without manual refresh.

## Playback Queue Contract

- Use `just_audio` multi-track source sequences.
- Search, discovery carousel, favorites, albums, and full-library songs all build real queues from the current collection.
- Use `PlayerNotifier.playAtIndex()` as the unified entry for switching tracks and selecting queue items.
- Do not add abnormal auto-next recovery, jump-back behavior, or extra seek protection logic.
- Keep playback direct through Navidrome `stream.view&format=raw`.
- Handle lock-screen/background stop issues through platform audio support: Android uses `JoyalPlaybackService` as a `mediaPlayback` foreground service and iOS declares `UIBackgroundModes/audio`.

## Listening Stats

- `ListeningStatsNotifier` records locally listened unique song IDs and an ordered recent-played song ID list.
- Recent-played IDs are local-only, deduped by moving repeat plays to the front, capped at 24, and persisted in secure storage with unique heard IDs.
- Sidebar “听歌概览” progress equals listened unique songs divided by current total library songs.
