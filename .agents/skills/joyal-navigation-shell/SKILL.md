---
name: joyal-navigation-shell
description: "Navigation and shell memory for Joyal Music. Use when changing lib/app.dart, main tabs, GlassTopBar placement, HomeSidebar gestures or custom-image entry, the infinite library canvas route and Hero transition, MiniPlayer collapse/expand behavior, AppBottomNav, PlayQueueSheet entry points, or settings navigation."
---

# Joyal Navigation Shell

## Main Navigation

- The main navigation has only three pages: 首页, 曲库, 发现.
- Search enters from the home search box or top-bar icon.
- Old tests may still assert the copy `主页`.
- Main pages use a full-screen `Stack` background.
- `GlassTopBar` is fixed over the status bar; content must avoid the top bar.
- The library `TabBar` is an extra area below the top bar and must not shift the title or buttons.

## Root Shell

- `lib/app.dart` pre-mounts the home, library, and discovery pages in a sliding stack.
- Off-screen pages keep state.
- Use `TickerMode`, `IgnorePointer`, and `ExcludeSemantics` to prevent background animation, interaction, and semantics.
- Bottom navigation supports horizontal drag paging, cross-item selection vibration, and pages sliding in from the edge.
- Keep shell state and route coordination in `lib/app.dart`; edge-Hero, startup mask, drawer presentation, and gesture recognizer helpers live in `lib/widgets/navigation/main_shell_helpers.dart`.

## MiniPlayer And Dock

- `MiniPlayer` and `AppBottomNav` are floating capsules on a transparent dock.
- List bottom padding must dynamically avoid the dock; when a player is visible, add extra avoidance for the MiniPlayer.
- The MiniPlayer right-swipe collapse state belongs to `_MainShellState`.
- Collapse into the lower-right rotating album-cover button.
- Collapse/expand should keep one fixed-height track and move/shrink into a circular cover. Do not crossfade two separate UIs.
- MiniPlayer chrome/morphing stays in `mini_player.dart`; lyric lookup, pair transitions, text measurement, and rolling layout stay in `lib/widgets/mini_player/mini_player_lyrics.dart`.

## Home Sidebar

- Home right-swipe opens `HomeSidebar`.
- Sidebar width is about 70% of the screen.
- Home content, MiniPlayer, and dock move right, scale down, and dim with sidebar progress.
- The recently-added horizontal list is an exclusion zone for the sidebar gesture.
- Keep the sidebar animation smooth: use a stable child/RepaintBoundary for the home preview.
- Do not insert/remove temporary parent nodes when dragging starts.
- Avoid full-screen dynamic `BackdropFilter` during open/close.
- Sidebar shows only real state: when connected, show the connection icon only in the title area; show prompt cards only when disconnected or restoring.
- Use the custom sidebar image as the entry to `LibraryCanvasScreen`; keep choosing, clearing, and 16:9 cropping in the personalization page.
- Share `libraryCanvasHeroTag` between the sidebar image and the canvas header thumbnail. Keep the sidebar open while the route is active so the reverse Hero returns to a visible source.
- Do not show the main-shell MiniPlayer or Dock inside `LibraryCanvasScreen`.

## Infinite Canvas Gestures And Hero

- On the home tab with the sidebar closed, use a two-finger spread to open `LibraryCanvasScreen`; use a two-finger pinch inside the canvas to pop back home.
- Track pinch distance through `TwoFingerPinchTracker` and raw pointer events so one-finger sidebar and canvas dragging remain available.
- Make the home two-finger recognizer win the gesture arena as soon as the second finger lands. Freeze the home vertical scroll, recent-card horizontal drag, and sidebar drag for the rest of that two-finger gesture.
- Keep two distinct Hero routes for the custom sidebar image. Sidebar taps use `libraryCanvasHeroTag`; closed-home pinch entry uses `libraryCanvasEdgeHeroTag` with an off-screen source at the left screen edge. Pass the selected tag into the canvas header so reverse navigation returns along the same path.
- Never mount both image sources with the same Hero tag on the home route; duplicate tags break route collection.

## Settings Entry

- Settings entry lives at the lower-left settings button in the home right-swipe sidebar.
- It opens `SettingsHubScreen`.

## Files To Check

- Shell/navigation: `lib/app.dart`, `lib/widgets/navigation/main_shell_helpers.dart`, `bottom_nav.dart`, `glass_top_bar.dart`.
- Sidebar: `home_sidebar.dart`.
- Infinite library canvas: `library_canvas_screen.dart`.
- Shared pinch tracking: `lib/utils/two_finger_pinch_tracker.dart`.
- Floating playback UI: `mini_player.dart`, `lib/widgets/mini_player/mini_player_lyrics.dart`, `mini_player_chrome.dart`.
- Queues and sheets: `play_queue_sheet.dart`.
- Settings route: `settings_hub_screen.dart`, `personalization_screen.dart`.
