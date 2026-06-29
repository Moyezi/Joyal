# Song Cover Picker — 长按封面选曲

**日期**: 2026-06-28  
**状态**: 设计完成，待实现

---

## 概述

在 Now Playing 页面，用户长按专辑封面进入选曲模式：当前封面缩小但仍最大，上一首和下一首封面在左右淡入。左右滑动在播放队列中导航，每次切歌有振动反馈。点击封面播放该曲并退出选曲，点击空白取消。

---

## 架构

### 文件变更

| 文件 | 变更 | 说明 |
|------|------|------|
| `lib/widgets/song_cover_picker.dart` | **新建** | 选曲浮层组件，自包含动画与手势 |
| `lib/screens/now_playing_screen.dart` | 修改 | 集成浮层，新增 `_isSelecting`、`_candidateIndex`，信息区跟随候选 |

`AlbumCover`、`player_provider.dart`、播放控件等其他文件**不动**。

### 组件树（选曲模式）

```
NowPlayingScreen
├── DynamicAlbumBackground (叠加 BackdropFilter sigma 3 模糊)
├── Stack
│   ├── 原 playerPage
│   │   ├── 封面区 (被浮层覆盖)
│   │   ├── 信息区 (标题/艺人跟随 _candidateIndex)
│   │   ├── 波形进度条 (保持当前播放位置不变)
│   │   └── 控件行 (Opacity 0.3 + IgnorePointer)
│   └── SongCoverPicker (浮层，HitTestBehavior.opaque)
│       ├── 左侧候选 AlbumCover (scale ~0.5, opacity 0.7)
│       ├── 中央候选 AlbumCover (scale ~0.7)
│       └── 右侧候选 AlbumCover (scale ~0.5, opacity 0.7)
└── (歌词页不受影响)
```

### 数据流

```
PlayerNotifier.playlist + currentIndex
        │
        ▼
NowPlayingScreen._candidateIndex  (选曲时独立跟踪)
        │
        ├── SongCoverPicker  决定三封面显示
        ├── 信息区            更新标题/艺人
        └── 确认选歌 → playerProvider.notifier.playAtIndex(candidateIndex)
```

---

## 交互设计

### 状态机

```
普通播放 ──(长按封面 500ms + heavyImpact)──▶ 选曲中
    ▲                                            │
    │              (点击候选封面)                    │
    └──────────────────────────────────────────────┘
    ▲
    │              (点击空白取消)
    └──────────────────────────────────────────────┘
```

### 手势详情

- **长按进入**：`onLongPressStart`，阈值 500ms，`HapticFeedback.heavyImpact()`。`_candidateIndex = currentIndex`，`_isSelecting = true`。
- **水平滑动**：`onHorizontalDragEnd` 判断条件：velocity 绝对值 > 300 px/s，或累积位移超过中央候选封面宽度的 30%。满足任一条件则 `_candidateIndex ± 1` + `HapticFeedback.selectionClick()`；否则动画回弹原位。
- **点击候选封面**：调用 `playAtIndex(candidateIndex)` → 退出选曲。
- **点击空白**：退出选曲，不改变播放。
- **边界行为**：`candidateIndex == 0` 时左侧无封面；`candidateIndex == last` 时右侧无封面。滑动有弹簧阻尼但不切换。
- **与歌词滑动互斥**：歌词滑动的 `onHorizontalDragStart` 检查 `_isSelecting`，为 true 则 return。

---

## 视觉规格

### 封面布局

```
         ┌──────────────────────────────┐
         │      BackdropFilter sigma 3   │
         │      + 半透明深色遮罩 0.08      │
         │                               │
         │   ┌─┐      ┌─────┐      ┌─┐  │
         │   │左│      │ 中  │      │右│  │
         │   │  │      │     │      │  │  │
         │   └─┘      └─────┘      └─┘  │
         │  scale 0.5  scale 0.7   scale 0.5
         │  opacity 0.7             opacity 0.7
         │  外侧被屏幕截断 ~1/3
         │                               │
         ├───────────────────────────────┤
         │  标题 (跟随候选)  ·  艺人       │
         │  ═══════ 波形进度 (不变) ══════  │
         │  ▶▶  ⏯  ▶▶  (半透明/禁用)      │
         └───────────────────────────────┘
```

