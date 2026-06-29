# Home Sidebar and Settings Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a home-tab right-swipe sidebar, remove the favorites "My" button, and move the old quick actions into a settings hub.

**Architecture:** Keep drawer ownership in `MainShell` so the tab content, mini player, and bottom Dock transform together. Add a focused `HomeSidebar` widget for the 70% panel and a focused `SettingsHubScreen` for server settings, refresh, downloads, cache, and about.

**Tech Stack:** Flutter, Dart, Material 3, Riverpod, existing `libraryProvider`, `authProvider`, and player shell widgets.

---

## File Structure

- Modify `lib/app.dart`: remove `MyScreen` navigation, add drawer animation/progress state, wrap the existing shell content in a transform/blur layer, and show `HomeSidebar` behind it.
- Create `lib/widgets/home_sidebar.dart`: render the sidebar placeholder content and fixed lower-left settings button.
- Create `lib/screens/settings_hub_screen.dart`: render the new settings hub and migrate quick actions from `MyScreen`.
- Leave `lib/screens/settings_screen.dart` as the server connection form.
- Leave `lib/screens/my_screen.dart` unused for now unless a later cleanup task removes it after tests pass.
- Modify `test/widget_test.dart`: add regression coverage for the missing favorites profile button and the reachable settings hub entries.

## Task 1: Add Settings Hub Screen

**Files:**
- Create: `lib/screens/settings_hub_screen.dart`
- Test later in: `test/widget_test.dart`

- [ ] **Step 1: Create the settings hub screen**

Use `apply_patch` to add `lib/screens/settings_hub_screen.dart` with this structure:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/library_provider.dart';
import 'cache_management_screen.dart';
import 'download_manager_screen.dart';
import 'settings_screen.dart';

class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          _SettingsHubItem(
            icon: Icons.dns_outlined,
            title: '服务器连接',
            subtitle: '配置 Navidrome 地址、用户名和密码',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _SettingsHubItem(
            icon: Icons.cached_outlined,
            title: '刷新曲库',
            subtitle: '重新同步专辑、歌曲和收藏',
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在刷新曲库')),
              );
              await ref.read(libraryProvider.notifier).refreshLibrary();
              if (!context.mounted) return;
              final error = ref.read(libraryProvider).error;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error == null ? '曲库已刷新' : '刷新失败: $error')),
              );
            },
          ),
          _SettingsHubItem(
            icon: Icons.download_for_offline_outlined,
            title: '下载管理',
            subtitle: '查看、播放和删除已下载音乐',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DownloadManagerScreen()),
            ),
          ),
          _SettingsHubItem(
            icon: Icons.storage_rounded,
            title: '缓存管理',
            subtitle: '查看缓存占用、分类清理和自动清理策略',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CacheManagementScreen()),
            ),
          ),
          _SettingsHubItem(
            icon: Icons.info_outline,
            title: '关于 Joyal Music',
            subtitle: '版本 1.0.0',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Joyal Music',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Joyal Music',
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHubItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsHubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, size: 20, color: AppTheme.primaryText),
      ),
      title: Text(title, style: AppTheme.bodyLarge),
      subtitle: Text(subtitle, style: AppTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.secondaryText),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 2: Run analyzer for the new file**

Run: `dart analyze lib/screens/settings_hub_screen.dart`

Expected: analyzer exits with no issues for this file. If Flutter tooling hangs in the sandbox, rerun with escalated permissions.

## Task 2: Add Sidebar Widget

**Files:**
- Create: `lib/widgets/home_sidebar.dart`

- [ ] **Step 1: Create the sidebar widget**

