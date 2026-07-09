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

- Wrap the five playback controls in `FrostedGlass` using `GlassEffectTarget.bottomNav`; this shares the navigation glass blur, opacity, and liquid-glass switch.
- Keep the main play/pause Hero (`nowPlayingPlayButtonHeroTag`) as a 64px rounded rectangle (`radius: 22`) with `context.surfaceColor` and `onSurface` foreground; do not hardcode light/dark button colors.

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

## Files To Check

- Main page: `now_playing_screen.dart`.
- Transition: `now_playing_transition.dart`.
- Progress: `waveform_progress.dart`.
- Background and palette: `dynamic_album_background.dart`, `album_visual_palette.dart`.
- Player entry: `mini_player.dart`, `mini_player_chrome.dart`, `lib/providers/player_provider.dart`.
