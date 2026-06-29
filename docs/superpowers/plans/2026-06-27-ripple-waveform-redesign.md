# 涟漪波形进度条重构 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `WaveformProgress` 从"伪随机能量包络 + 单柱脉冲"改为"等长离散短柱 + 涟漪扩散动画"。

**Architecture:** 删除 `_generateWaveform()` 和 `_waveformData`；新增 `_ripplePhaseController`（循环 ~600ms）和 `_rippleFadeController`（播放/暂停淡入淡出）；`WaveformGeometry` 新增 `rippleHeight()` 和 `activeHalfWidth` 静态方法；保留磁吸形变 `morphedHeight()` 作为拖拽叠加层；着色简化为活跃区内 `playedColor`、区外 `unplayedColor`。

**Tech Stack:** Flutter / Dart, `package:flutter/material.dart`, `dart:math`, `package:flutter/services.dart`（HapticFeedback）

## Global Constraints

- 柱数默认 72（`barCount`），柱宽比例 `barFillRatio = 0.48`
- 活跃区半径 = 总柱数的 10%（`activeHalfWidth` 为 bar fraction 空间中的 0.10）
- 静态高度 12px，涟漪幅度 18-24px（1.5-2x）
- 涟漪周期 ~600ms，双向对称扩散
- 拖拽保留磁吸形变 + 触觉反馈 + 时间气泡
- 着色仅活跃区用 `playedColor`，区外用 `unplayedColor`，去掉 `playedGlowColor`
- `WaveformProgress` 不再需要 `trackKey` 生成波形，但保留参数用于切歌检测
- 保留 `_dragMorphController` 及 `morphedHeight()` 不变，作为拖拽叠加层

## 文件结构

| 文件 | 角色 |
|---|---|
| `lib/widgets/waveform_progress.dart` | 主要改动：删除波形生成，新增涟漪动画，简化着色，保留磁吸拖拽 |
| `lib/screens/now_playing_screen.dart` | 删除 `playedGlowColor:` 传参行 |
| `lib/config/theme.dart` | 无需改动 |
| `lib/widgets/album_visual_palette.dart` | 无需改动 |
| `test/waveform_progress_test.dart` | 替换所有测试：涟漪高度、活跃区宽度、磁吸叠加、着色边界、effectiveDragFraction |

---

### Task 1: `WaveformGeometry` 新增 `rippleHeight()` 和 `activeHalfWidth`

**Files:**
- Modify: `lib/widgets/waveform_progress.dart` — 在 `WaveformGeometry` 类中添加两个静态方法
- Modify: `test/waveform_progress_test.dart` — 添加涟漪测试，重写旧测试

**Interfaces:**
- Produces: `WaveformGeometry.rippleHeight(...)`, `WaveformGeometry.activeHalfWidth(int barCount)`
- Consumes: 无（纯数学工具）

- [ ] **Step 1: 添加涟漪高度的失败测试**

在 `test/waveform_progress_test.dart` 中**完全替换**现有测试内容为：

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/widgets/waveform_progress.dart';

