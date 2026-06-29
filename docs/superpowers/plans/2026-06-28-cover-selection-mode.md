# Cover Selection Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the now playing album cover long-press interaction into an in-place three-cover selection mode where dragging browses candidates and tapping the center cover confirms playback.

**Architecture:** Keep the feature inside `lib/screens/now_playing_screen.dart`, reusing the existing player state, album cover widget, and `PlayerNotifier.playAtIndex()`. Replace the prior selection overlay behavior with a bounded stack that visually grows from the original cover slot, while disabling unrelated player controls during selection.

**Tech Stack:** Flutter, Dart, Riverpod, Material gesture APIs, `HapticFeedback`, existing `AlbumCover` and player provider.

---

### Task 1: Stabilize Selection State And Lifecycle

**Files:**
- Modify: `lib/screens/now_playing_screen.dart`

- [x] **Step 1: Replace the selection animation state with explicit enter/exit and drag state**

Use one enter controller, one drag settle controller, and fields for candidate index, drag offset, and center tap bounds. Keep all fields inside `_NowPlayingScreenState`.

- [x] **Step 2: Clamp candidate index against the active playlist**

Add helper logic so an out-of-range candidate falls back to the current playback index.

- [x] **Step 3: Add enter, cancel, and confirm helpers**

`_enterSelectionMode()` should require at least two playlist songs, use `HapticFeedback.heavyImpact()`, set `_candidateIndex` to `currentIndex`, and animate in. `_cancelSelectionMode()` should animate out without playback changes. `_confirmSelection()` should call `playAtIndex()` only when the center cover is tapped.

### Task 2: Rebuild The Three-Cover Selector Layout

**Files:**
- Modify: `lib/screens/now_playing_screen.dart`

- [x] **Step 1: Replace `_buildSelectionCovers()`**

Render the selector inside the existing album-cover slot with a `LayoutBuilder` and centered `Stack`. The center cover uses the candidate song and scales from normal size to 70%; side covers use previous/next candidates, scale to 50%, and fade to 70% opacity.

- [x] **Step 2: Add drag behavior**

Horizontal drag updates `_selDragOffset`. Drag end snaps to the previous or next candidate when velocity exceeds 300 px/s or distance exceeds 30% of center cover width. Snapping changes only `_candidateIndex`, triggers `HapticFeedback.selectionClick()`, and resets drag offset.

- [x] **Step 3: Add tap behavior**

Tap inside the center cover confirms. Tap outside the center cover cancels. This avoids nested gesture conflicts and keeps the whole cover area responsive.

### Task 3: Integrate Selector With Existing Page Controls

**Files:**
- Modify: `lib/screens/now_playing_screen.dart`

- [x] **Step 1: Keep song metadata tied to the candidate while selecting**

Reuse the existing `displaySong` selection logic, clamped to playlist length.

- [x] **Step 2: Disable non-selection controls**

Wrap progress and playback controls with opacity/ignore-pointer while `_isSelecting` is true, so the waveform does not seek while browsing candidates.

- [x] **Step 3: Preserve lyrics swipe exclusion**

Keep the existing route-level horizontal lyrics gesture disabled while `_isSelecting` is true.

### Task 4: Verify

**Files:**
- Test/Run: `dart analyze lib test`
- Build/Run: `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`

- [x] **Step 1: Run static analysis**

Run `dart analyze lib test`. Expected: no analyzer errors from the touched code.

- [x] **Step 2: Build the review APK**

Run `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`. Expected output APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

- [x] **Step 3: Report verification**

Summarize changed files, analyzer/build results, and the APK path.
