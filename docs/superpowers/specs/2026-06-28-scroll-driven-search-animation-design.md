# Scroll-Driven Search Bar ↔ Top Bar Animation — Design Spec

**Date:** 2026-06-28  
**Status:** Approved  
**Project:** Joyal Music

---

## 1. 需求概述

首页初始有一个大搜索框（`_HomeSearchBar`，高度 54px）。当用户向下滚动页面时：

- **大搜索框**：逐渐向上位移（translateY）、缩小（scale）、变透明（opacity），直至完全不可见且不可点击
- **顶栏搜索图标**：在完全相同滚动区间内，从缩小/透明状态放大到正常大小并完全显示

向上回滚时效果完全可逆。不使用 CSS 类名切换，而是根据滚动进度（0→1）实时 `lerp` 插值。

### 约束

- 问候语（顶栏左侧）完全不动
- 搜索图标放在顶栏右侧
- 滚动区间 = 搜索框自身可见范围（搜索框高度 54px + 上方 padding 16px = 70px）
- 必须保证性能，不造成整页重建

---

## 2. 方案：`ScrollController` + `AnimationController`

### 2.1 架构

```
HomeScreen (_HomeScreenState)
├── AnimationController _animController  (duration: Duration.zero, vsync: this)
│     ├── 由 ScrollController.listener 手动 setValue(progress)
│     └── 被两处 AnimatedBuilder 订阅
│
├── ScrollController _scrollController
│     └── _onScroll(): progress = clamp(scrollOffset / 70, 0, 1)
│           → _animController.value = progress
│
├── GlassTopBar(searchAnimation: _animController, onSearchTap: _openSearch)
│     └── 右侧: AnimatedBuilder → 搜索图标 IconButton
│           ├── scale: lerp(0.6, 1.0, progress)
│           ├── opacity: lerp(0.0, 1.0, progress)
│           └── onPressed: onSearchTap (→ Navigator.push SearchScreen)
│
└── CustomScrollView(controller: _scrollController)
      └── AnimatedBuilder → 大搜索框
            ├── translateY: lerp(0, -20, progress)
            ├── scale: lerp(1.0, 0.85, progress)
            ├── opacity: lerp(1.0, 0.0, progress)
            └── IgnorePointer: progress == 1.0
```

### 2.2 滚动进度公式

```dart
static const double _searchBarHeight = 54.0;
static const double _searchBarTopPadding = 16.0;
static const double _totalRange = _searchBarHeight + _searchBarTopPadding; // 70px

void _onScroll() {
  if (!_scrollController.hasClients) return;
  final offset = _scrollController.offset;
  final progress = (offset / _totalRange).clamp(0.0, 1.0);
  _animController.value = progress;
}
```

### 2.3 大搜索框动画参数

| 属性 | progress=0 | progress=1 | 实现 |
|------|-----------|-----------|------|
| translateY | 0 | -20px | `Transform.translate(offset: Offset(0, lerp(0, -20, p)))` |
| scale | 1.0 | 0.85 | `Transform.scale(scale: lerp(1.0, 0.85, p))` |
| opacity | 1.0 | 0.0 | `Opacity(opacity: 1.0 - p)` |
| 交互 | 可点击 | 禁用 | `IgnorePointer(ignoring: p == 1.0)` |

- 大搜索框初始位于 `SliverToBoxAdapter` 中 `_buildSearch()`
- 用 `AnimatedBuilder(animation: _animController, builder: ...)` 包裹
- 搜索框 `onTap` 跳转 `SearchScreen` 逻辑不变

### 2.4 顶栏搜索图标动画参数

| 属性 | progress=0 | progress=1 | 实现 |
|------|-----------|-----------|------|
| scale | 0.6 | 1.0 | `Transform.scale(scale: lerp(0.6, 1.0, p))` |
| opacity | 0.0 | 1.0 | `Opacity(opacity: p)` |
| 交互 | 自然不可点击 | 可点击跳转搜索 | `onPressed: () => Navigator.push(...)` |

- 图标初始状态（progress=0）：缩小到 60% 且完全透明，视觉上不可见
- 图标完全显示后点击跳转 `SearchScreen`

---

## 3. 文件改动

### 3.1 `lib/screens/home_screen.dart`（主要改动）

