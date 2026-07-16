# Floating Name Stage (`浮名`)

## Layout And Camera

- Implement independently in `floating_name_lyrics_stage.dart`. Pretype the song into a deterministic cached world-space three-column snake article with sparse hero lines, expanding left/right before turning to the next row.
- Move a camera between blocks and lightly follow the active glyph frontier. Strike one complete Chinese grapheme or Latin letter at a time like a typewriter; keep fractional progress only for camera movement and short solid print-stamp motion. Passed lyrics remain fading ink traces, future lines stay faint, and word-by-word off reveals the whole active line at its start.
- For a single visual row, continuously interpolate horizontal focus between cached grapheme-box centers. Never snap after a glyph completes.
- When a lyric wraps to multiple visual rows, lock horizontal focus to the block center and keep subtle vertical following. Spread wrap movement across surrounding graphemes for Chinese and surrounding Latin-word boundaries for English; keep English ink landing one letter at a time. Preserve original grapheme indices for wrapping and whitespace.
- Use an edge-to-edge screen-space paper tint. Never restore a finite world-space rounded mask whose edges can enter the moving camera. Attach decorative marks to the current lyric block, not a fake canvas boundary.
- For a genuinely long gap after a completed line and before the next non-empty timed line, reuse the existing frame controller for a few pixels of low-frequency translation and sub-degree rotation. Keep short gaps still; ease in after settling and out before the next line. Disable while paused, hidden, covered, or reduced-motion. Do not add a ticker.
- Cache text layout by lyrics identity, viewport, font family, independent `floatingNameFontSize`, and climax signature. Cull off-camera blocks and reuse each block's `TextPainter`; never remeasure visible blocks on each playback tick.

## Print Stamp And Wait Cursor

- Share timing helpers from `lyrics/lyric_print_effect.dart`. Both default and `浮名` use a baseline-to-at-most-10%-up-to-baseline bounce. Default may keep its blurred stamp; `浮名` uses a crisp hard-edged stamp with no `MaskFilter.blur`.
- In `浮名`, keyword stamps use the semantic keyword color; other current glyphs and stamps use the client-derived dark-mode dynamic-light effect color. Peak alpha is 0.8 times the resolved color alpha and fades with the stamp pulse.
- Draw no stamp for whitespace or Unicode punctuation.
- Show the small input-wait stamp only when the full gap from print end to the next non-empty line is at least 3.6 seconds. Start cadence immediately at print completion, not after 3.6 seconds, and stop before the next line. The final lyric bypasses the threshold and continues until playback stops.
- If the last stampable grapheme is a semantic keyword, inherit that keyword color through trailing punctuation; otherwise use the client-derived dynamic-light effect color.
- Disable the wait stamp while paused, hidden/covered, word-by-word-off, or reduced-motion. Reuse the existing frame controller.
- Reveal typed text with per-grapheme `TextSpan` colors, not a glyph-selection rectangle clipping one fully bright `TextPainter`; tight metrics can otherwise reveal the next visual row. During current-to-passed transition, ease non-keyword glyphs to passed gray while keyword colors remain stable.

Read `lyrics-stage-foundations.md` for shared lifecycle/composition and `lyrics-ai-analysis.md` when changing climax sizing or semantic colors.
