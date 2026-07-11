---
name: joyal-settings-cache-release
description: "Settings, cache, download, and build memory for Joyal Music. Use when changing SettingsHubScreen, personalization settings, cache/download management, CachedDiskImage keys, AppCacheService JSON work, validation commands, APK release builds, file_picker pinning, or liquid_glass_easy build caveats."
---

# Joyal Settings Cache Release

## Settings

- Settings entry is the lower-left button in the home right-swipe sidebar.
- It opens `SettingsHubScreen`.
- `SettingsHubScreen` is a two-column grid with six cards: server connection,
  personalization, intelligent classification, downloads, cache, and about.
- Its cards follow the "为你发现" visual language: restrained gradient,
  subtle border/shadow, lower-right ambient light, and a small pressed-state
  scale/motif response. Do not restore the old one-column list layout.
- Personalization is entered from the `个性化设置` card. Do not add back the
  former `外观` card or duplicate theme-mode cycling there.
- Library refresh belongs to the connected state of `SettingsScreen` (server
  connection), not as a top-level settings card. It calls
  `libraryProvider.notifier.refreshLibrary()` and must never report success
  when disconnected.

## Cache And Downloads

- Cache statistics and cleanup are managed by `CacheRepository` and bucket-specific logic.
- Expensive directory statistics should use `Isolate.run` to avoid blocking UI.
- Offline downloads should navigate to download management and must not accidentally delete downloads.
- Image display should prefer `CachedDiskImage`: check disk by stable `cacheKey` before network.
- Album and song cover keys use stable `coverArtId`.
- Artist avatars must not use `String.hashCode` as a persistent cache key.
- `AppCacheService` manages small JSON caches.
- Do not call `Isolate.run(() => jsonEncode(value))` inside an instance method when that closure captures instance fields.

## Cache Limit Settings

- Auto-clean slider stops are 500MB, 1GB, 2GB, 5GB, and unlimited.
- Store the limit in secure storage.
- Also mirror it to the `cache_settings` JSON fallback.
- Load settings before allowing statistics refresh on startup.

## Validation Commands

- Static analysis: `dart analyze lib test` or `flutter analyze`.
- Full test suite: `flutter test`.
- Common focused tests:
  - `flutter test test/widget_test.dart`
  - `flutter test test/home_search_animation_test.dart`
  - `flutter test test/now_playing_visual_song_test.dart`
  - `flutter test test/cache_provider_test.dart`
  - `flutter test test/lyrics_provider_test.dart`
- Sidebar gesture regressions:
  - `Home content does not scroll vertically while opening sidebar`
  - `Home sidebar drag preserves existing home scroll offset`
  - `Home sidebar closes on a fast left fling`

## Release Build

- Default APK review target is arm64 Release:

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```

- Release output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- `--no-tree-shake-icons` is currently used to bypass the icon tree-shaking build issue.

## Dependency Caveats

- `file_picker` is pinned to `10.3.3` for custom lyrics `.ttf`.
- `file_picker` 11.x can fail to compile the Android plugin class with the current Flutter/AGP combination.
- Old 3.x versions still use `jcenter()`.
- `android/build.gradle.kts` unifies the `:file_picker` Kotlin JVM target to 11.
- `liquid_glass_easy 3.2.x` may emit shader/SkSL compatibility warnings during build/test.
- Current arm64 Release builds successfully; treat those warnings as non-fatal for now.

## Files To Check

- Settings: `settings_hub_screen.dart`, `settings_screen.dart`,
  `personalization_screen.dart`.
- Cache: `app_cache_service.dart`, `cache_repository.dart`, `cache_provider.dart`, `cache_management_screen.dart`.
- Images: `cached_disk_image.dart`.
- Android build: `android/build.gradle.kts`, `pubspec.yaml`, `pubspec.lock`.
