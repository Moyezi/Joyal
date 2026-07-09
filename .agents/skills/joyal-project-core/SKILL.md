---
name: joyal-project-core
description: "Project-level memory for Joyal Music. Use when making broad architectural choices, touching credentials/security, Subsonic/Navidrome API boundaries, Android media bridge, repository conventions, key file routing, or deciding which more specific Joyal project skill to load."
---

# Joyal Project Core

## Scope

Use this skill as the project entry point. For a focused change, also read the narrower project skill listed in `AGENTS.md`.

Joyal Music is a Flutter iOS/Android private music player for user-hosted Navidrome servers. It fetches library data, cover art, lyrics, and audio through the Subsonic/OpenSubsonic API.

The visual direction is minimal, immersive, cool black/white/gray, large-radius, and softly layered. UI changes should preserve the overall spatial feel instead of mechanically copying one isolated dimension.

## Stack

- Flutter / Dart / Material 3.
- Riverpod manages app state.
- `just_audio` handles playback.
- `dio` handles requests.
- Cover art should prefer local disk cache.

## Security Contracts

- Store credentials, search history, playback progress, theme, page background, cache limit, frosted-glass settings, and similar preferences in `flutter_secure_storage`.
- Also mirror the cache size limit into the `AppCacheService` JSON fallback.
- Authenticate Subsonic with random salt plus `md5(password + salt)` token.
- Never write or transmit real plaintext credentials.
- Prefer HTTPS for public Navidrome servers.
- Android media bridge must pass only playback metadata and local cover paths. Do not pass stream URLs, tokens, passwords, or `baseUrl`.
- Android locked-screen playback is backed by `JoyalPlaybackService`, a native `mediaPlayback` foreground service driven by `AndroidMediaBridge` snapshots; it may hold a partial wake lock while playing, but still must never receive stream URLs or credentials.
- `OppoFluidCloudBridge` is only reserved for a future SDK. Current behavior relies on standard `MediaSession`.
- Store the DeepSeek API key only in secure storage under `deepseek_api_key`.
- Never write the DeepSeek API key to SQLite, JSON, logs, crash reports, or Git.
- Classification requests may send only textual song metadata.

## Key Paths

- API and playback: `lib/services/subsonic_api.dart`, `audio_player_service.dart`, `lib/providers/player_provider.dart`, `listening_stats_provider.dart`.
- Library, search, and discovery: `library_provider.dart`, `home_screen.dart`, `library_screen.dart`, `hotlist_screen.dart`, `search_screen.dart`. The discovery page file is still named `HotlistScreen`.
- Discovery widgets: `lib/widgets/discovery/discover_song_carousel.dart`, `for_you_discovery_section.dart`, `discovery_playlist_card.dart`, `discovery_card_models.dart`, `classification_status_card.dart`, `discovery_section_header.dart`.
- Navigation, settings, and dock: `lib/app.dart`, `home_sidebar.dart`, `mini_player.dart`, `bottom_nav.dart`, `play_queue_sheet.dart`, `settings_hub_screen.dart`, `personalization_screen.dart`.
- Visual effects and backgrounds: `page_background_provider.dart`, `glass_effect_provider.dart`, `visual_effect_provider.dart`, `mini_player_color_provider.dart`, `frosted_glass.dart`, `liquid_glass_overlay.dart`, `glass_top_bar.dart`, `page_custom_background.dart`, `dynamic_album_background.dart`, `album_visual_palette.dart`, `mini_player_chrome.dart`.
- Personalization widgets: `lib/widgets/personalization/page_background_settings.dart`, `glass_effect_tile.dart`, `liquid_glass_toggle_tile.dart`, `mini_player_color_tile.dart`, `personalization_choice_tile.dart`.
- Now playing and lyrics: `now_playing_screen.dart`, `lyrics_screen.dart`, `lyrics_provider.dart`, `lyrics_personalization_provider.dart`, `waveform_progress.dart`, `now_playing_transition.dart`.
- Downloads and cache: `app_cache_service.dart`, `cache_repository.dart`, `cache_provider.dart`, `cache_management_screen.dart`, `cached_disk_image.dart`.
- Classification: `music_classification.dart`, `deepseek_classification_service.dart`, `music_classification_repository.dart`, `music_classification_provider.dart`, `music_classification_screen.dart`.
- Android media bridge and background playback: `android/app/src/main/kotlin/com/example/joyal_music/`, especially `JoyalMediaSessionManager.kt`, `JoyalPlaybackService.kt`, and `PlaybackSnapshot.kt`.
- iOS background audio capability: `ios/Runner/Info.plist` declares `UIBackgroundModes/audio`.

## Collaboration Boundaries

- Keep user changes. Do not revert unrelated edits.
- Some older files may display Chinese mojibake in PowerShell. Do not bulk-rewrite unrelated code because of display encoding. Prefer explicit UTF-8 when reading Chinese files.
- Add UI actions only after confirming the provider/service capability exists. Do not present placeholder UI as complete.
- When external dependencies are involved, such as vendor SDKs, accounts, or remote services, clearly distinguish "reserved/bridged" from "actually integrated".
- The user often reviews UI by real-device screenshots. After UI changes, prefer producing an arm64 release APK for review when feasible.
- Keep project memory concise. Preserve constraints, paths, commands, and known pitfalls that affect implementation decisions; remove stale logs and facts that can be read directly from code.
