# Lyrics Data And Screen

## Cache, Sources, And Prefetch

- On track change, prefetch current and next lyrics in the background and write them to local JSON cache.
- Do not promise full queue and progress restoration after the app is completely closed.
- Scope lyrics cache keys by `baseUrl + username + song.id`; cache empty lyrics only short-term and remove the in-memory Future cache on failure.
- Bundle `raw-lyrics-index.jsonl` as a Flutter asset. Load it once in `LyricsService` and conservatively match title plus artist, preferring a matching album.
- AMLL source priority is `qq-lyrics`, `ncm-lyrics`, `spotify-lyrics`, then `am-lyrics`; download from `https://raw.githubusercontent.com/amll-dev/amll-ttml-db/refs/heads/main/<source>/<id>.ttml`.
- Parse TTML `<p>` and timed foreground `<span>` elements into `LyricLine.words`, cache parsed timing with lyric JSON, and fall back to Navidrome structured/legacy embedded lyrics when index matching, download, or parsing fails.
- Fetch embedded lyrics through enhanced OpenSubsonic `getLyricsBySongId.view?id=<songId>&enhanced=true`, with legacy `getLyrics.view` as compatibility fallback.
- Automatic priority is embedded word-by-word, AMLL TTML, embedded synchronized line-by-line, then embedded plain text. Per-song `embedded` mode skips AMLL but still accepts embedded word-by-word and line-by-line lyrics.
- Enhanced embedded timing may be OpenSubsonic `cueLine`/`cue` data or LDDC enhanced LRC using `[line time]` plus `<word time>` markers. Convert both into complete `LyricLine` rows with `LyricWord` timing; never expose one character as a separate lyric row.
- For `cueLine`, keep the first vocal agent for each line index, use combined `line` as fallback text, and interpret `byteStart`/`byteEnd` as inclusive UTF-8 byte ranges so multibyte lyrics and gaps reconstruct exactly.
- Use only structured entries whose `kind` is absent/empty or `main`. If several line-level candidates remain, prefer synchronized content and then more complete text. Reject suspicious fragmented sets dominated by single-character rows.
- Embedded LRC parsing supports hour-bearing timestamps, comma or period fractions, multiple word markers, and `[offset:+/-milliseconds]`; clamp negative adjusted times to zero.
- Persist resolved content type in `LyricsData.source`: none, embedded word-by-word, AMLL TTML, embedded synchronized, or embedded plain text. Show this separately from the user's source-mode setting.
- Use the `lyrics_v2_` cache prefix because source metadata and enhanced embedded timing are part of the schema.
- Personalization may re-fetch or clear the current song cache. Clearing keeps visible lyrics until the next request; re-fetch bypasses fresh cache.

## Lyrics Screen And Default Renderer

- Load `LyricsScreen` immediately after initialization; do not wait for the horizontal swipe animation.
- Show no back button and no `歌词` title. The fixed top area contains only song name and artist.
- Treat the header as an overlay. Center the active lyric against the full phone-screen viewport and keep symmetric vertical breathing room.
- Disable the outer now-playing downward-close gesture while lyrics are visible or horizontally transitioning. Exit through the existing horizontal swipe/switching flow.
- Keep `lib/widgets/lyrics/default_lyrics_view.dart` as the stable default renderer. Its Folia-inspired focus transition returns the active line to full scale while passed and upcoming lines recede slightly to opposite horizontal sides.
- Use `lyricGlyphProgress()` to distribute each `LyricWord` range across Unicode grapheme clusters and render a glyph-level color sweep with a short glow only at the reveal frontier.
- Reuse `lib/widgets/lyrics/lyric_print_effect.dart` timing helpers for the default renderer and `浮名`: move each timed grapheme from baseline up by at most 10% of font size before settling. The default renderer keeps its blurred stamp; `浮名` uses a crisp stamp. Do not animate whitespace, word-by-word-off content, covered/disabled position updates, or reduced-motion states.
- Only the active timed line may watch high-frequency player position. Do not rebuild inactive lines, the whole list, backgrounds, or stage shells on every position update.
- Keep `lyrics_screen.dart` as orchestration. Put dynamic palette resolution, the default renderer, personalization sheet, and controls under `lib/widgets/lyrics/`; put independent stages under `lib/widgets/lyrics_stage/`.
