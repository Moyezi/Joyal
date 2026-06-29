# Dynamic Waveform Progress Design

## Goal

Make the now-playing waveform progress feel more musical and tactile while staying aligned with Joyal Music's minimal, immersive visual direction.

The selected direction is a magnetic energy waveform:

- During normal playback, the waveform keeps its existing track-stable energy shape and subtle pulse.
- During drag seeking, the waveform follows the user's finger.
- Bars near the finger stay expressive and slightly amplified.
- Bars farther from the finger flatten smoothly.
- Entering and leaving drag mode must be animated, not a hard visual switch.
- Releasing the drag commits the seek, then the waveform returns to the normal playback state.

## Scope

This change targets the now-playing `WaveformProgress` only.

In scope:

- Add drag-state morphing to the waveform painter.
- Add animated transition progress between normal and dragging states.
- Add cover-derived accent colors to the active waveform, connected to existing dynamic album color extraction.
- Keep current seek behavior and haptic feedback.
- Keep the simulated waveform generated from `song.id`; do not decode PCM.

Out of scope:

- Changing the playback queue or seek service logic.
- Adding extra recovery, auto-next, or seek-protection behavior.
- Replacing the waveform with a generic slider.
- Reworking the full now-playing layout.

## Visual Behavior

Normal playback:

- Played bars use a cover-derived accent when available.
- Unplayed bars remain quiet grey.
- The current active bar continues to pulse subtly while playing.
- The waveform shape remains stable per track.

Dragging:

- Dragging stores a `dragFraction` that represents the finger position.
- Each bar computes distance from `dragFraction`.
- Bars inside a local influence area keep most of their original energy and can grow slightly.
- Bars outside the influence area compress toward a low flat baseline.
- The flattening amount is controlled by an animated drag intensity value.
- The time bubble remains attached to the dragged position.

Release:

- The seek is committed through the existing `onSeek` callback.
- The drag fraction clears after seek completion.
- The waveform animates back to normal playback with a soft elastic feel.

## Color Link

The existing `DynamicAlbumBackground` already extracts and caches a palette from cover art. To avoid duplicate palette work, introduce a small shared palette value object/helper so both background and waveform can consume the same cover-derived colors.

The waveform needs:

- `accent`: active played color, derived from the cover palette but darkened enough for contrast.
- `accentSoft`: optional glow or secondary played color.
- `track`: low-contrast unplayed color, still based on the app's grey system.

If cover art or palette extraction fails, the waveform falls back to the current black/grey colors.

## Implementation Shape

Add or extract a lightweight visual palette helper near the existing dynamic background code.

Update `DynamicAlbumBackground` to use the helper without changing its external API.

Update `WaveformProgress`:

- Accept optional active/accent colors.
- Add an animation controller for drag morph intensity.
- Animate drag intensity to `1` on drag start/update.
- Animate drag intensity back to `0` after drag cancellation or committed seek.
- Pass `dragFraction` and `dragIntensity` into `_WaveformPainter`.

Update `_WaveformPainter`:

- Calculate each bar's distance from the drag fraction.
- Convert distance into a local influence value.
- Blend normal height with flattened height based on drag intensity and local influence.
- Slightly amplify the finger-local bars.
- Repaint when drag fraction, drag intensity, colors, progress, pulse, or waveform data changes.

## Testing

Static verification:

- Run `dart analyze lib test` or `flutter analyze`.

Behavior verification:

- Normal playback renders the familiar waveform.
- Dragging changes the waveform shape immediately but smoothly.
- Remote bars flatten while finger-local bars remain expressive.
- Releasing seek restores playback waveform.
- Tracks without cover art keep the fallback colors.

