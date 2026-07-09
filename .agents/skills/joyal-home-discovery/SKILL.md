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
- Random albums are selected from `LibraryState.albums`.
- Selection is stable by current date.
- Pick 8 albums for the day.
- "查看更多" switches to the library page and selects the album tab.
- The home bottom copy is fixed as `----到底了----`.

## Recently Added Card Flow

- Home "最近添加" uses a peekaboo card flow, not a normal equal-width horizontal list.
- The focused album is a full rounded-square cover card aligned to the left edge of the section.
- The right side shows the next two albums as narrow vertical pill capsules with clipped cover content.
- Left dragging should make the adjacent right capsule expand directly into the full rounded-square focused card.
- Avoid any intermediate circular/oval large-card state while expanding; once a capsule begins becoming focused, switch to the full-card corner radius and keep only width/position animating.
- When the focused card shrinks back into a right-side capsule, lerp the radius toward the capsule radius during the shrink instead of holding the full-card radius until the final frame; distinguish this from the expansion path by page-motion direction.
- Keep small spacing between cards and preserve rounded clipping.
- Show album text only on the focused/full card, with a subtle bottom gradient for readability.
- Tapping the focused card opens album detail; tapping a capsule should focus/expand that album.

## Derived Lists

- Lists derived during `build`, such as daily recommendations, random albums, discovery carousel, classification scan results, and random roaming, must be cached by date and source-list identity.
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

## Discovery Card Visuals

- "为你发现" cards are horizontal contextual playlist cards.
- Use a delicate gradient background, subtle stroke, soft shadow, and colored ambient light at the lower right.
- Place two real album covers at the upper right, offset and stacked.
- Foreground cover rotates left; background cover rotates right, scales down, and lowers opacity.
- Put a small icon at the upper left.
- Bottom text shows only title and subtitle. Do not show song count.
- Pressed state slightly enlarges the card, strengthens shadow/stroke/ambient light, and gently spreads the covers. Release restores the idle state.

## Files To Check

- Home: `home_screen.dart`.
- Discovery page: `hotlist_screen.dart`.
- Cover Flow: `lib/widgets/discovery/discover_song_carousel.dart`.
- For You: `for_you_discovery_section.dart`, `discovery_playlist_card.dart`, `discovery_card_models.dart`.
- Status and headers: `classification_status_card.dart`, `discovery_section_header.dart`.
