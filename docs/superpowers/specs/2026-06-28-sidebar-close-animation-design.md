# Sidebar 关闭动画设计

## 概述

当前 HomeSidebar 通过手势拖拽打开有实时跟手过渡（位移/缩放/圆角/模糊），但关闭时直接 `setState` 到 0，瞬间弹回无动画。本设计为所有关闭路径加上动画过渡。

## 动机

- 点击模糊区域关闭侧边栏时，主页瞬间弹回位置，体验生硬
- 左滑收起时同样无过渡
- 松手弹到全开也没有动画（低于阈值时也一样）

## 方案选择

采用方案 A：单 `AnimationController` + 速度自适应 `animateTo`。

`AnimationController` 同时承担手势跟手（直接设 value）和动画过渡（animateTo）。

## 动画参数

| 场景 | 目标值 | Duration | Curve | 触发条件 |
|------|--------|----------|-------|----------|
| 松手弹到全开 | 1.0 | 200ms | `easeOut` | 松手时 progress ≥ 0.35 |
| 松手弹回收起 | 0.0 | 速度自适应 | `easeOut` | 松手时 progress < 0.35 |
| 点击模糊区关闭 | 0.0 | 220ms | `easeIn` | 点击右侧预览区域 |
| 设置/切Tab关闭 | 0.0 | 220ms | `easeIn` | 打开设置或切换底部Tab |

### 速度自适应 duration

```
remainingFraction = currentProgress
speed = abs(velocity) in progress-space
duration = max(120ms, min(220ms, remainingFraction / speed))
```

速度从最近几次 `PointerMoveEvent` 的 `delta.dx / drawerWidth` 和对应时间戳估算。

## 架构变更

### 改动范围

仅 `lib/app.dart` 中的 `_MainShellState`。

### 变更清单

1. **Mixin**：`_MainShellState` 加 `SingleTickerProviderStateMixin`
2. **成员**：删除 `double _drawerProgress`，新增 `late final AnimationController _drawerController`
3. **常量**：新增 `_snapDuration = 200ms`、`_tapCloseDuration = 220ms`
4. **`initState`**：创建 controller + listener 驱动 `setState`
5. **`_isDrawerOpen`**：改为 `_drawerController.value > 0.001`
6. **`_setDrawerProgress`**：先 `stop()` 再设 `value`
7. **关闭触发点**：`_closeDrawer()`、`_handleDrawerPreviewTap()`、`_openSettingsHub()`、`_onTabChanged()` 统一改为 `animateTo(0, ...)`
8. **松手逻辑**：新增 `_snapAfterRelease()` 替代原来直接 `setState` 到 0 或 1
9. **速度采集**：在 `_handleDrawerPointerMove` 中记录最近 movement 用于估算速度
10. **`_buildTransformedShell`**：所有 `_drawerProgress` → `_drawerController.value`
11. **`dispose`**：加 `_drawerController.dispose()`

### 手势中断

动画运行中用户再次触摸 → `_handleDrawerPointerDown` 触发 `_setDrawerProgress` → `stop()` 中断动画，立即切回跟手模式。

## 数据流

```
用户手势 → PointerEvent → _setDrawerProgress(v) → controller.value = v
                                     ↓ stop() 如有动画
松手 → _snapAfterRelease() → controller.animateTo(0 or 1)
点击模糊区 → controller.animateTo(0, 220ms, easeIn)
切换Tab/设置 → controller.animateTo(0, 220ms, easeIn)
                                     ↓
                        controller listener → setState → build
```

## 测试策略

- 现有 widget 测试应继续通过（动画不影响逻辑结果，只是过渡方式变化）
- 手动验证 4 个关闭路径的动画流畅度
- 验证手势中断：动画中触摸可立即接管

## 风险与边界

- `AnimationController` 需 `SingleTickerProviderStateMixin`，`_MainShellState` 当前未混入，加混入无副作用
- 速度估算依赖 PointerEvent 的 `delta` 和 `timeStamp`，精度足够判断手势意图
- `addListener` 中 `setState` 需 `mounted` 检查，避免 dispose 后调用
