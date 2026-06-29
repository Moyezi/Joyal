# Sidebar 关闭动画 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 HomeSidebar 的关闭路径（点击模糊区、左滑、切Tab）加上流畅的动画过渡，替代当前的瞬间弹回。

**Architecture:** 用 `AnimationController` 替换裸 `_drawerProgress` double。手势拖拽时直接设 `controller.value`，松手/点击后通过 `animateTo` 驱动过渡。速度自适应 duration 模拟左滑惯性。

**Tech Stack:** Flutter / Dart, `AnimationController`, `SingleTickerProviderStateMixin`

## Global Constraints

- 仅改 `lib/app.dart` 中的 `_MainShellState`
- 不引入新依赖
- 现有测试继续通过
- `SingleTickerProviderStateMixin` 加混入无副作用

---

### Task 1: 侧边栏关闭动画

**Files:**
- Modify: `lib/app.dart` — `_MainShellState` 全文

**Interfaces:**
- Consumes: `HomeSidebar`（widget，不变）、`AppTheme`（常量，不变）
- Produces: `_drawerController`（AnimationController，内部状态）

---

- [ ] **Step 1: 加 `SingleTickerProviderStateMixin` 混入**

```dart
class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
```

- [ ] **Step 2: 替换成员变量**

删除 `double _drawerProgress = 0;`，新增以下成员：

在现有静态常量下方（`_drawerMinScale` 之后）加入 duration 常量：

```dart
  static const Duration _snapDuration = Duration(milliseconds: 200);
  static const Duration _tapCloseDuration = Duration(milliseconds: 220);
```

在 `bool _suppressNextDrawerTap = false;` 之后加入：

```dart
  late final AnimationController _drawerController;
  double _lastDrawerWidth = 0;
  final List<_VelocitySample> _velocitySamples = [];
```

在文件末尾（`_MainShellState` 的 `dispose` 之后或同文件 scope 内）加入：

```dart
class _VelocitySample {
  final Duration timestamp;
  final double deltaDx;
  const _VelocitySample({required this.timestamp, required this.deltaDx});
}
```

- [ ] **Step 3: 更新 `initState`**

在 `super.initState();` 之后、`_androidMediaBridge = ...` 之前插入：

```dart
    _drawerController = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _drawerController.addListener(() {
      if (mounted) setState(() {});
    });
```

- [ ] **Step 4: 更新 `_isDrawerOpen` getter**

```dart
  bool get _isDrawerOpen => _drawerController.value > 0.001;
```

- [ ] **Step 5: 重写 `_setDrawerProgress`**

```dart
  void _setDrawerProgress(double value) {
    if (!mounted) return;
    _drawerController.stop();
    _drawerController.value = value.clamp(0.0, 1.0);
  }
```

- [ ] **Step 6: 重写 `_closeDrawer`**

```dart
  void _closeDrawer() {
    if (!mounted) return;
    _drawerController.animateTo(0.0,
        duration: _tapCloseDuration, curve: Curves.easeIn);
  }
```

- [ ] **Step 7: 添加速度辅助方法**

在 `_resetDrawerPointerTracking()` 方法后添加：

