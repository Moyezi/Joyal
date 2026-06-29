# 侧边栏手势排除区域 — 设计文档

**日期**：2026-06-28
**范围**：在主页"最近添加"横向列表区域禁止侧边栏右滑手势

## 问题

主页"最近添加"是横向滚动 `ListView`。用户在列表上右滑浏览专辑时，外层 `Listener` 同时检测到右滑手势，误触发侧边栏拉出。

当前侧边栏手势由 `app.dart` 中最外层 `Listener（HitTestBehavior.translucent）` 统一捕获，手势识别条件为：首页 tab + 右滑 >18px + 水平主导 + 累计右移。

## 方案

采用**回调式排除区域**：`_MainShellState` 维护排除矩形列表，`HomeScreen` 通过构造回调上报"最近添加"横向列表的全局坐标区域。在 `_handleDrawerPointerDown` 中检测落点是否在排除区内，若在则直接返回，不启动侧边栏追踪。

### 改动文件

- `lib/app.dart` — `_MainShellState`
- `lib/screens/home_screen.dart` — `_HomeScreenState`

### 数据结构

`_MainShellState` 新增：

```dart
final List<Rect> _drawerExclusionRects = [];

void _registerDrawerExclusion(Rect rect) {
  _drawerExclusionRects.clear();
  _drawerExclusionRects.add(rect);
}
```

`_screens` 从 `static const` 改为实例字段，以便向 `HomeScreen` 传入回调：

```dart
// 旧：static const _screens = <Widget>[HomeScreen(), ...];
// 新：
late final List<Widget> _screens;
// 在 initState 末尾：
_screens = [
  HomeScreen(onExclusionZoneChanged: _registerDrawerExclusion),
  const LibraryScreen(),
  const HotlistScreen(),
];
```

### HomeScreen 接口

```dart
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(Rect)? onExclusionZoneChanged;
  const HomeScreen({super.key, this.onExclusionZoneChanged});
}
```

### 手势过滤

`_handleDrawerPointerDown` 开头增加排除矩形命中检测：

```dart
void _handleDrawerPointerDown(PointerDownEvent event, double drawerWidth) {
  if (drawerWidth <= 0) return;
  if (_drawerPointer != null) return;

  // 触点落在排除区域内 → 不启动侧边栏追踪
  for (final rect in _drawerExclusionRects) {
    if (rect.contains(event.position)) return;
  }

  // ... 原有逻辑不变
}
```

### 排除矩形上报

`_HomeScreenState` 中：

```dart
final GlobalKey _recentListKey = GlobalKey();

@override
void initState() {
  super.initState();
  // ... 现有逻辑 ...
  WidgetsBinding.instance.addPostFrameCallback((_) => _reportExclusionRect());
}

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

横向列表 `SizedBox` 挂上 key：

```dart
SizedBox(
  key: _recentListKey,  // 新增
  height: 200,
  child: ListView.separated( ... )
```

### 上报时机

使用 `addPostFrameCallback` 在首帧布局完成后上报一次。排除矩形是静态的——该列表位于 `CustomScrollView` 顶部，位置不随滚动变化。

## 影响范围

- 仅影响首页"最近添加"横向列表区域内的侧边栏手势启动
- 列表的横向滚动、卡片点击等原生交互不受影响
- 首页其他区域（搜索框、全部专辑网格、空白区域等）的侧边栏手势不变
- 曲库页、收藏页的侧边栏手势不变（它们原本就不在首页 tab）

## 边界情况

- `onExclusionZoneChanged` 为 null 时（非首页场景），`HomeScreen` 不上报矩形，无副作用
- `_recentListKey.currentContext` 为 null 时（Widget 未挂载），静默跳过
- 排除矩形列表为空时（未上报或已清空），`_handleDrawerPointerDown` 行为与现有完全一致
- 屏幕旋转或窗口大小变化时，需重新上报矩形。`HomeScreen` 的 `didChangeDependencies` 或 `build` 后的 `postFrameCallback` 会自然触发更新（若需保证可加 `OrientationBuilder` 监听，但当前为移动端竖屏应用，暂不需）

## 测试要点

- 在"最近添加"列表上右滑 → 侧边栏不拉出，列表正常滚动
- 在首页其他区域（搜索框、专辑网格、空白区域）右滑 → 侧边栏正常拉出
- 横向列表的卡片点击进入专辑详情 → 正常
- 侧边栏已打开状态下，在列表区域左滑关闭 → 正常（排除区域不影响已打开状态的关闭手势，因为 `_handleDrawerPointerDown` 中 `canTrackOpen` 路径最早触发，排除检测在其之后。⚠️ 需确认代码顺序）

### 代码顺序确认

`_handleDrawerPointerDown` 完整逻辑顺序：

1. `drawerWidth <= 0` → return
2. `_drawerPointer != null` → return（已有指针追踪中）
3. **排除区域命中检测 → return（新增）**
4. `canStartClosed` / `canTrackOpen` → 决定是否追踪

侧边栏已打开时，`canTrackOpen` 为 true，但排除检测在步骤 3 已经返回。这意味着**侧边栏打开状态下，用户也无法从"最近添加"区域通过左滑关闭侧边栏**。

如果这是预期行为（只限制拉出，不限制关闭），则需将排除检测移至 `canStartClosed` 条件内部：

```dart
final canStartClosed = _currentTab == 0 && !_isDrawerOpen;
final canTrackOpen = _isDrawerOpen;
if (!canStartClosed && !canTrackOpen) return;

// 排除检测仅对"关闭状态下尝试打开"生效
if (canStartClosed) {
  for (final rect in _drawerExclusionRects) {
    if (rect.contains(event.position)) return;
  }
}
```

**→ 设计采用此修正版本**，确保只限制拉出，不限制关闭。

## 实现检查清单

- [ ] `app.dart`：添加 `_drawerExclusionRects`、`_registerDrawerExclusion`
- [ ] `app.dart`：`_screens` 改为实例 `late final`，`initState` 中初始化
- [ ] `app.dart`：`_handleDrawerPointerDown` 增加条件排除检测
- [ ] `home_screen.dart`：`HomeScreen` 增加 `onExclusionZoneChanged` 参数
- [ ] `home_screen.dart`：添加 `_recentListKey`、`_reportExclusionRect`、`addPostFrameCallback`
- [ ] `home_screen.dart`：横向列表 `SizedBox` 挂 `key`
- [ ] `dart analyze lib` 无新增错误
- [ ] `flutter test` 全部通过
- [ ] 构建 arm64 Release APK 供实机验证
