# Dark Mode Button & Icon Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three UI elements that appear as white blocks in dark mode by branching on brightness.

**Architecture:** Inline brightness check (`Theme.of(context).brightness == Brightness.dark`) at each affected widget. Dark mode uses `context.surfaceColor` for backgrounds and `context.primaryColor` for foreground/icons. Light mode behavior unchanged.

**Tech Stack:** Flutter / Dart, Material 3, `ThemeContext` extension

## Global Constraints

- Light mode appearance must remain unchanged
- Dark mode backgrounds use `context.surfaceColor` (`#1E1E1E`), foregrounds use `context.primaryColor` (`#FFFFFF`)
- Follow AGENTS.md convention: `context.primaryColor` is text color, never button background
- No new abstractions or files
- `flutter analyze` must pass; existing tests must not break

---

### Task 1: Fix all three dark-mode white-block elements

**Files:**
- Modify: `lib/screens/settings_screen.dart:234-250` (连接服务器 button)
- Modify: `lib/screens/download_manager_screen.dart:95-103` (circular download icon)
- Modify: `lib/screens/search_screen.dart:203-214` (circular search icon)

**Interfaces:**
- Consumes: `ThemeContext` extension (`context.primaryColor`, `context.surfaceColor`), `Theme.of(context).brightness`
- Produces: (no new interfaces)

- [ ] **Step 1: Fix settings_screen.dart — "连接服务器" button**

In `lib/screens/settings_screen.dart`, find the `ElevatedButton` for "连接服务器" and add brightness branching on `backgroundColor`:

```dart
          // ── 连接按钮 ──
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? context.surfaceColor
                    : context.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                elevation: 0,
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '连接服务器',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
```

- [ ] **Step 2: Run analyze to verify settings_screen.dart change**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Fix download_manager_screen.dart — circular download icon**

In `lib/screens/download_manager_screen.dart`, find the circular icon `Container` inside the summary card and add brightness branching:

```dart
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? context.surfaceColor
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.download_done_rounded,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? context.primaryColor
                                  : null,
                            ),
                          ),
```

- [ ] **Step 4: Run analyze to verify download_manager_screen.dart change**

Run: `flutter analyze lib/screens/download_manager_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Fix search_screen.dart — circular search icon**

In `lib/screens/search_screen.dart`, find the circular icon `Container` in the empty state and add brightness branching:

```dart
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? context.surfaceColor
                        : context.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? context.primaryColor
                        : Colors.white,
                    size: 32,
                  ),
                ),
```

- [ ] **Step 6: Run analyze to verify search_screen.dart change**

Run: `flutter analyze lib/screens/search_screen.dart`
Expected: No issues found.

- [ ] **Step 7: Run full analyze and tests**

Run: `flutter analyze lib test`
Expected: No issues found.

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/settings_screen.dart lib/screens/download_manager_screen.dart lib/screens/search_screen.dart docs/superpowers/specs/2026-06-28-dark-mode-button-icon-fix-design.md docs/superpowers/plans/2026-06-28-dark-mode-button-icon-fix.md
git commit -m "fix: resolve dark mode white-block buttons and icons

- settings: connect button uses surfaceColor background in dark mode
- download manager: circular icon uses surfaceColor + primaryColor icon in dark mode
- search: circular icon uses surfaceColor + primaryColor icon in dark mode"
```