Use `apply_patch` to add `lib/widgets/home_sidebar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';

class HomeSidebar extends ConsumerWidget {
  final VoidCallback onSettingsTap;

  const HomeSidebar({super.key, required this.onSettingsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Joyal Music', style: AppTheme.headlineLarge),
            const SizedBox(height: 6),
            Text('私人音乐空间', style: AppTheme.bodyMedium),
            const SizedBox(height: 28),
            _ConnectionStatus(
              connected: authState.isConnected,
              baseUrl: authState.baseUrl,
            ),
            const SizedBox(height: 28),
            const _ReservedItem(icon: Icons.auto_awesome_outlined, title: '灵感入口'),
            const _ReservedItem(icon: Icons.history_rounded, title: '最近动态'),
            const _ReservedItem(icon: Icons.tune_rounded, title: '个性化预留'),
            const Spacer(),
            Align(
              alignment: Alignment.bottomLeft,
              child: IconButton.filledTonal(
                tooltip: '设置',
                onPressed: onSettingsTap,
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final bool connected;
  final String? baseUrl;

  const _ConnectionStatus({required this.connected, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.cloud_done : Icons.cloud_off,
            color: connected ? Colors.green : AppTheme.secondaryText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(connected ? 'Navidrome 已连接' : '未连接服务器', style: AppTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  connected ? (baseUrl ?? '') : '前往设置配置连接',
                  style: AppTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservedItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ReservedItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.secondaryText),
          const SizedBox(width: 12),
          Text(title, style: AppTheme.bodyMedium),
          const Spacer(),
          Text('预留', style: AppTheme.caption),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer for the sidebar file**

Run: `dart analyze lib/widgets/home_sidebar.dart`

Expected: analyzer exits with no issues for this file. If Flutter tooling hangs in the sandbox, rerun with escalated permissions.

## Task 3: Wire Sidebar Into MainShell

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Update imports**

In `lib/app.dart`, remove:

```dart
import 'screens/my_screen.dart';
```

Add:

```dart
import 'dart:ui';

import 'screens/settings_hub_screen.dart';
import 'widgets/home_sidebar.dart';
```

Keep `dart:async` as the first Dart import and place `dart:ui` next to it.

- [ ] **Step 2: Add drawer state to `_MainShellState`**

Inside `_MainShellState`, add:

```dart
static const double _drawerWidthFactor = 0.70;
static const double _drawerOpenThreshold = 0.35;
static const double _drawerMaxBlur = 8;
static const double _drawerMinScale = 0.94;

double _drawerProgress = 0;
bool _isDraggingDrawer = false;
```

- [ ] **Step 3: Add drawer helper methods**

Inside `_MainShellState`, add:

```dart
bool get _isDrawerOpen => _drawerProgress > 0.001;

void _setDrawerProgress(double value) {
  setState(() => _drawerProgress = value.clamp(0.0, 1.0));
}

void _closeDrawer() => _setDrawerProgress(0);

void _openSettingsHub() {
  _closeDrawer();
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SettingsHubScreen()),
  );
}

void _handleDrawerDragStart(DragStartDetails details) {
  _isDraggingDrawer = _currentTab == 0 || _isDrawerOpen;
}

void _handleDrawerDragUpdate(DragUpdateDetails details, double drawerWidth) {
  if (!_isDraggingDrawer || drawerWidth <= 0) return;
  final delta = details.primaryDelta ?? 0;
  if (!_isDrawerOpen && delta <= 0) return;
  _setDrawerProgress(_drawerProgress + delta / drawerWidth);
}

void _handleDrawerDragEnd(DragEndDetails details) {
  if (!_isDraggingDrawer) return;
  _isDraggingDrawer = false;
  final velocity = details.primaryVelocity ?? 0;
  if (velocity > 300 || (_drawerProgress >= _drawerOpenThreshold && velocity > -300)) {
    _setDrawerProgress(1);
  } else {
    _closeDrawer();
  }
}
```

- [ ] **Step 4: Extract current shell body**

In `build`, keep the existing `hasSong` calculation. Replace the current `return Scaffold(...)` with a `LayoutBuilder` that computes drawer width and calls a new private builder:

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final drawerWidth = constraints.maxWidth * _drawerWidthFactor;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _handleDrawerDragStart,
        onHorizontalDragUpdate: (details) => _handleDrawerDragUpdate(details, drawerWidth),
        onHorizontalDragEnd: _handleDrawerDragEnd,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: drawerWidth,
              child: HomeSidebar(onSettingsTap: _openSettingsHub),
            ),
            _buildTransformedShell(hasSong: hasSong, drawerWidth: drawerWidth),
          ],
        ),
      ),
    );
  },
);
```

- [ ] **Step 5: Add `_buildTransformedShell`**

Add this method to `_MainShellState`:

