# Cover Selection Mode Design

## Goal

Add an in-place cover selection mode to the now playing screen. The interaction should feel like the current album cover temporarily becomes a focused selector, not like a separate queue picker or modal.

## Interaction

- Long-press the current album cover to enter selection mode.
- Entering selection mode triggers `HapticFeedback.heavyImpact()`.
- Selection mode is unavailable when the active playlist has fewer than two songs.
- The currently playing cover shrinks in place to about 70% of its normal size and remains the largest visible cover.
- The previous and next song covers fade in on the left and right at about 50% of the normal cover size, with lower opacity and slight outer clipping.
- Horizontal drag changes only the candidate song. It does not start playback.
- A candidate change is triggered by either horizontal velocity above 300 px/s or drag distance above 30% of the center cover width.
- Candidate changes trigger `HapticFeedback.selectionClick()`.
- The song title and artist below the cover follow the current candidate while selecting.
- The waveform progress stays tied to the actually playing song and does not jump while browsing candidates.
- Tapping the center candidate confirms the selection, calls `PlayerNotifier.playAtIndex(candidateIndex)`, and exits selection mode.
- Tapping outside the center cover cancels selection mode without changing playback.

## Visual And Input Behavior

- Selection mode reuses the existing now playing page layout instead of opening a new sheet.
- Playback controls and non-selection actions fade to 30% opacity and ignore input while selecting.
- Lyrics horizontal swipe is disabled while selecting.
- The transition into and out of selection mode should be smooth: center cover scales, side covers fade, and drag cancellation uses the existing spring-like curve.
- The side covers should appear as neighboring candidates, not as equally weighted cards.

## Implementation Notes

- Keep the implementation scoped to `lib/screens/now_playing_screen.dart`.
- Rework the existing selection-mode state and helper methods rather than adding a separate component.
- Use `playerState.playlist` and `playerState.currentIndex` as the source of candidate order.
- Use `PlayerNotifier.playAtIndex()` as the only playback entry point for confirmation.
- Do not add automatic next-track recovery, seek protection, or other playback-chain logic.

## Verification

- Run static analysis for the touched Dart code.
- Prefer building the arm64 release APK after implementation for device review:
  `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`
