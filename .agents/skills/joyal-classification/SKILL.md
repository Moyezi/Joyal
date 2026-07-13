---
name: joyal-classification
description: "小Jo同学 tag-classification and climax-cache memory for Joyal Music. Use when changing MusicClassificationProvider, DeepSeek classification or climax requests, local classification/highlight storage, fixed vocabulary validation, manual tag correction, the 小Jo同学 management UI, or its discovery/settings entries."
---

# Joyal Classification

## Provider Contract

- `MusicClassificationProvider` owns configuration, connection test, batch classification, pause, resume, cancel, low-confidence handling, and forced reclassification.
- Normal classification skips manual-source results.
- Normal classification also skips results whose metadata hash, model, and vocabulary version have not changed.

## DeepSeek Safety

- DeepSeek API key lives only in secure storage under `deepseek_api_key`.
- Do not store the key in SQLite, JSON, logs, crash reports, or Git.
- Classification requests send only textual song metadata.
- Lyrics climax analysis reuses the same secure-storage API key and saved endpoint/model settings, but has its own service and derived-data cache; requests contain only title, artist, album, duration, and timed lyric text.
- Keep climax analysis separate from `DeepSeekClassificationService` and the classification store: `DeepSeekHighlightService` owns the request, `SongHighlightProvider` owns lazy orchestration, and `SongHighlightRepository` stores only the derived timeline. Never persist or log the API key with that timeline.
- If no API key is configured, guide the user to configuration. Do not describe the feature as already connected.

## Vocabulary And Validation

- Fixed vocabulary lives in `ClassificationVocabulary`.
- DeepSeek responses must be validated against the vocabulary.
- Each category may contain at most 3 tags.
- Energy value is 0-100.
- Because `Song` does not parse year yet, era/year is always `年份未知`.

## Storage

- `MusicClassificationRepository` stores classification config and results through `AppCacheService` as `music_classification_store` JSON.
- If storage later moves to SQLite, keep the UI/provider contract unchanged.

## Climax Cache Management

- Keep climax analysis lazy: entering an implemented independent lyrics stage with synchronized lyrics may analyze; opening `小Jo同学` or now playing must only read local cache.
- `recognizedSongHighlightsProvider` scans current-library song IDs in the active server scope, keeps non-empty timelines, and sorts them by `analyzedAt` descending so older caches remain discoverable without an index migration.
- `cachedSongHighlightProvider` is the read-only source for now-playing progress markers.
- Clearing one or all climax records deletes only `SongHighlightRepository` timelines. Never delete classification tags or lyrics cache with that action.

## Manual Correction

- Song detail classification tags support lightweight manual correction.
- Long-press genre, mood, or scene tags to show full-vocabulary multi-select.
- Tap the language row for single-select.
- Saving writes `ClassificationSource.manual`.

## UI Entry Points

- `MusicClassificationScreen` is the real entry.
- The user-facing feature name is `小Jo同学`; keep internal classification
  type/provider names stable unless a code-level rename is separately needed.
- Settings path: 设置 -> 小Jo同学.
- Only the discovery page title-bar icon opens it. Do not restore the former
  classification-status card below `为你发现`.
- The screen has separate tag, climax, and service tabs. Keep tag classification and manual correction available.
- Show the selected tag, climax, or service tab as a gray rounded capsule; suppress any sharp rectangular press/splash backing when switching tabs.
- Keep the `你的音乐整理台` header icon container square (currently `60 x 60`) so the pulse mark is not visually compressed.
- Before first classification, if no API key exists, show configuration guidance.
- Do not add "创建歌单" or "相似歌曲" buttons until provider/service capability exists.
- Do not ship placeholder entrances for incomplete classification features.

## Discovery Usage

- "为你发现" should prefer local classification tags.
- If classification data is insufficient, fall back only to real local collections such as favorites or random songs.
- Never display unsupported AI recommendations.

## Files To Check

- Model and vocabulary: `music_classification.dart`.
- DeepSeek service: `deepseek_classification_service.dart`.
- Storage: `music_classification_repository.dart`.
- Provider: `music_classification_provider.dart`.
- Screen state and provider actions: `music_classification_screen.dart`.
- Screen sections: `lib/widgets/classification/classification_screen_sections.dart`.
- Song detail/manual correction: `lib/widgets/song_actions/song_detail_dialog.dart`.
- Discovery entry: `hotlist_screen.dart`.
- Lyrics climax integration: `song_highlight_provider.dart`, `deepseek_highlight_service.dart`, `song_highlight_repository.dart`, `models/song_highlight.dart`, `widgets/lyrics_stage/flowing_light_lyrics_stage.dart`.
