# Home Sidebar and Settings Hub Design

## Goal

Replace the old "My" entry on the favorites page with a home-page side panel that opens by swiping right anywhere on the home tab. The panel should feel like part of the existing immersive shell: it occupies about 70% of the screen, leaves the right 30% showing the home content, progressively blurs and slightly scales the home content while dragging, and keeps the Dock relationship clean.

The existing quick actions from `MyScreen` move into a new settings hub. The side panel itself can contain reserved placeholder content for now, without presenting unfinished features as complete.

## Current Context

- `MainShell` in `lib/app.dart` owns the root `Stack`, tab selection, `MiniPlayer`, and `AppBottomNav`.
- The bottom navigation already has three tabs: home, library, and favorites.
- The favorites page currently gets a `FloatingActionButton.small` in `MainShell` when `_currentTab == 2`; that button opens `MyScreen`.
- `MyScreen` contains connection status, an app bar settings icon, and quick actions for refresh library, download manager, cache management, and about.
- `SettingsScreen` currently only handles Navidrome server connection.

## Chosen Approach

Implement the drawer behavior at the `MainShell` layer.

This keeps the home content, top bar, mini player, and bottom Dock moving as one visual surface. It also avoids placing a custom drawer inside `HomeScreen`, where the floating shell layers would remain visually detached.

The side panel opens only when the home tab is active, but the gesture can start from anywhere on the home surface. Horizontal album scrolling should remain usable; the drawer gesture should only take over when the drag clearly intends to open the side panel.

## Interaction Design

- Right swipe on the home tab opens the side panel.
- The side panel width is `screenWidth * 0.70`.
- Drag progress runs from `0.0` closed to `1.0` open.
- While progress increases:
  - The main shell translates right with the panel reveal.
  - The main shell scales down slightly, ending around `0.94`.
  - A blur overlay increases gradually over the visible home content, ending around `ImageFilter.blur(sigmaX: 8, sigmaY: 8)`.
  - The right 30% remains visible as a preview of the current home state.
- Tapping the visible right preview closes the panel.
- Dragging left while open closes it.
- The bottom navigation and mini player should be transformed with the main shell, preserving the transparent Dock convention.

## Gesture Handling

The drawer gesture should be available from anywhere on the home tab, not just the left edge.

To reduce conflict with horizontal album lists:

- Start tracking horizontal drags at the shell layer only when `_currentTab == 0`.
- Open from a closed state when the drag delta is primarily horizontal and moving right.
- Do not force-open from tiny accidental horizontal movement; require a small threshold before applying progress.
- When the gesture ends, settle open if progress is at least about `0.35` or rightward velocity is strong; otherwise settle closed.
- When open, leftward horizontal drags should close regardless of where they start.

Vertical scroll and taps should remain unchanged.

## Side Panel Content

The side panel is intentionally light for this iteration:

- A compact app identity/header area.
- A Navidrome connection status row using `authProvider`.
- A few placeholder rows for future sections, visually marked as reserved or inactive.
- A settings button fixed near the lower-left corner.

The placeholder rows must not navigate to unfinished pages or claim features that do not exist yet.

## Settings Hub

Create a new settings hub screen that becomes the target of the side panel settings button.

The hub contains:

- Server connection entry, opening the existing `SettingsScreen`.
- Refresh library action, using `libraryProvider.notifier.refreshLibrary()` so albums, all songs, and favorites stay in sync.
- Download manager entry, opening `DownloadManagerScreen`.
- Cache management entry, opening `CacheManagementScreen`.
- About entry, showing the existing about dialog.

This replaces the old `MyScreen` workflow. `MyScreen` can be removed from active navigation; if kept temporarily, it should no longer be reachable from the favorites page.

## Code Structure

Expected implementation points:

- `lib/app.dart`
  - Remove the favorites-page floating "My" button.
  - Remove the `MyScreen` import if unused.
  - Add drawer progress state, gesture handling, animation settle behavior, and the root transformed shell layout.
- `lib/widgets/home_sidebar.dart`
  - New side panel widget with placeholder content and a bottom-left settings button.
- `lib/screens/settings_hub_screen.dart`
  - New settings hub screen containing the migrated quick actions.
- `lib/screens/settings_screen.dart`
  - Keep as the server connection screen.
- `lib/screens/home_screen.dart`
  - No major ownership change expected; only adjust if gesture conflict requires a narrow coordination hook.

## Error Handling

- Refresh library should show a SnackBar for start and failure if the provider reports an error after refresh.
- Settings navigation should use normal `Navigator.push`.
- Drawer animation should be resilient to orientation and width changes by deriving width from `MediaQuery` or `LayoutBuilder`.

## Testing

Run static analysis after implementation:

```bash
dart analyze lib test
```

Add or update widget tests where practical:

- Verify favorites tab no longer shows the profile floating action button.
- Verify the settings hub exposes entries for server connection, refresh library, download manager, cache management, and about.
- If the drawer gesture is testable without brittle animation timing, verify a right drag on the home tab reveals the side panel.

Manual visual checks:

- Home right swipe opens panel to about 70% width.
- Right 30% preview remains visible, blurred, and slightly scaled.
- Horizontal recent-album scrolling still works naturally.
- Mini player and bottom Dock move with the main shell.
- Favorites page has no "My" button.
