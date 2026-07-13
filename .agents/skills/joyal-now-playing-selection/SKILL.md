---
name: joyal-now-playing-selection
description: "Now-playing and selection-mode memory for Joyal Music. Use when changing now_playing_screen.dart, now_playing_transition.dart, MiniPlayer-to-now-playing Hero transitions, playback controls, waveform progress, cover swipe transitions, or long-press cover selection mode."
---

# Joyal Now Playing Selection

## Control Colors

- Use `Theme.of(context).colorScheme.onSurface` for normal now-playing action icons so they match the main navigation.
- Favorited state keeps `context.favoriteRedColor`.
- Use rounded Material icons for top actions and transport controls.

## Playback Control Rail

- Wrap the five playback controls in `FrostedGlass` using `GlassEffectTarget.nowPlayingControls`; its blur and opacity are independently adjustable in the personalization “播放控制栏” preview. Keep `bottomNav` for the app navigation only.
- Keep the main play/pause Hero (`nowPlayingPlayButtonHeroTag`) as a 64px rounded rectangle (`radius: 22`) with `context.surfaceColor` and `onSurface` foreground. Its pressed overlay must use the same rounded rectangle, never a `CircleBorder`.

## MiniPlayer To Now Playing

- Tapping MiniPlayer opens now playing with a transparent `PageRouteBuilder`.
- The page draws its own transition.
- Background fills from the bottom.
- Album cover Hero moves from the MiniPlayer circular avatar to the now-playing cover.
- MiniPlayer circular cover rotates and preserves phase across Hero/rebuild.
- The large now-playing cover stays still when settled.
- The Hero flight layer is responsible for continuous shape and shadow. Logic lives in `now_playing_transition.dart`.

## Play Button Transition

- MiniPlayer play button and now-playing main play button share a Hero.
- Preserve the cross-fade on return and do not let the play-button color jump after landing.
- MiniPlayer lyrics area does not participate in cross-page Hero.

## Waveform Progress

- Waveform progress is equal-length discrete short bars plus ripple traveling-wave animation.
- It is not PCM amplitude.
- Color comes from the current visual song palette and is corrected for light/dark mode.
- During dragging, the colored boundary follows the finger.
- Locally cached song-climax segments are shown only with an accent color. They
  must not change bar height; opening now playing must never trigger a new
  climax-analysis request.
- Keep position updates local; do not rebuild the whole now-playing page for progress ticks.

## Cover Switching

- Previous/next cover horizontal switching should let the leaving cover fully exit the screen before cleanup.

## Selection Mode

- Long-press the now-playing cover to enter selection mode.
- Swiping left/right changes only the candidate song; it does not immediately play.
- Tapping the center cover confirms with `playAtIndex()`.
- Tapping blank space cancels.
- Candidate covers should be naturally clipped by the screen edge.
- Do not clip them with the cover slot, current cover, local `ClipRect`, or masking overlay.
- In selection mode, title, artist, dynamic background, and waveform color follow the candidate song.
- Use `nowPlayingVisualSong(...)` as the unified source for visual-song selection.
- Keep selection logic in `_NowPlayingScreenState`.
- Keep entrance/Hero chrome in `lib/widgets/now_playing/now_playing_chrome.dart` and the provider-driven playback controls/progress in `now_playing_player_content.dart`; do not move the selection state machine out merely to reduce line count.

## Files To Check

- Page state and selection: `now_playing_screen.dart`.
- Chrome and playback content: `lib/widgets/now_playing/now_playing_chrome.dart`, `lib/widgets/now_playing/now_playing_player_content.dart`.
- Transition: `now_playing_transition.dart`.
- Progress: `waveform_progress.dart`.
- Background and palette: `dynamic_album_background.dart`, `album_visual_palette.dart`.
- Player entry: `mini_player.dart`, `mini_player_chrome.dart`, `lib/providers/player_provider.dart`.
