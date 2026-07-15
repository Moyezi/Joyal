---
name: joyal-library-playback-lyrics
description: "Library, playback, and lyrics memory for Joyal Music. Use when changing Navidrome credential restore, refreshLibrary, library sorting, the infinite library canvas, favorites, queue construction, PlayerNotifier, just_audio source sequences, listening stats, lyrics cache/prefetch, LyricsScreen, lyrics stage renderers, or MiniPlayer lyrics."
---

# Joyal Library Playback Lyrics

## Core Contracts

- Keep credentials in secure storage and let dependent providers rebuild before the startup library refresh.
- Build playback queues from the complete current collection, never a progressively revealed UI subset.
- Use `PlayerNotifier.playAtIndex()` as the unified track/queue selection entry and `PlayerNotifier.playNext()` for “下一首播放”.
- Keep playback direct through Navidrome `stream.view&format=raw`; do not add abnormal auto-next recovery, jump-back behavior, or extra seek protection.
- Scope lyrics caches and AI-derived lyrics data by server/user/song identity. Never send credentials, server addresses, media URLs, or cover URLs to AI services.
- Restrict high-frequency playback-position updates to the smallest active lyric/progress subtree.
- Keep `lyrics_screen.dart` as page orchestration; put default lyrics UI under `lib/widgets/lyrics/` and independent stages under `lib/widgets/lyrics_stage/`.

## Reference Routing

Read only the references needed for the task:

- [Library and playback](references/library-playback.md): startup restore, refresh, sorting, infinite-canvas playback actions, favorites, queues, background playback, and listening stats.
- [Lyrics data and screen](references/lyrics-data-screen.md): source priority, AMLL/OpenSubsonic parsing, cache/prefetch, screen orchestration, and the default renderer.
- [Lyrics stage foundations](references/lyrics-stage-foundations.md): shared shell, route background ownership, header geometry, renderer lifecycle, and layout caching.
- [Flowing Light stage](references/flowing-light-stage.md): `流光` scattered layout, token reveal/halo, climax ring presentation, and ambient rocking.
- [Floating Name stage](references/floating-name-stage.md): `浮名` world layout, camera, print stamp, gap drift, and wait cursor.
- [Lyrics AI analysis](references/lyrics-ai-analysis.md): shared DeepSeek climax timeline, AI text palette, cache invalidation, provider lifetime, and management rules.
- [Lyrics personalization and MiniPlayer](references/lyrics-personalization-miniplayer.md): personalization drawer, persisted controls, custom fonts, cache actions, and rolling MiniPlayer lyrics.

## File Routing

- Library/API: `lib/services/subsonic_api.dart`, `lib/providers/library_provider.dart`, `lib/screens/library_screen.dart`, `lib/screens/library_canvas_screen.dart`.
- Playback/stats: `lib/services/audio_player_service.dart`, `lib/providers/player_provider.dart`, `lib/providers/listening_stats_provider.dart`, `lib/widgets/play_queue_sheet.dart`.
- Lyrics data/orchestration: `lib/screens/lyrics_screen.dart`, `lib/providers/lyrics_provider.dart`, `lib/providers/lyrics_personalization_provider.dart`, `lib/widgets/lyrics/`.
- Lyrics AI and analysis: `lib/providers/lyrics_ai_palette_provider.dart`, `lib/providers/song_highlight_provider.dart`, `lib/models/lyrics_ai_palette.dart`, `lib/models/song_highlight.dart`, and the corresponding services/repositories under `lib/services/`.
- Lyrics stages: `lib/widgets/lyrics_stage/`.
- MiniPlayer lyrics: `lib/widgets/mini_player/mini_player_lyrics.dart`, `lib/widgets/mini_player/mini_player_chrome.dart`.
