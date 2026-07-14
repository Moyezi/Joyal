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
- Drive the center-card play action icon and tooltip from whether that card is the current playing song: show pause only while it is actively playing, otherwise show play. Select this state inside the action subtree so playback changes do not rebuild the whole canvas.
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
- The default scrolling renderer lives in `lib/widgets/lyrics/default_lyrics_view.dart`. Its Folia-inspired focus transition returns the active line to full scale while passed and upcoming lines recede slightly to opposite horizontal sides. Keep it as the default renderer rather than treating it as a full-screen stage mode.
- Word-by-word presentation in the default renderer uses `lyricGlyphProgress()` to distribute each `LyricWord` time range across Unicode grapheme clusters and renders a glyph-level color sweep with a short glow only at the reveal frontier.
- Reuse `lib/widgets/lyrics/lyric_print_effect.dart` timing helpers for the default renderer and `浮名`: as each timed grapheme highlights, move the glyph from its baseline up by at most 10% of its font size before settling. The default renderer keeps its blurred stamp; `浮名` uses a crisp stamp in the active font color with peak alpha at 0.8 times that color, then fades with the stamp pulse. Keep the default renderer's existing color sweep and frontier glow. Do not animate whitespace, word-by-word-off content, covered/disabled position updates, or reduced-motion states.
- Only the active timed line may watch high-frequency player position. Inactive lines, the whole list, the background, and future stage shells must not rebuild for every position update.
- Keep `lyrics_screen.dart` as page orchestration. Dynamic palette resolution, the default renderer, personalization sheet, and sheet controls belong under `lib/widgets/lyrics/`; independent visual stages belong under `lib/widgets/lyrics_stage/`.

## Independent Lyrics Stages

- DeepSeek 歌曲高潮时间轴由 `流光` 和 `浮名` 舞台按需复用。进入有同步歌词的任一已实现独立舞台时可以触发分析；只发送歌曲名、歌手、专辑、歌曲时长和带时间歌词，复用“小Jo同学”的 secure-storage API Key、endpoint 和模型设置。`流光` 用时间轴控制外扩圆环，`浮名` 用时间轴放大与高潮区间重叠的歌词行。
- 高潮结果通过 `SongHighlightRepository` 按服务器 scope 与歌曲缓存；`lyricsAnalysisHash` 包含歌曲元数据、时长、歌词文本及行时间，模型或 hash 改变时重新分析。缓存可以在 API Key 被移除或离线后继续读取。
- DeepSeek 时间段必须经 `normalizeHighlightSegments()` 排序、歌曲时长裁剪、重叠合并并最多保留 3 段。未配置 Key、无同步歌词、分析中或分析失败时不显示圆环；文字揭示、自适应柔光和末词呼吸保持可用。不要用启发式高频圆环作为失败回退。

