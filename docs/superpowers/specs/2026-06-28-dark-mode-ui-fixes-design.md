# 深色模式 UI 修复 — 设计文档

**日期**: 2026-06-28
**状态**: 已批准

---

## 问题描述

深色模式下三处 UI 未适配：

1. **专辑详情页"播放全部"按钮** — 白色背景 + 白色图标/文字，不可见
2. **播放页播放/暂停大圆按钮** — 白色圆形底 + 白色图标，不可见
3. **设置页卡片** — 仍为浅色模式的白底黑字样式

## 根因

| 问题 | 文件 | 原因 |
|------|------|------|
| "播放全部"按钮 | `album_detail_screen.dart:_ActionButton` | `backgroundColor: context.primaryColor` → 深色模式解析为 `#FFFFFF`，前景为硬编码 `Colors.white` |
| 播放/暂停按钮 | `now_playing_screen.dart:800` | `BoxDecoration(color: context.primaryColor)` → 同上，图标 `Colors.white` |
| 设置卡片 | `settings_hub_screen.dart:_SettingsHubItem` | 直接引用静态常量 `AppTheme.surfaceLight` / `AppTheme.primaryText` / `AppTheme.secondaryText`，未走上下文感知 getter |

核心矛盾：`context.primaryColor` 语义是"主要文字颜色"（浅色=黑、深色=白），被误用作按钮背景色，在深色模式下恰好同色隐形。

## 设计决策

- 深色模式操作按钮统一使用**深灰表面色**（`darkSurface` / `context.surfaceColor`）作背景，**白色主文字色**（`context.primaryColor`）作前景
- "播放全部"与"随机播放"在深色模式下外观统一，不区分主次
- 浅色模式视觉效果**不做任何改变**
- 不新增主题色常量或 getter，复用现有 `ThemeContext` 体系

## 修改清单

### 1. `lib/screens/album_detail_screen.dart` — `_ActionButton`

将 `ElevatedButton.styleFrom` 按亮度分支：

- **深色模式**：背景 = `context.surfaceColor`，前景 = `context.primaryColor`
- **浅色模式**：保持现有逻辑（`light=false` 黑底白字，`light=true` 浅灰底黑字）

### 2. `lib/screens/now_playing_screen.dart` — 播放/暂停按钮

`Container` 的 `BoxDecoration` 和 `Icon` 按亮度分支：

- **深色模式**：圆底 = `context.surfaceColor`，图标色 = `context.primaryColor`
- **浅色模式**：保持黑底白图标

### 3. `lib/screens/settings_hub_screen.dart` — `_SettingsHubItem`

三处硬编码替换为上下文感知 getter：

- `AppTheme.surfaceLight` → `context.surfaceColor`（卡片底色）
- `AppTheme.primaryText` → `context.primaryColor`（标题色）
- `AppTheme.secondaryText` → `context.secondaryColor`（副标题色）

## 不改的部分

- 不修改 `lib/config/theme.dart` 或 `lib/config/theme_context.dart`
- 不修改 `lib/providers/theme_provider.dart`
- 不改变浅色模式下的任何视觉效果
- 不新增 widget 或拆分组件

## 验收标准

- 深色模式下专辑详情页"播放全部"按钮可见（深灰底 + 白字）
- 深色模式下播放页播放/暂停按钮可见（深灰圆底 + 白图标）
- 深色模式下设置卡片为深色底 + 白字样式
- 浅色模式所有页面视觉效果与修复前一致
- `flutter analyze lib test` 无新增警告
- 现有测试全部通过