**新增成员（`_HomeScreenState`）：**

```dart
late final AnimationController _animController;
late final ScrollController _scrollController;

static const double _searchBarHeight = 54.0;
static const double _searchBarTopPadding = 16.0;
static const double _totalRange = _searchBarHeight + _searchBarTopPadding;
```

**生命周期：**

```dart
@override
void initState() {
  super.initState();
  _animController = AnimationController(
    duration: Duration.zero,
    vsync: this,
  );
  _scrollController = ScrollController();
  _scrollController.addListener(_onScroll);
}

@override
void dispose() {
  _scrollController.removeListener(_onScroll);
  _scrollController.dispose();
  _animController.dispose();
  super.dispose();
}
```

**GlassTopBar 调用变更：**

```dart
// 原: GlassTopBar(height: _headerHeight, child: _buildHeader()),
// 改为:
GlassTopBar(
  height: _headerHeight,
  child: _buildHeader(),
  searchAnimation: _animController,
  onSearchTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SearchScreen()),
  ),
),
```

**`_buildSearch()` 变更：** 用 `AnimatedBuilder` 包裹，对搜索框做 transform + opacity 插值。

**`_buildBody()` 变更：** `CustomScrollView` 绑定 `_scrollController`。

### 3.2 `lib/widgets/glass_top_bar.dart`（小改）

**新增可选参数和搜索图标渲染：**

```dart
class GlassTopBar extends StatelessWidget {
  final double height;
  final Widget child;
  final Animation<double>? searchAnimation;
  final VoidCallback? onSearchTap;  // 新增：搜索图标点击回调

  const GlassTopBar({
    super.key,
    required this.height,
    required this.child,
    this.searchAnimation,
    this.onSearchTap,
  });
}
```

- 当 `searchAnimation != null` 时，在现有 `Stack` 的 `child` 层之上叠加一个右侧搜索图标
- 搜索图标通过 `Positioned`（或 `Row` + `Align`）放在顶栏右侧区域，与左侧 `child`（问候语）不冲突
- 图标使用 `IconButton(icon: Icon(Icons.search_rounded), onPressed: onSearchTap)` 并由 `AnimatedBuilder` 包裹做 scale + opacity 插值
- `onSearchTap` 由调用方（HomeScreen）传入 `() => Navigator.push(SearchScreen)`，避免 GlassTopBar 直接依赖 SearchScreen
- `LibraryScreen` / `HotlistScreen` 不传 `searchAnimation` 和 `onSearchTap`，行为不变

### 3.3 不改动的文件

- `lib/app.dart` — 不变
- `lib/screens/search_screen.dart` — 不变
- `lib/screens/library_screen.dart` — 不变（不传 searchAnimation）
- `lib/screens/hotlist_screen.dart` — 不变（不传 searchAnimation）
- 专辑网格、最近添加卡片等 — 零改动

---

## 4. 性能保障

- `AnimationController` 不需要 `Ticker` 持续运行：只在 `_onScroll` 中 `setValue`，无额外帧开销
- `AnimatedBuilder` 仅重建 `Transform` + `Opacity` 组合子树，不触发整页 layout
- `lerp` / `clamp` 为纯数学运算，无副作用
- `_onScroll` 只做一次浮点运算 + `setValue`，无 I/O、无 setState
- `CustomScrollView` 的 Sliver 懒加载不受影响

---

## 5. 测试要点

| 测试场景 | 预期行为 |
|---------|---------|
| 页面初始加载 | 大搜索框完全可见（progress=0），顶栏无搜索图标 |
| 向下滚动至搜索框刚好消失 | 大搜索框完全透明 + IgnorePointer，顶栏图标完全显示 |
| 继续向下滚动（超过 70px） | progress 保持 1.0，状态不变 |
| 向上回滚 | 动画完全可逆，搜索框淡入，图标淡出 |
| 快速快速滚动（惯性） | 动画平滑跟随，无跳帧 |
| 搜索框不可见时点击其位置 | 无反应（IgnorePointer） |
| 顶栏图标可见时点击 | 跳转 SearchScreen |
| 曲库/收藏页 | GlassTopBar 无 searchAnimation，无搜索图标，行为不变 |

---

## 6. 构建验证

```bash
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```