- The independent lyrics stage selector is persisted through `lyrics_personalization_provider.dart`. The stable default scrolling renderer remains available.
- `流光` is implemented as its own renderer in `lib/widgets/lyrics_stage/flowing_light_lyrics_stage.dart`. It displays only the active line, splitting Chinese into graphemes and Latin runs into whole words. Use a deterministic scattered layout: common lines form 3–4 vertical rows with about 2–3 tokens per row, irregular spacing and offsets, and normally distributed token rotation clamped to ±20°. Untimed lyrics and disabled word-by-word display keep the same scattered layout but reveal statically.
- With word timing, future tokens reserve invisible positions so revealed text never shifts. Each token appears at about 116% scale and settles to 100% over 520 ms. Keep the outward entrance ring short, but make the soft highlight interval adaptive: hold full brightness from this token's start until the next Chinese grapheme or Latin word starts, including timing gaps, then overlap the next token with a smooth 520 ms fade-out instead of clearing the previous halo immediately. For the final token, use the line end and keep its soft highlight breathing until the next lyric line activates; never repeat its outward ring or render a dim pending-text mask. Drive this from the active playback-position updates instead of adding another persistent controller; reduced-motion/covered states keep only a static highlight.
- Center independent stage compositions against the full phone screen as well. The fixed header remains an overlay and must not shift the stage center downward.
- Keep the settled `流光` composition vertically fixed; do not add whole-composition floating or translation.
- Use one 7.2-second controller to rock revealed `流光` tokens gently around their deterministic base rotation: adjacent tokens begin in opposite directions, reverse direction every half-cycle, and vary only about 1.8°–2.4°. Ramp the sway in with token reveal, keep future tokens still, clamp the combined rotation to ±20°, and reset to the base angle whenever ambient motion is disabled. Keep the controller and painting inside the active composition `RepaintBoundary`; settings coverage, hidden lyrics pages, disabled position updates, and reduced-motion settings must stop/reset it, and do not add another persistent controller.
- `浮名` is implemented independently in `lib/widgets/lyrics_stage/floating_name_lyrics_stage.dart`. It pretypes the whole song into a deterministic three-column snake article with sparse hero lines, expanding left and right before turning into the next row, then moves a camera between blocks and lightly follows the active glyph frontier. The active line uses word timing but strikes one complete Chinese grapheme or Latin letter at a time like a typewriter; keep continuous fractional progress only for the camera and short solid print-stamp motion. Passed lyrics remain as fading ink traces, future lines stay very faint, and word-by-word off reveals the whole active line at its start.
- `浮名` 的单视觉行歌词按 grapheme 进度和预排版 glyph box 中心连续插值横向镜头，不能在每个字唱完时跳到下一个字；一句歌词自动换成多视觉行时锁定镜头横向中心，只保留轻微纵向跟随，避免换行时左右扫动。把换行纵向位移铺成连续缓动：中文横跨换行前后多个 grapheme，英文按 Latin 单词边界横跨前后多个单词，不得退回单字或单字母区间内突然下跳；英文仍逐字母落印。保留换行/空白对应的原始 grapheme 索引。歌词舞台完全进入前页头保持可见；完全进入后，默认滚动、流光和浮名左上歌曲名与歌手都继续显示 5 秒，再用约 720 ms 的柔和淡出隐藏。打开设置面板不得重启计时。DeepSeek 高潮时间轴覆盖到的歌词行使用约 116% 的预排版字号，且时间轴签名必须进入布局缓存 key。
- `浮名` 的纸张底色必须是 edge-to-edge 的屏幕空间层，不能再使用会被移动镜头拍到上下左右边界的有限世界坐标圆角矩形；装饰标记只能依附当前歌词块，不能伪装成画布边界。
- `浮名` 在当前句完成后到下一条非空同步歌词之间只为长空档加入轻柔手持镜头漂移：短空档保持静止，长空档延迟渐入并在下一句前渐出，以数像素平移和极小旋转营造呼吸感。复用现有 frame controller，不新增常驻 ticker；暂停播放、舞台隐藏、设置遮挡或 reduced motion 时停止该运动。
- `浮名` 的当前字打印印章保持清晰硬边，不使用 `MaskFilter.blur`；关键词印章使用关键词语义色，其他印章使用配置的 `stamp` 色，峰值 alpha 为解析后印章颜色 alpha 的 0.8 倍，并随印章脉冲淡出。空白 grapheme 和所有 Unicode 标点符号不绘制印章。默认滚动歌词仍可保留自身的模糊打印印章。已唱/未唱字形必须通过逐 grapheme 的 TextSpan 颜色区分，不能再用 glyph 选区矩形裁剪整段亮色 TextPainter；紧行距或字体 ink bounds 溢出时，后者会误揭示下一视觉行的字顶。当前句切成已唱句时，复用镜头转场把非关键词字从当前色平滑过渡到已唱灰色，关键词色保持不变。
- “AI 文字配色”开关显示在默认滚动、`流光`与`浮名`的歌词个性化“文字”栏。开启时按当前歌曲缓存或请求 DeepSeek；请求含 title、album、artist 与纯歌词行，不含歌曲/服务器 ID、凭据、服务地址或媒体/封面 URL。AI 结合歌词语义、情绪走向和歌曲氛围返回基础 `primary`/`stamp`，并从歌词原文提取最多 20 个（提示词要求 10～20 个）关键词，为浅色/深色主题分别派生专属文字色；协议会丢弃不存在于歌词、重复或格式无效的关键词，并修正所有文字色的背景对比度。
- 三个效果让普通当前字或单词使用 AI `primary`，并在下一字或单词开始后约 280 ms 内退回各渲染器原本的默认歌词色；关键词只在实际唱到后使用其语义色，之后持续保留，不退回默认色。默认滚动与`浮名`的已唱非当前句也保留关键词语义色，未唱关键词仍使用渲染器默认色。无逐字时间时，默认滚动与`流光`可静态显示当前句关键词色。默认滚动的当前字前沿光晕和模糊打印印章跟随当前解析色；`流光`的当前文字与高光光晕跟随当前解析色，并按原始歌词字符范围匹配关键词以保留 token 间被布局省略的空白，高潮时间轴覆盖的关键词外扩圆环也使用其语义色，非关键词圆环继续使用 `stamp`；`浮名`当前 grapheme 使用当前解析色，关键词处的清晰打印印章使用其语义色，非关键词印章继续使用 `stamp`。关闭、无有效缓存或请求失败时完整保留默认配色；不新增 ticker。
- AI 歌词配色是三个渲染器共享的领域能力，不属于 `浮名`。`LyricsScreen` 负责订阅 `lyricsAiPaletteProvider`、按当前明暗主题解析基础色和关键词色，再注入默认滚动、`流光`和`浮名`；渲染器只可依赖 UI 层的 `lyric_semantic_colors.dart` 做文本单元匹配，不得直接依赖配色 model、provider、缓存或 DeepSeek service。
- 配色模块按职责拆分：`lyrics_ai_palette.dart` 只定义缓存模型与包含歌词内容的 metadata hash，`lyrics_ai_palette_protocol.dart` 负责请求体、提示词、关键词响应校验和对比度修正，`deepseek_lyrics_ai_palette_service.dart` 只负责网络传输，`lyrics_ai_palette_repository.dart` 只负责派生色缓存，`lyrics_ai_palette_provider.dart` 负责配置/缓存/生成编排与开关激活结果。提示词协议版本变化或歌词内容变化必须使旧缓存失效；旧 `floating_name_palette_*` 缓存读取后迁移为 `lyrics_ai_palette_*`。
- Cache `浮名` text layout by lyrics identity, viewport, font family, and its independent `floatingNameFontSize`. Cull blocks outside the camera viewport and reuse each block's laid-out `TextPainter`; do not measure visible blocks again on every playback tick. Camera animation must stop when covered, hidden, or reduced motion is enabled.
- `流光` and `浮名` share `lib/widgets/lyrics_stage/lyrics_stage_shell.dart` for the full-screen composition, overlaid song header, and pinch gesture. Keep renderer-specific animation and painting inside each renderer.
- `群唱` remains planned. Its disabled `待完成` entry stays visible in the lyrics personalization drawer, and selecting it must not persist an unavailable renderer.
- These themes are not skins over `_LyricsList`. Give each theme its own renderer and animation grammar, while sharing a small stage shell, lyric timing runtime, theme/palette inputs, empty states, gestures, and lifecycle handling.
- Keep the current scrolling lyrics renderer available as the stable default. Persist available stage modes through `lyrics_personalization_provider.dart` in secure storage and expose them through the existing in-place personalization flow.
- Stage renderers must accept the same `LyricsData` model and degrade gracefully for synchronized line lyrics or plain lyrics when `LyricLine.words` has no timing.
- Precompute and cache expensive text layout by song identity, viewport, font, font size, and renderer settings. Prepare the active and upcoming line before a transition instead of measuring the full composition on every playback tick.
- Avoid one giant renderer with mode branches. Keep the shared stage shell/runtime and each finished renderer under `lib/widgets/lyrics_stage/`, with one file or folder per `浮名`, `流光`, and `群唱` renderer.
- Preserve Joyal's visual identity and implement the concepts cleanly in Flutter; do not copy AGPL Folia source code into this project.

