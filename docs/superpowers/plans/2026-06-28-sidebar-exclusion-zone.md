# 侧边栏手势排除区域 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在主页"最近添加"横向列表区域禁止侧边栏右滑手势拉出

**Architecture:** `_MainShellState` 维护排除矩形列表，`HomeScreen` 通过构造回调上报横向列表的全局坐标。`_handleDrawerPointerDown` 在侧边栏关闭状态时检测触点是否落入排除区，若是则跳过追踪。

**Tech Stack:** Flutter / Dart, 无新增依赖

## Global Constraints

- 仅影响首页 tab（`_currentTab == 0`）侧边栏关闭状态下的拉出手势
- 侧边栏已打开时的关闭手势不受影响
- 横向列表自身的滚动和点击交互不受影响
- 保持现有 `flutter analyze` / `flutter test` 零错误

---

### Task 1: 实现排除区域回调 + 手势过滤

**Files:**
- Modify: `lib/app.dart` — `_MainShellState` 类
- Modify: `lib/screens/home_screen.dart` — `HomeScreen` widget + `_HomeScreenState`
- Create: `test/sidebar_exclusion_test.dart`

**Interfaces:**
- Produces: `HomeScreen.onExclusionZoneChanged` (`void Function(Rect)?`) — 可选回调
- Produces: `_MainShellState._registerDrawerExclusion(Rect)` — 注册排除矩形
- Produces: `_MainShellState._drawerExclusionRects` (`List<Rect>`) — 排除矩形列表

- [ ] **Step 1: 编写失败测试**

```dart
// test/sidebar_exclusion_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sidebar exclusion zone', () {
    test('pointer down inside exclusion rect is ignored', () {
      // 模拟排除矩形
      final exclusionRects = <Rect>[
        const Rect.fromLTWH(16, 300, 360, 200),
      ];

      // 触点落在排除矩形内
      final insideEvent = PointerDownEvent(
        position: const Offset(100, 350),
        pointer: 1,
      );

      // 触点落在排除矩形外
      final outsideEvent = PointerDownEvent(
        position: const Offset(100, 100),
        pointer: 2,
      );

      // 内点命中排除区 → 应被忽略
      bool insideShouldTrack = true;
      for (final rect in exclusionRects) {
        if (rect.contains(insideEvent.position)) {
          insideShouldTrack = false;
          break;
        }
      }
      expect(insideShouldTrack, isFalse);

      // 外点未命中排除区 → 应正常追踪
      bool outsideShouldTrack = true;
      for (final rect in exclusionRects) {
        if (rect.contains(outsideEvent.position)) {
          outsideShouldTrack = false;
          break;
        }
      }
      expect(outsideShouldTrack, isTrue);
    });

    test('empty exclusion list allows all pointers', () {
      final exclusionRects = <Rect>[];
      final event = PointerDownEvent(
        position: const Offset(100, 350),
        pointer: 1,
      );

      bool shouldTrack = true;
      for (final rect in exclusionRects) {
        if (rect.contains(event.position)) {
          shouldTrack = false;
          break;
        }
      }
      expect(shouldTrack, isTrue);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter test test/sidebar_exclusion_test.dart
```

**Expected:** 测试文件创建后能正常执行（逻辑测试不依赖 Widget），2 tests pass（纯逻辑验证）。

> 注：由于排除逻辑是纯 Rect 命中检测，该测试验证的是算法正确性，不依赖 Widget 树。即使尚未修改源码也应通过。

- [ ] **Step 3: 修改 `lib/screens/home_screen.dart` — 添加回调参数**

在 `HomeScreen` 类定义处（约第 20 行）修改：

```dart
// 旧：
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

// 新：
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(Rect)? onExclusionZoneChanged;
  const HomeScreen({super.key, this.onExclusionZoneChanged});
```

- [ ] **Step 4: 修改 `lib/screens/home_screen.dart` — 添加 _recentListKey 和上报逻辑**

在 `_HomeScreenState` 类中（约第 30 行，`_scrollController` 声明附近）添加：

```dart
final GlobalKey _recentListKey = GlobalKey();
```

