# Lyrics AI Analysis

## Climax Timeline

- Let implemented synchronized stages request the shared DeepSeek climax timeline on demand. Send only title, artist, album, duration, and timed lyric text using the secure-storage 小Jo API key/endpoint/model configuration.
- Cache results through `SongHighlightRepository` by server scope and song. Include metadata, duration, lyric text, and line timing in `lyricsAnalysisHash`; regenerate when model or hash changes. Cached results remain readable after API-key removal or offline.
- Normalize segments with `normalizeHighlightSegments()`: sort, clamp to song duration, merge overlaps, and retain at most 3.
- `流光` gates ordinary-token outward rings with the climax timeline. AI semantic keywords retain keyword-colored rings outside climax segments. `浮名` prelays lines overlapping climax at about 116% size and includes the timeline signature in the layout cache key.
- With no key, no synchronized lyrics, loading, or failure, show no ordinary-token climax rings. Preserve cached keyword rings, text reveal, adaptive soft halo, and final-token breathing. Do not add heuristic high-frequency rings as fallback.

## Shared AI Lyric Palette

- Show “AI 文字配色” under personalization “文字” for default, `流光`, and `浮名`.
- Send only title, album, artist, plain lyric lines, and optional client-derived light/dark background/accent hex values. Never send song/server IDs, credentials, service addresses, media URLs, cover URLs, or cover images.
- Treat the optional visual context as a harmony constraint rather than a replacement for lyric semantics. Include its stable color signature in the palette metadata hash, bump the prompt protocol when the input contract changes, and validate returned colors against both canonical and derived top/bottom backgrounds on device.
- Request theme-aware base `primary`/`stamp` colors and 10–20 lyric keywords (maximum 20). Reject missing, duplicate, or malformed keywords and correct text/background contrast.
- Ordinary current graphemes/tokens use AI `primary`, then return to renderer defaults about 280 ms after the next unit begins. Keywords gain semantic color only when sung and retain it afterward; unsung keywords stay at renderer defaults. Without word timing, default and `流光` may show current-line keyword colors statically.
- Default frontier glow and blurred stamp follow the current resolved color. `流光` text/halo follow it and match keyword ranges against original lyric text so omitted layout whitespace is preserved. Keyword rings use keyword color regardless of climax; non-keyword rings use `stamp` only during climax. `浮名` current grapheme and crisp keyword stamps use resolved semantic colors.
- When disabled, uncached, or failed, preserve all default colors and add no ticker.
- Treat the palette as shared domain capability, not a `浮名` feature. `LyricsScreen` watches `lyricsAiPaletteProvider`, resolves light/dark base and keyword colors, and injects UI colors into all renderers. Renderers may use UI-only `lyric_semantic_colors.dart` matching but must not import the palette model/provider/repository/protocol/DeepSeek service.
- Split responsibilities: `lyrics_ai_palette.dart` defines cache model and lyric-content metadata hash; `lyrics_ai_palette_protocol.dart` owns prompt/request validation/contrast; `deepseek_lyrics_ai_palette_service.dart` owns transport; `lyrics_ai_palette_repository.dart` owns derived-color cache; `lyrics_ai_palette_provider.dart` owns configuration, cache/generation orchestration, and activation.
- Invalidate old cache when prompt protocol or lyrics content changes. Migrate legacy `floating_name_palette_*` entries to `lyrics_ai_palette_*` after read.
- To refresh current palette, back up the existing value, call `LyricsAiPaletteRepository.delete()` for current/legacy cache, invalidate, then await the normal `lyricsAiPaletteProvider(LyricsAiPaletteRequest(song, lyrics))`. Do not introduce a `forceRefresh` family identity. Restore backup and invalidate on failure; refresh `recognizedLyricsAiPalettesProvider` on success.
- Because `lyricsAiPaletteProvider` is `autoDispose`, call `ref.keepAlive()` until cache read/DeepSeek request finishes and close the link in `finally`. Regression tests must use a delayed fake palette service without depending on a UI listener.
- 小Jo “配色” scans only cached palettes for the current server and current library, newest first, and shows light/dark bases, keywords, and model. Opening management must not call DeepSeek. Single/all clear must not delete classifications, climax timelines, or lyrics cache.