```dart
  void _recordVelocitySample(double deltaDx, Duration timestamp) {
    _velocitySamples.add(_VelocitySample(timestamp: timestamp, deltaDx: deltaDx));
    while (_velocitySamples.length > 5) {
      _velocitySamples.removeAt(0);
    }
  }

  double _estimateVelocity() {
    if (_velocitySamples.length < 2) return 0.0;
    double totalDx = 0.0;
    double totalDt = 0.0;
    for (int i = 1; i < _velocitySamples.length; i++) {
      totalDx += _velocitySamples[i].deltaDx;
      totalDt += (_velocitySamples[i].timestamp -
                  _velocitySamples[i - 1].timestamp)
              .inMicroseconds /
          1000000.0;
    }
    if (totalDt <= 0.0) return 0.0;
    return totalDx / totalDt; // pixels per second
  }

  void _snapAfterRelease() {
    final progress = _drawerController.value;
    if (progress >= _drawerOpenThreshold) {
      _drawerController.animateTo(1.0,
          duration: _snapDuration, curve: Curves.easeOut);
      _velocitySamples.clear();
      return;
    }
    final pixelVelocity = _estimateVelocity();
    final progressVelocity =
        _lastDrawerWidth > 0 ? (pixelVelocity / _lastDrawerWidth).abs() : 0.0;
    _velocitySamples.clear();
    final remaining = progress;
    final speed = progressVelocity.clamp(0.5, 8.0);
    final durationMs = (remaining / speed * 1000).clamp(120.0, 220.0).toInt();
    _drawerController.animateTo(0.0,
        duration: Duration(milliseconds: durationMs), curve: Curves.easeOut);
  }
```

- [ ] **Step 8: 更新 `_handleDrawerPointerMove` 添加速度记录**

在方法末尾，`_setDrawerProgress(...)` 调用之后添加：

```dart
    _recordVelocitySample(event.delta.dx, event.timeStamp);
```

同时将方法体内的 `_drawerProgress` 引用改为 `_drawerController.value`：

```dart
    if (!_isDrawerOpen && delta.dx <= 0) return;
    _setDrawerProgress(_drawerController.value + delta.dx / drawerWidth);
    _recordVelocitySample(event.delta.dx, event.timeStamp);
```

- [ ] **Step 9: 更新 `_handleDrawerPointerUpOrCancel` 使用动画**

将方法体替换为：

```dart
  void _handleDrawerPointerUpOrCancel(int pointer) {
    if (_drawerPointer != pointer) return;
    if (_drawerTrackingAccepted) {
      _suppressNextDrawerTap =
          _drawerAccumulatedDx.abs() > 4 || _drawerAccumulatedDy.abs() > 4;
      _snapAfterRelease();
    }
    _resetDrawerPointerTracking();
  }
```

- [ ] **Step 10: 更新 `_handleDrawerPreviewTap`**

```dart
  void _handleDrawerPreviewTap() {
    if (_suppressNextDrawerTap) {
      _suppressNextDrawerTap = false;
      return;
    }
    _closeDrawer();
  }
```

（保持不变——`_closeDrawer()` 已有动画）

- [ ] **Step 11: 更新 `_buildTransformedShell` 中的 `_drawerProgress` 引用**

将方法内 `final progress = _drawerProgress;` 改为：

```dart
    final progress = _drawerController.value;
```

- [ ] **Step 12: 在 `build` 方法中存储 `drawerWidth`**

在 `LayoutBuilder` 的 `builder` 回调开头，`final drawerWidth = ...` 之后添加：

```dart
        _lastDrawerWidth = drawerWidth;
```

- [ ] **Step 13: 更新 `dispose`**

在 `_androidMediaBridge?.dispose();` 之后、`super.dispose();` 之前插入：

```dart
    _drawerController.dispose();
```

- [ ] **Step 14: 运行静态分析和测试**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS
flutter analyze lib\app.dart
```

预期：无新增 issue。

```bash
flutter test
```

预期：所有现有测试通过。

- [ ] **Step 15: Commit**

```bash
git add lib/app.dart docs/superpowers/specs/2026-06-28-sidebar-close-animation-design.md docs/superpowers/plans/2026-06-28-sidebar-close-animation.md
git commit -m "feat: add animated close transition for sidebar drawer"
```

---

## Self-Review

- **Spec coverage:** ✅ 所有 4 个动画场景（弹全开、弹回收起、点击关闭、左滑惯性关闭）均覆盖
- **Placeholder scan:** ✅ 无 TBD/TODO/占位符，所有代码完整
- **Type consistency:** ✅ `_drawerController` 类型贯穿一致，`_VelocitySample` 定义在文件末尾