```dart
Widget _buildTransformedShell({
  required bool hasSong,
  required double drawerWidth,
}) {
  final progress = _drawerProgress;
  final scale = 1 - ((1 - _drawerMinScale) * progress);
  final blur = _drawerMaxBlur * progress;

  return Transform.translate(
    offset: Offset(drawerWidth * progress, 0),
    child: Transform.scale(
      scale: scale,
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28 * progress),
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(index: _currentTab, children: _screens),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MiniPlayer(onTap: _openNowPlaying),
                    ColoredBox(
                      color: hasSong ? AppTheme.miniPlayerBg : AppTheme.background,
                      child: AppBottomNav(
                        currentIndex: _currentTab,
                        onTabChanged: (index) {
                          _closeDrawer();
                          _onTabChanged(index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (progress > 0)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeDrawer,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.05 * progress),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 6: Remove the favorites floating action button**

Delete the `floatingActionButton: _currentTab == 2 ? ... : null` block from `MainShell.build`.

- [ ] **Step 7: Run analyzer for `app.dart`**

Run: `dart analyze lib/app.dart`

Expected: no unused imports, no missing symbols. If the method signatures or line wrapping need formatting, run `dart format lib/app.dart`.

## Task 4: Add Widget Tests

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Add tests for removed profile entry and settings hub**

Append these tests inside `main()`:

```dart
testWidgets('favorites tab no longer shows My floating action button', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));

  await tester.tap(find.text('鏀惰棌'));
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.person_outline), findsNothing);
});

testWidgets('home sidebar settings button opens settings hub', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));

  await tester.drag(find.byType(Scaffold).first, const Offset(320, 0));
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.settings_outlined).first);
  await tester.pumpAndSettle();

  expect(find.text('设置'), findsOneWidget);
  expect(find.text('服务器连接'), findsOneWidget);
  expect(find.text('刷新曲库'), findsOneWidget);
  expect(find.text('下载管理'), findsOneWidget);
  expect(find.text('缓存管理'), findsOneWidget);
  expect(find.text('关于 Joyal Music'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused tests**

Run: `flutter test test/widget_test.dart`

Expected: all tests in `widget_test.dart` pass. If Flutter hangs due to sandboxing, rerun with escalated permissions.

- [ ] **Step 3: Adjust only for legitimate test mechanics**

If `find.byType(Scaffold).first` does not receive the drag in widget tests, change the drag target to a stable visible home text:

```dart
await tester.drag(find.text('鎼滅储姝屾洸銆佷笓杈戞垨鑹轰汉'), const Offset(320, 0));
```

Rerun `flutter test test/widget_test.dart` and expect pass.

## Task 5: Full Verification

**Files:**
- No new source files unless analyzer requires formatting changes.

- [ ] **Step 1: Format touched Dart files**

Run:

```bash
dart format lib/app.dart lib/widgets/home_sidebar.dart lib/screens/settings_hub_screen.dart test/widget_test.dart
```

Expected: formatter completes and reports formatted files or "Changed 0 files".

- [ ] **Step 2: Run static analysis**

Run:

```bash
dart analyze lib test
```

Expected: no errors. Existing non-error info warnings should be reported in the handoff if present.

- [ ] **Step 3: Run tests**

Run:

```bash
flutter test
```

Expected: all tests pass. If Flutter tooling hangs due to sandboxing, rerun with escalated permissions and mention the rerun in the final handoff.

- [ ] **Step 4: Manual visual smoke check**

Run the app or build the APK according to the user's normal review flow. For release APK verification, use:

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```

Expected release output:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Check these interactions on device or emulator:

- On the home tab, right swipe from the page body opens a 70% side panel.
- The visible 30% home preview scales slightly and blurs as the panel opens.
- Tapping the visible preview closes the panel.
- Recent-album horizontal scrolling remains usable.
- The mini player and bottom Dock transform with the main shell.
- The favorites tab no longer shows the "My" floating button.
- The side panel settings button opens the settings hub, and each real entry navigates or acts correctly.

## Commit Notes

The workspace currently reports `fatal: not a git repository` even when commands are escalated, despite a `.git` directory being visible. If git becomes available, commit in small chunks:

```bash
git add lib/screens/settings_hub_screen.dart lib/widgets/home_sidebar.dart
git commit -m "feat: add settings hub and home sidebar"
git add lib/app.dart test/widget_test.dart
git commit -m "feat: wire home sidebar into shell"
```

If git remains unavailable, complete implementation and verification, then report that commits were blocked by repository metadata access.
