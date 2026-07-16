---
name: joyal-home-discovery
description: "Home and discovery memory for Joyal Music. Use when changing home recommendations, random albums, discovery Cover Flow, favorites on the discovery page, For You discovery cards, recommendation seed logic, or build-time derived list caching."
---

# Joyal Home Discovery

## Home Page

- Daily recommendations are selected from `LibraryState.songs`.
- Selection is stable by current date.
- Pick 24 songs for the day and show 3 songs in the inline section.
- "查看更多" reuses `PlayQueueSheet`.
- Cards reuse `QueueSongCard`.
- Tapping a daily recommendation must build a real queue from those 24 songs.
- Home "最近播放" is selected from `ListeningStatsState.recentSongIds` and mapped against `LibraryState.songs`.
- Recently played shows at most 24 songs; skip IDs no longer present in the current library.
- "最近播放" uses `PlayQueueSheet` for "查看更多".
- Tapping a recently played card or sheet item must build a real queue from those recent songs.
- Random albums are selected from `LibraryState.albums`.
- Selection is stable by current date.
- Pick 8 albums for the day.
- "查看更多" switches to the library page and selects the album tab.
- Daily recommendation song cards and random album cards reuse the shared
  `DirectionalAnchorReveal`: reveal after 15% enters, use the main vertical
  scroll direction for the top/bottom anchor, and reset only after fully exiting.
- Daily recommendation and random album section titles use the same viewport
  lifecycle but fade only; do not scale the title row or affect the home search
  collapse animation.
- `app.dart` requests a home reveal remeasure after the main-tab slide settles,
  because the root shell keeps all main pages pre-mounted.
- The home bottom copy is fixed as `----到底了----`.

## Recently Played Card Flow

- Home "最近播放" uses a peekaboo card flow, not a normal equal-width horizontal list.
- The focused song is a full rounded-square cover card aligned to the left edge of the section.
- The right side shows the next two songs as narrow vertical pill capsules with clipped cover content.
- Left dragging should make the adjacent right capsule expand directly into the full rounded-square focused card.
- Avoid any intermediate circular/oval large-card state while expanding; once a capsule begins becoming focused, switch to the full-card corner radius and keep only width/position animating.
- When the focused card shrinks back into a right-side capsule, lerp the radius toward the capsule radius during the shrink instead of holding the full-card radius until the final frame; distinguish this from the expansion path by page-motion direction.
- Keep small spacing between cards and preserve rounded clipping.
- Show song title and artist/album only on the focused/full card, with a subtle bottom gradient for readability.
- Tapping the focused card starts playback from the recent-song queue; tapping a capsule should focus/expand that song.
- The card flow is circular: swiping past either end wraps to the other end. When listening stats promote the playing song to the front, retain focus by song ID rather than by its previous numeric index.
- On a recent-song card or sheet tap, rotate the real player queue so the selected song is index 0: `[A, B, C, D]` tapping `B` becomes `[B, C, D, A]`. Songs that were to the selected song's left belong at the queue tail, never immediately to its right.
- When the active player queue contains exactly the same recent-song collection, use that queue order for the carousel and “查看更多” sheet so their visual order matches playback. Keep listening-stat storage itself in its normal recency order.
- The renderer and its drag/snap state live in `lib/widgets/home/recent_card_flow.dart`; `home_screen.dart` owns list derivation, queue rotation, and navigation callbacks.

## Derived Lists

- Lists derived during `build`, such as recent played songs, daily recommendations, random albums, discovery carousel, classification scan results, and random roaming, must be cached by date and source-list identity where applicable.
- Avoid repeated shuffle or full-library scans during page transition animation.

## Discovery Cover Flow

- Discovery top Cover Flow is based on a stable random selection from `LibraryState.songs`.
- Center cover is about 65% of screen width with 24px radius.
- Show 2-3 covers on each side, progressively smaller, lower opacity, and slightly blurred.
- Keep the depth restrained and mostly flat. Do not add obvious perspective tilt.
- Cover area supports horizontal dragging and virtual circular paging.
- Fling behavior:
  - Speed `<180`: snap to nearest page.
  - Speed `180-1000`: jump 1 cover.
  - Speed `1001-2000`: jump 2 covers.
  - Speed `>2000`: jump 3 covers.
- Use light selection haptic feedback on Cover Flow page selection.

## Favorites Section

- Keep the discovery page "收藏歌曲" section.
- Reuse `QueueSongCard` and `PlayQueueSheet`.
- Tapping a favorite song must build a real queue from the current favorite collection.
- Favorite state is shared and updates optimistically elsewhere; this section should sync without manual refresh.

## For You Discovery

- Prefer local intelligent-classification tags to select songs.
- When classification is insufficient, degrade only to real local collections such as favorites or random songs.
- Do not show AI recommendations without supporting local data.
- Discovery refresh should first refresh local "为你发现" recommendation seeds, then try `fetchStarred()` for favorites.
- If disconnected, refresh only local recommendations and state that favorite refresh requires a server connection.
- Do not place a classification or `小Jo同学` status card below this section;
  discovery keeps only the title-bar entry.

## Discovery Card Visuals

- "为你发现" cards are horizontal contextual playlist cards.
- Use a delicate gradient background, subtle stroke, soft shadow, and colored ambient light at the lower right.
- Place two real album covers at the upper right, offset and stacked.
- Foreground cover rotates left; background cover rotates right, scales down, and lowers opacity.
- Put a small icon at the upper left.
- Bottom text shows only title and subtitle. Do not show song count.
- Pressed state slightly enlarges the card, strengthens shadow/stroke/ambient light, and gently spreads the covers. Release restores the idle state.

## Files To Check

- Home orchestration: `home_screen.dart`.
- Shared viewport reveal: `lib/widgets/directional_anchor_reveal.dart`.
- Recently played renderer: `lib/widgets/home/recent_card_flow.dart`.
- Discovery page: `hotlist_screen.dart`.
- Cover Flow: `lib/widgets/discovery/discover_song_carousel.dart`.
- For You: `for_you_discovery_section.dart`, `discovery_playlist_card.dart`, `discovery_card_models.dart`.
- Section headers: `discovery_section_header.dart`.
