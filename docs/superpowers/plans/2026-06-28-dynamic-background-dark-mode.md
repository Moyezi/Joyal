# DynamicAlbumBackground 深色模式初始背景 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 `DynamicAlbumBackground` 在深色模式下初始背景闪现白色的问题，改为上下文感知的暗色回退。

**Architecture:** 单文件改动 — `DynamicAlbumBackground` 的 `_DynamicAlbumBackgroundState` 在 `didChangeDependencies` 中用 `AlbumVisualPalette.fallbackFor(brightness)` 设置初始 `_top`/`_bottom`，替代硬编码 `AppTheme.background`。

**Tech Stack:** Flutter / Dart，无新增依赖。

## Global Constraints

- 深色背景色：`#121212`（`AppTheme.darkBackground`）
- 所有 Widget 通过 `Theme.of(context)` 或 `ThemeContext` 获取颜色，禁止直接引用 `AppTheme.primaryText` 等静态常量
- 动画时长不变：AnimatedContainer 950ms easeInOutCubic
- MiniPlayer 始终 `#151922` 不参与主题

---

### Task 1: 修复 DynamicAlbumBackground 上下文感知初始化

**Files:**
- Modify: `lib/widgets/dynamic_album_background.dart:27-29`（字段初始化）
- Modify: `lib/widgets/dynamic_album_background.dart:30-33`（initState → didChangeDependencies）
- Modify: `lib/widgets/dynamic_album_background.dart:45-58`（_loadPalette 加标记）

**Interfaces:**
- Consumes: `AlbumVisualPalette.fallbackFor(Brightness)` — 已存在，签名 `static AlbumVisualPalette fallbackFor(Brightness brightness)`
- Produces: 无新增公开接口，`_DynamicAlbumBackgroundState` 内部行为变更

- [ ] **Step 1: 修改字段声明，移除硬编码初始化**

将第 27-29 行：
```dart
class _DynamicAlbumBackgroundState extends State<DynamicAlbumBackground> {
  Color _top = AppTheme.background;
  Color _bottom = AppTheme.background;
```

改为：
```dart
class _DynamicAlbumBackgroundState extends State<DynamicAlbumBackground> {
  late Color _top;
  late Color _bottom;
  bool _paletteLoaded = false;
```

- [ ] **Step 2: 替换 initState 为 didChangeDependencies**

删除 `initState` override，新增 `didChangeDependencies`：

```dart
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_paletteLoaded) {
      final fallback = AlbumVisualPalette.fallbackFor(
        Theme.of(context).brightness,
      );
      _top = fallback.top;
      _bottom = fallback.bottom;
      _loadPalette();
    }
  }
```

- [ ] **Step 3: _loadPalette 成功后设置 _paletteLoaded 标记**

在第 56 行 `setState(() {` 之前插入标记设置：

```dart
    if (!mounted || widget.coverArtId != requestedId) return;
    _paletteLoaded = true;
    setState(() {
      _top = palette.top;
      _bottom = palette.bottom;
    });
```

- [ ] **Step 4: 静态分析**

Run: `flutter analyze lib/widgets/dynamic_album_background.dart`
Expected: No issues found.

- [ ] **Step 5: 运行现有测试**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/dynamic_album_background.dart
git commit -m "fix: DynamicAlbumBackground uses dark fallback in dark mode"
```

---

### Task 2: 构建验证

**Files:**
- None (构建产物)

- [ ] **Step 1: 构建 arm64 Release APK**

Run: `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`
Expected: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` 生成成功。

- [ ] **Step 2: 人工验证**

在深色模式下进入播放详情页，确认初始背景为暗色（非白色），随后平滑过渡到专辑取色。