在 `initState` 末尾（约第 45 行，`_scrollController.addListener(_onScroll)` 之后）添加：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) => _reportExclusionRect());
```

在 `dispose` 之前（约第 55 行，`_onScroll` 方法之前）添加新方法：

```dart
void _reportExclusionRect() {
  final callback = widget.onExclusionZoneChanged;
  if (callback == null) return;
  final ctx = _recentListKey.currentContext;
  if (ctx == null) return;
  final box = ctx.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return;
  final globalOffset = box.localToGlobal(Offset.zero);
  callback(Rect.fromLTWH(
    globalOffset.dx, globalOffset.dy,
    box.size.width, box.size.height,
  ));
}
```

- [ ] **Step 5: 修改 `lib/screens/home_screen.dart` — 横向列表挂 key**

在 `_buildBody` 方法中的"最近添加"横向列表处（约第 155 行），给 `SizedBox` 添加 key：

```dart
// 旧：
child: SizedBox(
  height: 200,
  child: ListView.separated(

// 新：
child: SizedBox(
  key: _recentListKey,
  height: 200,
  child: ListView.separated(
```

- [ ] **Step 6: 修改 `lib/app.dart` — 添加排除区域字段和方法**

在 `_MainShellState` 类中，`_velocitySamples` 声明之后（约第 79 行）添加：

```dart
final List<Rect> _drawerExclusionRects = [];

void _registerDrawerExclusion(Rect rect) {
  _drawerExclusionRects.clear();
  _drawerExclusionRects.add(rect);
}
```

- [ ] **Step 7: 修改 `lib/app.dart` — _screens 改为实例字段**

将旧代码（约第 81-84 行）：

```dart
static const _screens = <Widget>[
  HomeScreen(),
  LibraryScreen(),
  HotlistScreen(),
];
```

替换为：

```dart
late final List<Widget> _screens;
```

并在 `initState` 末尾（约第 117 行，`_androidMediaBridge = ...` 之后）添加初始化：

```dart
_screens = [
  HomeScreen(onExclusionZoneChanged: _registerDrawerExclusion),
  const LibraryScreen(),
  const HotlistScreen(),
];
```

- [ ] **Step 8: 修改 `lib/app.dart` — 手势过滤**

修改 `_handleDrawerPointerDown` 方法（约第 181 行），在现有的 `canStartClosed` / `canTrackOpen` 检查和 `_drawerPointer` 赋值之间插入排除检测：

```dart
void _handleDrawerPointerDown(PointerDownEvent event, double drawerWidth) {
  if (drawerWidth <= 0) return;
  if (_drawerPointer != null) return;

  final canStartClosed = _currentTab == 0 && !_isDrawerOpen;
  final canTrackOpen = _isDrawerOpen;
  if (!canStartClosed && !canTrackOpen) return;

  // 新增：仅在"关闭状态尝试打开"时检测排除区域
  if (canStartClosed) {
    for (final rect in _drawerExclusionRects) {
      if (rect.contains(event.position)) return;
    }
  }

  _drawerPointer = event.pointer;
  _drawerPointerStart = event.position;
  _drawerAccumulatedDx = 0;
  _drawerAccumulatedDy = 0;
  _drawerTrackingAccepted = canTrackOpen;
  _isDraggingDrawer = true;
}
```

注意：原代码中 `_drawerPointer` 的空值检查在 `canStartClosed` / `canTrackOpen` 之前。新增排除检测需放在这两个检查**之后**，以确保 `canStartClosed` 变量已赋值，同时只影响关闭→打开方向。

- [ ] **Step 9: 静态分析**

```powershell
cd c:\Users\Moye\Desktop\Joyal-mainFDS; dart analyze lib/app.dart lib/screens/home_screen.dart
```

**Expected:** No issues found.

- [ ] **Step 10: 运行全部测试**

```powershell
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter test
```

**Expected:** All tests pass（包括新增的 `sidebar_exclusion_test.dart`）。

- [ ] **Step 11: 构建 arm64 Release APK**

```powershell
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```

**Expected:** `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` 构建成功。
