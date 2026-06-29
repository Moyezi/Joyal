# 涟漪波形进度条重构设计

## 目标

将播放器波形进度条从"基于 trackKey 的伪随机能量包络 + 单柱脉冲"改为"等长离散短柱 + 涟漪扩散动画"，使播放中的视觉反馈更优雅、更音乐化。

## 设计决策

| 维度 | 选择 |
|---|---|
| 动画模式 | 波浪涟漪，从播放位置向外双向对称扩散 |
| 活跃区宽度 | 按比例，占柱子总数 15-20% |
| 静态高度 | 12px |
| 呼吸幅度 | 细微：12px → 18-24px（1.5-2x），温和不抢眼 |
| 着色策略 | 仅活跃区内柱子用 waveformAccent（已播放色），活跃区外全部用 waveformTrack（未播放色），去掉 playedGlowColor 渐变 |
| 拖拽行为 | 保留磁吸形变（手指附近放大、远处压平）与涟漪叠加 |
| 涟漪周期 | 固定 ~600ms 完整循环，与音乐 BPM 无关 |
| 涟漪方向 | 双向对称（以播放/拖拽位置为中心同时向左右扩散） |

## 架构变更

### 1. 移除能量包络生成

- 删除 `_generateWaveform()` 静态方法及 `_waveformData` 成员
- 删除基于 `trackKey.hashCode` 的 `Random` 伪随机波形
- 所有柱子静态高度统一为 `staticBarHeight`（12px），不再有高矮差异
- `WaveformProgress` 不再依赖 `trackKey` 生成波形数据，仅保留用于 `didUpdateWidget` 中检测切歌

### 2. 新增涟漪动画系统

**`_ripplePhaseController`**（`AnimationController`，循环 `repeat`）：
- 播放时 repeat 驱动涟漪相位 `0 → 2π`，周期 ~600ms
- 暂停时 stop，保持当前相位

**`_rippleFadeController`**（`AnimationController`，单次）：
- 播放时 forward → 活跃区 alpha 从 0 淡入到 1
- 暂停时 reverse → 活跃区 alpha 淡出到 0，柱子收拢回 12px

**涟漪高度公式**（每根柱子）：
```
distance = |barFraction - centerFraction|
// 活跃区半宽 = activeWidth / 2（~10% 总宽）
if (distance > activeHalfWidth) → 12px（静止）
else {
  normalizedDist = distance / activeHalfWidth  // 0 到 1
  envelope = cos(normalizedDist * π/2)          // 中心 1，边缘 0，余弦衰减
  ripple = sin(normalizedDist * 2π - phase)     // 波浪相位
  height = 12 + envelope * ripple * 6 + envelope * 3  // 基线抬高 + 波动，范围 12-24px
}
```

### 3. 拖拽行为：磁吸 + 涟漪叠加

- 拖拽时活跃区中心 = 手指位置
- 涟漪围绕手指位置扩散，与播放时行为一致
- 磁吸形变（`morphedHeight` 现有逻辑）作为**叠加层**：手指附近柱子额外放大 22%，远处压平
- 拖拽松手后 `_dragMorphController.reverse()` 回弹，涟漪中心回到播放位置
- 保留触觉反馈（selectionClick + lightImpact）和时间气泡

### 4. 着色逻辑简化

- 活跃区内柱子：`playedColor`（即 `waveformAccent`）
- 活跃区外柱子：`unplayedColor`（即 `waveformTrack`）
- 去掉 `playedGlowColor` — 不再有已播放/未播放渐变混合，仅靠活跃区高亮区分
- `WaveformProgress` 构造函数保留 `playedGlowColor` 参数但标记为 deprecated/可选，向后兼容

### 5. `WaveformGeometry` 改造

- **移除**：`morphedHeight()` 中的能量包络依赖（`baseEnergy` 参数不再从 `_waveformData` 取，改为固定 1.0）
- **新增**：`rippleHeight(barFraction, centerFraction, phase, activeHalfWidth, staticHeight, rippleAmplitude)`
- **新增**：`activeHalfWidth` 计算（基于 `barCount` 的比例，默认 0.10，即活跃区半径 = 10% 总宽，直径 = 20%）
- **保留**：`effectiveDragFraction()` 用于拖拽松手回弹过渡
- **保留**：磁吸形变 `morphedHeight()` 作为可选叠加

### 6. `_WaveformPainter` 改造

- 不再持有 `waveformData`，改为持有 `barCount`
- `paint()` 中每根柱子高度计算：
  1. 涟漪高度（如果 `rippleAlpha > 0`）
  2. 叠加磁吸形变（如果 `dragIntensity > 0`）
  3. 最终 clamp 到 [3, maxHeight]
- 取消基于 `progress` 的已播放/未播放着色混合逻辑

## 文件影响

| 文件 | 改动 |
|---|---|
| `lib/widgets/waveform_progress.dart` | 主要改动：删除波形生成，新增涟漪动画，简化着色，保留磁吸拖拽 |
| `lib/screens/now_playing_screen.dart` | 可能简化：不再传 `playedGlowColor`（或保留但忽略） |
| `lib/widgets/album_visual_palette.dart` | 无需改动 |
| `lib/config/theme.dart` | 无需改动 |
| `test/waveform_progress_test.dart` | 更新测试：涟漪高度、活跃区宽度、磁吸叠加、着色边界 |

## 边界与约束

- 柱数 `barCount` 默认保持 72
- 活跃区半径 `activeHalfWidth = 0.10`（直径 20%），例如 72 柱 → 活跃区约 14-15 根柱子
- 涟漪周期固定与音乐 BPM 无关
- 拖拽松手回弹仍使用 `Curves.elasticOut`（340ms）
- 不恢复异常自动下一首、回跳保护逻辑（遵循 AGENTS.md 约定）

## 不在范围

- 不改动 `just_audio` 播放链路或 seek 逻辑
- 不接入真实 PCM 振幅数据
- 不修改歌词页面或队列页面
- 不改动 Android 媒体会话桥接
