# Dark Mode Button & Icon Fix

**Date**: 2026-06-28  
**Status**: approved

## Problem

Three UI elements appear as white blocks in dark mode because `context.primaryColor` (which resolves to `#FFFFFF` in dark mode) is used as a background color, and the foreground/icons are also white:

| Location | File | Root Cause |
|---|---|---|
| "连接服务器" button | `lib/screens/settings_screen.dart` ~L234 | `backgroundColor: context.primaryColor` |
| Circular download icon | `lib/screens/download_manager_screen.dart` ~L98 | `color: Colors.white` hardcoded + icon inherits theme white |
| Circular search icon | `lib/screens/search_screen.dart` ~L207 | `color: context.primaryColor` + icon `color: Colors.white` |

## Constraint

Light mode appearance must remain unchanged. Only dark mode is fixed.

## Design

Pattern: branch on `Theme.of(context).brightness == Brightness.dark`. In dark mode, use `context.surfaceColor` (`#1E1E1E`) for backgrounds and `context.primaryColor` (`#FFFFFF`) for foreground/icons. In light mode, keep existing values.

This follows the project convention from AGENTS.md:
> `context.primaryColor` 语义是主文字色（浅黑深白），不可做按钮背景。操作按钮深色模式用 `context.surfaceColor` 底 + `context.primaryColor` 字。

### 1. Settings "连接服务器" button (`settings_screen.dart`)

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: isDark ? context.surfaceColor : context.primaryColor,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
    elevation: 0,
  ),
  // ...
)
```

- Light: black background, white text (unchanged)
- Dark: `#1E1E1E` background, white text

### 2. Download manager circular icon (`download_manager_screen.dart`)

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

Container(
  width: 52,
  height: 52,
  decoration: BoxDecoration(
    color: isDark ? context.surfaceColor : Colors.white,
    shape: BoxShape.circle,
  ),
  child: Icon(
    Icons.download_done_rounded,
    color: isDark ? context.primaryColor : null,
  ),
)
```

- Light: white circle, default icon color (black) — unchanged
- Dark: `#1E1E1E` circle, white icon

### 3. Search page circular icon (`search_screen.dart`)

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

Container(
  width: 72,
  height: 72,
  decoration: BoxDecoration(
    color: isDark ? context.surfaceColor : context.primaryColor,
    shape: BoxShape.circle,
  ),
  child: Icon(
    Icons.music_note_rounded,
    color: isDark ? context.primaryColor : Colors.white,
    size: 32,
  ),
)
```

- Light: black circle, white icon (unchanged)
- Dark: `#1E1E1E` circle, white icon

## Testing

- Manual verification: toggle dark mode, confirm the three elements are no longer white blocks
- Existing `flutter analyze` and `flutter test` should pass (no API changes)

## Scope

Three files, ~5 lines changed each. No new abstractions, no light-mode behavioral changes.
