---
name: joyal-navigation-shell
description: "Navigation and shell memory for Joyal Music. Use when changing lib/app.dart, main tabs, GlassTopBar placement or search actions, SearchScreen routing, HomeSidebar gestures or custom-image entry, the infinite library canvas route and Hero transition, MiniPlayer collapse/expand behavior, AppBottomNav, PlayQueueSheet entry points, or settings navigation."
---

# Joyal Navigation Shell

## Main Navigation

- The main navigation has only three pages: 首页, 曲库, 发现.
- Search enters from the home search box or the top-bar actions on 首页, 曲库, and 发现.
- Old tests may still assert the copy `主页`.
- Main pages use a full-screen `Stack` background.
- The shell renders the shared `PageCustomBackground` once behind all three transparent main pages; page transitions must not composite duplicate full-screen image backgrounds.
- `GlassTopBar` is fixed over the status bar; content must avoid the top bar.
- The library `TabBar` is an extra area below the top bar and must not shift the title or buttons.

## Search Entry And Route

- Top-bar search actions reveal `SearchScreen` as a circular ripple centered on the tapped button and collapse back to the same point on pop.
- Reuse `SearchRippleIconButton` for ordinary title-row actions on 曲库 and 发现. The animated 首页 top-bar icon reports its center through `GlassTopBar.onSearchTapAt` and calls `buildSearchRippleRoute` directly.
- Keep the ripple implementation in `lib/widgets/navigation/search_ripple_route.dart`; it owns the circular clip, subtle edge rings, transition timing, duplicate-route guard for its standard button, and the reduced-motion bypass.
- The large 首页 search box uses `buildSearchCurtainRoute`: capture its transformed global rectangle from the `RenderBox` corner points, then expand the capsule upward and downward into `SearchScreen`. Keep the top-bar entries on their separate circular-ripple route.
- `SearchScreen.transitionAnimation` and `sourceRect` coordinate the curtain entry. Preserve the home capsule's 24px horizontal inset, 54px height, 18px radius, glass settings, search-icon/text alignment, and trailing-arrow center; the arrow rotates into the search page's back action.
- Stage the search-page background before revealing history/results. Do not autofocus the field on entry; open the keyboard only after the user taps it so it does not compete with the transition.
- Treat reverse motion separately from entry: never simply reverse the forward `easeOut` field curve. While `AnimationStatus.reverse`, use a curve that decelerates into the home source, fade the field's icon/text/arrow before the capsule travels, and let only the glass capsule return. Otherwise duplicate chrome appears above the home bar and accelerates into it near the end.
- Keep the reduced-motion bypass. Cover forward/reverse curtain geometry in `test/search_ripple_route_test.dart` and the real home entry wiring in `test/home_search_animation_test.dart`.

## Root Shell

- `lib/app.dart` pre-mounts the home, library, and discovery pages in a sliding stack.
- Off-screen pages keep state.
- Use `TickerMode`, `IgnorePointer`, and `ExcludeSemantics` to prevent background animation, interaction, and semantics.
- Wrap pre-mounted pages in `ImageLoadingScope`: the destination may start new image decode work only after the tab slide settles, while images already presented on the outgoing page stay visible.
- After the main-tab slide settles on the library, increment `LibraryScreen.visibilityRequest`; the pre-mounted [`双向锚点显现`](../joyal-library-playback-lyrics/references/library-playback.md) cards otherwise remain in their off-screen hidden state.
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

- Shell/navigation: `lib/app.dart`, `lib/widgets/navigation/main_shell_helpers.dart`, `lib/widgets/navigation/search_ripple_route.dart`, `bottom_nav.dart`, `glass_top_bar.dart`.
- Search page: `lib/screens/search_screen.dart`; top-bar entries also live in `home_screen.dart`, `library_screen.dart`, and `hotlist_screen.dart`.
- Sidebar: `home_sidebar.dart`.
- Infinite library canvas: `library_canvas_screen.dart`.
- Shared pinch tracking: `lib/utils/two_finger_pinch_tracker.dart`.
- Floating playback UI: `mini_player.dart`, `lib/widgets/mini_player/mini_player_lyrics.dart`, `mini_player_chrome.dart`.
- Queues and sheets: `play_queue_sheet.dart`.
- Settings route: `settings_hub_screen.dart`, `personalization_screen.dart`.
