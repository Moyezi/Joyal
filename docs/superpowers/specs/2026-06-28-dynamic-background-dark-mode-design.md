# DynamicAlbumBackground 深色模式初始背景

**日期:** 2026-06-28
**状态:** 设计中

## 问题

进入播放详情页（`NowPlayingScreen`）时，`DynamicAlbumBackground` 初始背景为硬编码白色 `#FFFFFF`，在深色模式下产生刺眼的白闪，随后才过渡到专辑取色结果。

## 根因

`lib/widgets/dynamic_album_background.dart` 第 28-29 行：

```dart
Color _top = AppTheme.background;    // 硬编码 #FFFFFF
Color _bottom = AppTheme.background; // 硬编码 #FFFFFF
```

`AppTheme.background` 是浅色主题常量，不随 `Theme.of(context).brightness` 变化。而 `AlbumVisualPalette.fallbackFor(Brightness.dark)` 已正确定义深色回退 `#121212`，只是 `DynamicAlbumBackground` 未使用。

## 方案

**方案 A：`didChangeDependencies` 上下文感知初始化**（选定）

### 改动文件

- `lib/widgets/dynamic_album_background.dart`

### 改动内容

1. `_top` / `_bottom` 移除硬编码初始值
2. 新增 `_paletteLoaded` 标记
3. 重写 `didChangeDependencies`：首次调用时从 `AlbumVisualPalette.fallbackFor(Theme.of(context).brightness)` 获取初始背景色
4. `_loadPalette` 成功后设置 `_paletteLoaded = true`，防止后续 `didChangeDependencies` 覆盖

### 数据流

```
didChangeDependencies (首次)
  → _paletteLoaded == false
  → fallbackFor(brightness) → 深色 #121212 / 浅色 #FFFFFF
  → _loadPalette() 异步取色
    → 成功 → setState({ _top, _bottom }) + _paletteLoaded = true
    → 失败 → 保持 fallback 值

后续主题切换:
  → didChangeDependencies 再次触发
  → _paletteLoaded == true → 跳过，保留专辑颜色
```

### 不变项

- `AlbumVisualPalette.fallbackFor(brightness)` — 已正确实现，无需修改
- `_syncVisualPalette`（`now_playing_screen.dart`）— 已使用 `fallbackFor`，无需修改
- 取色逻辑、动画时长（950ms）、渐变结构（3 锚点 LinearGradient）不变
- 路由过渡动画背景由 `theme.dart` 的 `scaffoldBackgroundColor` 控制，已区分深浅

## 验证

- 深色模式：进入播放页，初始背景为暗色 `#121212`，无白色闪现
- 浅色模式：行为不变，初始背景为白色 `#FFFFFF`
- 取色完成后：平滑过渡到专辑颜色（AnimatedContainer 950ms easeInOutCubic）
- 现有测试：`flutter test` 全量通过