## Lyrics Personalization

- Pinch with two fingers on the lyrics page opens the in-place personalization drawer.
- Preferences are stored by `lyrics_personalization_provider.dart` in secure storage.
- Preferences include color, alignment, renderer-specific font sizes, and font family. Persist default-scroll size, `flowingLightFontSize`, and `floatingNameFontSize` independently; changing one renderer's size must not alter the others.
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
- Keep lyric lookup, pair timing, rolling animation, and text measurement in `lib/widgets/mini_player/mini_player_lyrics.dart`; the outer MiniPlayer only supplies the resulting lyrics widget to its morphing chrome.

## Files To Check

- API and library: `lib/services/subsonic_api.dart`, `library_provider.dart`.
- Player: `audio_player_service.dart`, `lib/providers/player_provider.dart`, `play_queue_sheet.dart`.
- Stats: `listening_stats_provider.dart`.
- Lyrics orchestration and settings: `lyrics_screen.dart`, `widgets/lyrics/default_lyrics_view.dart`, `widgets/lyrics/lyric_print_effect.dart`, `widgets/lyrics/lyric_semantic_colors.dart`, `widgets/lyrics/lyrics_palette.dart`, `widgets/lyrics/lyrics_personalization_sheet.dart`, `widgets/lyrics/lyrics_settings_controls.dart`, `lyrics_provider.dart`, `lyrics_personalization_provider.dart`, `lyrics_ai_palette_provider.dart`, `models/lyrics_ai_palette.dart`, `services/lyrics_ai_palette_protocol.dart`, `services/deepseek_lyrics_ai_palette_service.dart`, `services/lyrics_ai_palette_repository.dart`.
- Lyrics stages and analysis: `song_highlight_provider.dart`, `models/song_highlight.dart`, `services/deepseek_highlight_service.dart`, `services/song_highlight_repository.dart`, `widgets/lyrics_stage/lyrics_stage_shell.dart`, `widgets/lyrics_stage/flowing_light_lyrics_stage.dart`, `widgets/lyrics_stage/floating_name_lyrics_stage.dart`.
- MiniPlayer: `mini_player.dart`, `mini_player_chrome.dart`.
- Infinite library canvas: `library_canvas_screen.dart`.
