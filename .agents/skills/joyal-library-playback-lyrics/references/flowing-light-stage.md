# Flowing Light Stage (`流光`)

- Implement in `flowing_light_lyrics_stage.dart`. Show only the active line. Split Chinese into graphemes and Latin runs into whole words.
- Derive a deterministic scattered layout from token text so rebuilds never move glyphs. Typical 6–12-token lines use 3–4 vertical rows, about 2–3 tokens per row, irregular gaps/offsets/scales, and normally distributed rotation clamped to ±20°. Keep responsive scale-down for long text and small viewports; do not restore a regular `Wrap`.
- Use the same scattered layout for untimed lyrics and when word-by-word is disabled, but reveal it statically.
- With timing, reserve future token positions invisibly. Enter at about 116% scale and settle to 100% over 520 ms. Keep the outward ring short; hold the soft halo at full brightness until the next Chinese grapheme or Latin word starts, including timing gaps, then overlap a smooth 520 ms fade-out. Do not render a dim pending-token mask.
- For the final timed token, let the entrance ring finish once and keep the soft halo breathing until the next line activates. Derive this from already-scoped active position updates; use a static highlight when covered or motion is disabled.
- Keep the settled composition vertically fixed without whole-composition floating or translation.
- Use one 7.2-second controller to rock revealed tokens 1.8°–2.4° around stable base angles. Alternate initial direction between neighbors, reverse every half-cycle, ramp in with reveal, leave future tokens still, and clamp combined rotation to ±20°.
- Keep that controller and painting inside the active composition `RepaintBoundary`. Start only when `positionUpdatesEnabled`; stop/reset when hidden, covered, disabled, or `MediaQuery.disableAnimationsOf(context)` is true. Do not add another persistent controller.

Read `lyrics-stage-foundations.md` for shared lifecycle/composition and `lyrics-ai-analysis.md` when changing climax rings or semantic colors.