### 尺寸（以原始封面尺寸为基准）

| 元素 | 比例 | 说明 |
|------|:----:|------|
| 中央候选 | ~0.70× | 缩小但视觉主导 |
| 左右候选 | ~0.50× | 约 2/3 可见，通过水平偏移使外侧超出屏幕边缘裁剪 |
| 左右水平偏移 | ±0.57× 中央宽度 | 内侧边缘与中央保持间距；外侧 1/3 被屏幕边缘自然截断 |
| 左右垂直偏移 | +8dp | 轻微下沉 |
| 左右透明度 | 0.7 | 视线聚焦中央 |

### 动画参数

| 动画 | 时长 | 曲线 | 说明 |
|------|:----:|------|------|
| 进入选曲（缩小 + 侧封淡入） | 350ms | `easeOutCubic` | 同步 |
| 滑动后复位 | 300ms | `Cubic(0.25, 1.55, 0.5, 1)` | easeOutBack 轻量版，5% overshoot 带阻尼 |
| 选歌确认（放大恢复） | 300ms | `easeOutCubic` | 侧封淡出 |
| 取消退出 | 250ms | `easeInCubic` | 快速收起 |
| 背景模糊过渡 | 400ms | `easeInOut` | sigma 0→3 |
| 信息区文字过渡 | 200ms | 交叉淡入淡出 | `AnimatedSwitcher` |

### 其他视觉细节

- **选中封面阴影增强**：tap 时 `diffuseShadow` blur 从 16 临时扩至 24，然后还原。
- **控件行**：`Opacity(0.3)` + `IgnorePointer` 禁用。
- **占位封面**：加载失败时显示 `AlbumCover` 内置渐变占位符，不影响交互。

---

## 边界情况

| 场景 | 行为 |
|------|------|
| 队列只有 1 首歌 | 长按不进入选曲模式 |
| 队列为空 | 无封面，长按无反应 |
| `candidateIndex == 0` | 左侧无封面，向左滑有阻尼但不切换 |
| `candidateIndex == last` | 右侧无封面，向右滑有阻尼但不切换 |
| 选曲中歌曲被外部移除 | `candidateIndex >= playlist.length` → 立即退出 |
| 选曲中收到远程播放事件 | 保持选曲不中断 |
| 屏幕旋转 | `LayoutBuilder` 重新计算尺寸 |
| 封面加载失败 | 显示占位符，不影响交互 |

---

## 错误处理

- `playAtIndex()` 失败 → 回退到选曲前状态，退出选曲，SnackBar "切换失败"
- 封面取色未就绪 → 波形保持上一个调色板，不阻塞选曲
- 安全存储写入失败 → 不影响（选曲不改持久化状态）

---

## 测试策略

### 单元测试 (`test/song_cover_picker_test.dart`)

- 单曲队列不渲染或空态
- 边界索引（0 和 last）时对应侧封面为 null
- `candidateIndex` 越界不崩溃
- `onSongSelected` 和 `onDismiss` 回调参数正确
- 封面尺寸计算：给定 screenWidth，中央 ~0.7×、侧面 ~0.5×

### Widget 测试

- 长按后 `_isSelecting == true`
- `_isSelecting == true` 时歌词滑动不触发
- 选歌后封面恢复正常，`_isSelecting == false`
- 空白点击退出选曲

### 手工验证

- [ ] 实机长按封面 → 振动 + 三封面展开
- [ ] 左右滑动切候选 → 振动 + 阻尼动画
- [ ] 边界处滑动 → 弹簧阻力
- [ ] 点击候选封面 → 播放该曲
- [ ] 点击空白 → 取消
- [ ] 控件不可点击
- [ ] 标题/艺人跟随候选变化
- [ ] 选曲中歌词滑动禁用