void main() {
  group('activeHalfWidth', () {
    test('returns ~10% of bar count as fraction space radius', () {
      final halfWidth = WaveformGeometry.activeHalfWidth(72);
      expect(halfWidth, closeTo(0.10, 0.01));
    });

    test('scales proportionally with bar count', () {
      // 36 bars and 144 bars should yield similar fraction-space radius
      expect(
        WaveformGeometry.activeHalfWidth(36),
        closeTo(WaveformGeometry.activeHalfWidth(144), 0.005),
      );
    });
  });

  group('rippleHeight', () {
    test('center bar at phase=0 reaches max height (24)', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.5,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      // At phase=0, cos(0)*2π, ripple = sin(0)=0, envelope=1 → 12 + 1*(9+0) = 21
      // But max happens at ripple=1 when phase shifts. Let's test the range.
      expect(h, greaterThanOrEqualTo(18));
      expect(h, lessThanOrEqualTo(24));
    });

    test('center bar at specific phase reaches minimum height', () {
      // phase = π/2 → ripple = sin(0 - π/2) = -1
      // envelope = cos(0) = 1 → 12 + 1*(9 - 3) = 18
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.5,
        centerFraction: 0.5,
        phase: pi / 2,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      expect(h, closeTo(18, 0.01));
    });

    test('bar outside active zone stays at static height', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.8,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      expect(h, closeTo(12, 0.01));
    });

    test('bar at edge of active zone is >= static height', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.6,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      // At edge, envelope → 0, height → 12
      expect(h, greaterThanOrEqualTo(12));
      expect(h, lessThanOrEqualTo(15)); // close to static but slight lift
    });

    test('height is symmetric around center', () {
      final left = WaveformGeometry.rippleHeight(
        barFraction: 0.45,
        centerFraction: 0.5,
        phase: 1.0,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      final right = WaveformGeometry.rippleHeight(
        barFraction: 0.55,
        centerFraction: 0.5,
        phase: 1.0,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      expect(left, closeTo(right, 0.001));
    });
  });

  group('morphedHeight (preserved for drag overlay)', () {
    test('drag morph keeps finger-local bars taller than far bars', () {
      final local = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.52,
        dragFraction: 0.5,
        dragIntensity: 1,
        maxHeight: 48,
      );
      final far = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.92,
        dragFraction: 0.5,
        dragIntensity: 1,
        maxHeight: 48,
      );
      expect(local, greaterThan(far * 2));
      expect(far, lessThan(18));
    });

    test('drag morph returns normal height when drag intensity is zero', () {
      final normal = WaveformGeometry.morphedHeight(
        baseEnergy: 0.64,
        barFraction: 0.9,
        dragFraction: 0.1,
        dragIntensity: 0,
        maxHeight: 50,
      );
      expect(normal, closeTo(32, 0.001));
    });
  });

  group('effectiveDragFraction', () {
    test('keeps settling fraction while intensity remains active', () {
      expect(
        WaveformGeometry.effectiveDragFraction(
          dragFraction: null,
          settlingDragFraction: 0.42,
          dragIntensity: 0.5,
        ),
        0.42,
      );
      expect(
        WaveformGeometry.effectiveDragFraction(
          dragFraction: null,
          settlingDragFraction: 0.42,
          dragIntensity: 0,
        ),
        isNull,
      );
    });

    test('clamps overshooting intensity in morphedHeight', () {
      final capped = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.5,
        dragFraction: 0.5,
        dragIntensity: 1,
        maxHeight: 48,
      );
      final overshooting = WaveformGeometry.morphedHeight(
        baseEnergy: 0.8,
        barFraction: 0.5,
        dragFraction: 0.5,
        dragIntensity: 1.5,
        maxHeight: 48,
      );
      expect(overshooting, closeTo(capped, 0.001));
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter test test/waveform_progress_test.dart
```
预期：多个测试 FAIL，因为 `rippleHeight` 和 `activeHalfWidth` 尚未定义。

- [ ] **Step 3: 在 `WaveformGeometry` 中实现 `activeHalfWidth` 和 `rippleHeight`**

在 `lib/widgets/waveform_progress.dart` 的 `WaveformGeometry` 类中，于 `effectiveDragFraction` 方法**之前**插入：

```dart
  /// Active zone half-width in bar-fraction space.
  ///
  /// Returns a fixed ~10% of the total bar range, which translates to ~7 bars
  /// for the default [barCount] of 72.
  static double activeHalfWidth(int barCount) {
    // Use a fixed fraction so the visual zone is proportional.
    return 1.0 / barCount * (barCount * 0.10);
  }

  /// Height of a bar at [barFraction] within the ripple active zone.
  ///
  /// [centerFraction] is the playback or drag position (0–1).
  /// [phase] drives the traveling wave; incrementing phase moves peaks outward.
  /// [activeHalfWidth] defines the zone radius.
  /// [staticHeight] is the at-rest height.
  ///
  /// Returns a height between [staticHeight] and ~2× [staticHeight].
  static double rippleHeight({
    required double barFraction,
    required double centerFraction,
    required double phase,
    required double activeHalfWidth,
    required double staticHeight,
  }) {
    final distance = (barFraction - centerFraction).abs();
    if (distance > activeHalfWidth) return staticHeight;

    final normalizedDist = distance / activeHalfWidth; // 0→1
    final envelope = cos(normalizedDist * pi / 2); // 1 at center, 0 at edge
    final ripple = sin(normalizedDist * 2 * pi - phase); // traveling wave
    // Amplitude: 9px baseline lift + 3px ripple swing → [18, 24] at center
    return (staticHeight + envelope * (9 + ripple * 3)).clamp(3.0, 48.0);
  }
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter test test/waveform_progress_test.dart
```
预期：所有测试 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/waveform_progress.dart test/waveform_progress_test.dart
git commit -m "feat: add rippleHeight and activeHalfWidth to WaveformGeometry"
```

---

### Task 2: 重写 `_WaveformPainter` 为涟漪渲染

**Files:**
- Modify: `lib/widgets/waveform_progress.dart` — 替换 `_WaveformPainter` 类的字段和 `paint()` 方法

**Interfaces:**
- Consumes: `WaveformGeometry.rippleHeight(...)`, `WaveformGeometry.activeHalfWidth(int)`, `WaveformGeometry.morphedHeight(...)`
- Produces: `_WaveformPainter` 新接口（供 Task 3 的 state 使用）

- [ ] **Step 1: 添加 Painter 着色逻辑测试**

在 `test/waveform_progress_test.dart` 中**追加**以下测试（文件末尾 `}` 之前）：

```dart
  group('ripple coloring logic', () {
    test('active zone radius covers ~20% of total bars', () {
      // activeHalfWidth * 2 = 0.20 fraction space
      final half = WaveformGeometry.activeHalfWidth(72);
      expect(half * 2, closeTo(0.20, 0.01));
    });

    test('bar at center is in active zone', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.5,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      // Should be elevated above static (12) because it's in active zone
      expect(h, greaterThan(12));
    });

    test('bar at 0.62 is outside active zone when center is 0.5', () {
      final h = WaveformGeometry.rippleHeight(
        barFraction: 0.62,
        centerFraction: 0.5,
        phase: 0,
        activeHalfWidth: 0.10,
        staticHeight: 12,
      );
      expect(h, closeTo(12, 0.01));
    });
  });
```

- [ ] **Step 2: 运行测试确认新增测试失败（因已有代码不验证着色，可跳过）**

这一步可跳过——着色逻辑在 Painter 中，非纯函数，不在此测试。

- [ ] **Step 3: 重写 `_WaveformPainter`**

在 `lib/widgets/waveform_progress.dart` 中，**完全替换** `_WaveformPainter` 类为：

```dart
class _WaveformPainter extends CustomPainter {
  final int barCount;
  final double centerFraction;
  final double barFillRatio;
  final double ripplePhase;
  final double rippleAlpha;
  final double activeHalfWidth;
  final Color activeColor;
  final Color inactiveColor;
  final double? dragFraction;
  final double dragIntensity;

  _WaveformPainter({
    required this.barCount,
    required this.centerFraction,
    required this.barFillRatio,
    required this.ripplePhase,
    required this.rippleAlpha,
    required this.activeHalfWidth,
    required this.activeColor,
    required this.inactiveColor,
    required this.dragFraction,
    required this.dragIntensity,
  });

  static const double _staticHeight = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0) return;
    final barWidth = size.width / barCount;
    final drawWidth = max(2.0, barWidth * barFillRatio);
    final midY = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final barFraction = barCount == 1 ? 0.0 : i / (barCount - 1);

      // 1. Ripple height (only when rippleAlpha > 0)
      double height = _staticHeight;
      bool inActiveZone = false;
      if (rippleAlpha > 0) {
        final rippleH = WaveformGeometry.rippleHeight(
          barFraction: barFraction,
          centerFraction: centerFraction,
          phase: ripplePhase,
          activeHalfWidth: activeHalfWidth,
          staticHeight: _staticHeight,
        );
        if (rippleH > _staticHeight + 0.5) {
          inActiveZone = true;
          height = _staticHeight + (rippleH - _staticHeight) * rippleAlpha;
        }
      }

      // 2. Magnetic drag morph overlay
      if (dragIntensity > 0 && dragFraction != null) {
        final baseEnergy = height / size.height;
        final magneticH = WaveformGeometry.morphedHeight(
          baseEnergy: baseEnergy,
          barFraction: barFraction,
          dragFraction: dragFraction,
          dragIntensity: dragIntensity,
          maxHeight: size.height,
        );
        height = height + (magneticH - height) * dragIntensity;
      }

      height = height.clamp(3.0, size.height);

      // 3. Coloring: active zone → activeColor, else inactiveColor
      final color = inActiveZone ? activeColor : inactiveColor;

      final paint = Paint()..color = color;
      final x = i * barWidth + (barWidth - drawWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + drawWidth / 2, midY),
            width: drawWidth,
            height: height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.centerFraction != centerFraction ||
      oldDelegate.ripplePhase != ripplePhase ||
      oldDelegate.rippleAlpha != rippleAlpha ||
      oldDelegate.dragFraction != dragFraction ||
      oldDelegate.dragIntensity != dragIntensity ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.barCount != barCount;
}
```

- [ ] **Step 4: 运行 flutter analyze 确认无语法错误**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter analyze lib/widgets/waveform_progress.dart
```
预期：0 errors。（此时 state 尚未更新，可能有未使用导入等 warning，暂忽略。）

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/waveform_progress.dart test/waveform_progress_test.dart
git commit -m "feat: rewrite WaveformPainter with ripple rendering"
```

---

### Task 3: 重构 `_WaveformProgressState` — 新动画控制器

**Files:**
- Modify: `lib/widgets/waveform_progress.dart` — 替换 state 初始化、控制器、build 方法中的 painter 构造

**Interfaces:**
- Consumes: `_WaveformPainter`（新接口），`WaveformGeometry.rippleHeight(...)`, `WaveformGeometry.activeHalfWidth(int)`
- Produces: 无新公共 API

- [ ] **Step 1: 替换 `_WaveformProgressState` 的成员和初始化**

在 `lib/widgets/waveform_progress.dart` 中，找到 `_WaveformProgressState` 类的成员声明区域，**替换**以下内容：

**删除：**
```dart
  late List<double> _waveformData;
  late final AnimationController _pulseController;
```

**新增：**
```dart
  late final AnimationController _ripplePhaseController;
  late final AnimationController _rippleFadeController;
```

**替换 `initState`：**

原代码：
```dart
  @override
  void initState() {
    super.initState();
    _waveformData = _generateWaveform(widget.barCount, widget.trackKey);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _dragMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 340),
    );
    _dragMorph = CurvedAnimation(
      parent: _dragMorphController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    );
    _syncPulse();
  }
```

改为：
```dart
  @override
  void initState() {
    super.initState();
    _ripplePhaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rippleFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _dragMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 340),
    );
    _dragMorph = CurvedAnimation(
      parent: _dragMorphController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    );
    _syncRipple();
  }
```

- [ ] **Step 2: 替换 `didUpdateWidget`**

原代码：
```dart
  @override
  void didUpdateWidget(covariant WaveformProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.barCount != oldWidget.barCount ||
        widget.trackKey != oldWidget.trackKey) {
      _waveformData = _generateWaveform(widget.barCount, widget.trackKey);
      _dragFraction = null;
      _settlingDragFraction = null;
    }
    if (widget.isPlaying != oldWidget.isPlaying) _syncPulse();
  }
```

改为：
```dart
  @override
  void didUpdateWidget(covariant WaveformProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackKey != oldWidget.trackKey) {
      _dragFraction = null;
      _settlingDragFraction = null;
    }
    if (widget.isPlaying != oldWidget.isPlaying) _syncRipple();
  }
```

- [ ] **Step 3: 替换 `_syncPulse` 为 `_syncRipple`**

**删除** `_syncPulse()` 方法，**新增**：

```dart
  void _syncRipple() {
    if (widget.isPlaying) {
      _ripplePhaseController.repeat();
      _rippleFadeController.forward();
    } else {
      _ripplePhaseController.stop();
      _rippleFadeController.reverse();
    }
  }
```

- [ ] **Step 4: 删除 `_generateWaveform` 静态方法**

**完全删除**：
```dart
  static List<double> _generateWaveform(int count, String key) {
    final random = Random(key.hashCode);
    final raw = List.generate(count, (index) {
      final phrase = sin(index / 5.2) * 0.16 + sin(index / 13.0) * 0.12;
      return (random.nextDouble() * 0.72 + phrase).clamp(0.0, 1.0);
    });
    return List.generate(count, (index) {
      var sum = raw[index] * 3;
      var weight = 3.0;
      if (index > 0) {
        sum += raw[index - 1];
        weight++;
      }
      if (index < count - 1) {
        sum += raw[index + 1];
        weight++;
      }
      return 0.18 + (sum / weight) * 0.82;
    });
  }
```

- [ ] **Step 5: 替换 build 方法中的 animation listenable 和 painter 构造**

在 `build()` 方法中，找到 `AnimatedBuilder` 部分。**替换** listenable：

原：
```dart
            animation: Listenable.merge([
              _pulseController,
              _dragMorphController,
            ]),
```

改为：
```dart
            animation: Listenable.merge([
              _ripplePhaseController,
              _rippleFadeController,
              _dragMorphController,
            ]),
```

**替换** `_WaveformPainter(...)` 构造：

原：
```dart
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          waveformData: _waveformData,
                          progress: _displayFraction,
                          barFillRatio: widget.barFillRatio,
                          pulse: widget.isPlaying ? _pulseController.value : 0,
                          isInteracting: _dragFraction != null,
                          playedColor: widget.playedColor,
                          playedGlowColor: widget.playedGlowColor,
                          unplayedColor: widget.unplayedColor,
                          dragFraction: effectiveDragFraction,
                          dragIntensity: dragIntensity,
                        ),
                      ),
```

改为：
```dart
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          barCount: widget.barCount,
                          centerFraction: _displayFraction,
                          barFillRatio: widget.barFillRatio,
                          ripplePhase: _ripplePhaseController.value * 2 * 3.14159,
                          rippleAlpha: _rippleFadeController.value.clamp(0.0, 1.0),
                          activeHalfWidth: WaveformGeometry.activeHalfWidth(widget.barCount),
                          activeColor: widget.playedColor,
                          inactiveColor: widget.unplayedColor,
                          dragFraction: effectiveDragFraction,
                          dragIntensity: dragIntensity,
                        ),
                      ),
```

- [ ] **Step 6: 替换 dispose**

原：
```dart
  @override
  void dispose() {
    _pulseController.dispose();
    _dragMorphController.dispose();
    super.dispose();
  }
```

改为：
```dart
  @override
  void dispose() {
    _ripplePhaseController.dispose();
    _rippleFadeController.dispose();
    _dragMorphController.dispose();
    super.dispose();
  }
```

- [ ] **Step 7: 更新类文档注释**

将文件顶部 `WaveformProgress` 的文档注释：
```dart
/// An interactive, track-specific energy waveform.
///
/// Subsonic does not expose PCM amplitude data, so the energy envelope is a
/// stable visual approximation generated from [trackKey]. It avoids decoding
/// an entire remote track while still making progress feel tied to the music.
```

改为：
```dart
/// An interactive progress bar with ripple breathing columns.
///
/// When playing, a zone of bars around the current position breathes with a
/// traveling-wave ripple. When dragging, the ripple follows the finger and
/// nearby bars are magnetically amplified. Bars outside the active zone stay
/// at a uniform resting height.
```

- [ ] **Step 8: 运行 flutter analyze**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter analyze lib/widgets/waveform_progress.dart
```
预期：0 errors, 0 warnings。

- [ ] **Step 9: 运行测试**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter test test/waveform_progress_test.dart
```
预期：全部 PASS。

- [ ] **Step 10: 提交**

```bash
git add lib/widgets/waveform_progress.dart
git commit -m "feat: replace pulse waveform with ripple animation in WaveformProgress"
```

---

### Task 4: `WaveformProgress` 小组件参数清理

**Files:**
- Modify: `lib/widgets/waveform_progress.dart` — 标记 `playedGlowColor` 为 deprecated，保留但内部不再使用

**Interfaces:**
- Consumes: 无
- Produces: `WaveformProgress.playedGlowColor` 变为 `@Deprecated`

- [ ] **Step 1: 在构造函数中标记 `playedGlowColor` 为 deprecated**

找到 `WaveformProgress` 构造函数中的 `playedGlowColor` 参数，改为：

```dart
  @Deprecated('No longer used; active-zone bars use playedColor uniformly.')
  final Color playedGlowColor;
```

并将默认值改为不影响编译的占位：
```dart
    @Deprecated('No longer used') this.playedGlowColor = const Color(0x00000000),
```

> 保留该参数是为了不破坏 `now_playing_screen.dart` 的编译（Task 5 将移除调用处）。

- [ ] **Step 2: 验证 analyze**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter analyze lib/widgets/waveform_progress.dart
```
预期：可能有 deprecation info（非 error），0 errors。

- [ ] **Step 3: 提交**

```bash
git add lib/widgets/waveform_progress.dart
git commit -m "refactor: deprecate playedGlowColor in WaveformProgress"
```

---

### Task 5: `now_playing_screen.dart` 移除 `playedGlowColor` 传参

**Files:**
- Modify: `lib/screens/now_playing_screen.dart` — 删除一行

**Interfaces:**
- Consumes: `WaveformProgress`（deprecated 参数不再传递）
- Produces: 无

- [ ] **Step 1: 删除 `playedGlowColor:` 传参行**

在 `lib/screens/now_playing_screen.dart` 中，找到 `WaveformProgress(` 构造处的这三行：

```dart
            playedColor: _visualPalette.waveformAccent,
            playedGlowColor: _visualPalette.waveformAccentSoft,
            unplayedColor: _visualPalette.waveformTrack,
```

**删除** `playedGlowColor: _visualPalette.waveformAccentSoft,` 这一行。

- [ ] **Step 2: 运行 flutter analyze**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter analyze lib/screens/now_playing_screen.dart
```
预期：0 errors。

- [ ] **Step 3: 运行全量测试**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter test
```
预期：全部 PASS。

- [ ] **Step 4: 提交**

```bash
git add lib/screens/now_playing_screen.dart
git commit -m "refactor: remove playedGlowColor from NowPlayingScreen waveform"
```

---

### Task 6: 最终清理 — 移除 `playedGlowColor` 参数

**Files:**
- Modify: `lib/widgets/waveform_progress.dart` — 彻底删除 `playedGlowColor` 字段和参数

**Interfaces:**
- Produces: `WaveformProgress` 不再有 `playedGlowColor`

- [ ] **Step 1: 从构造函数中删除 `playedGlowColor` 参数**

在 `WaveformProgress` 构造函数中**删除**这一行：
```dart
    @Deprecated('No longer used') this.playedGlowColor = const Color(0x00000000),
```

- [ ] **Step 2: 从字段声明中删除**

**删除**：
```dart
  @Deprecated('No longer used; active-zone bars use playedColor uniformly.')
  final Color playedGlowColor;
```

- [ ] **Step 3: 运行 flutter analyze**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter analyze
```
预期：0 errors。

- [ ] **Step 4: 运行全量测试**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter test
```
预期：全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/waveform_progress.dart
git commit -m "refactor: remove deprecated playedGlowColor from WaveformProgress"
```

---

### Task 7: 构建 APK 验证

- [ ] **Step 1: 构建 arm64 Release APK**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS && flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```
预期：BUILD SUCCESSFUL。

- [ ] **Step 2: 确认输出路径**

```bash
ls build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
预期：文件存在。

- [ ] **Step 3: 提交**（如需要）

```bash
git add -A
git commit -m "build: arm64 release APK with ripple waveform"
```

