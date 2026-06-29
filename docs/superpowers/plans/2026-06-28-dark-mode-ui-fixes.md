# 深色模式 UI 修复 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复深色模式下三处 UI 未适配问题：专辑详情页按钮、播放页播放/暂停按钮、设置卡片。

**Architecture:** 三个独立文件的局部修改，都在现有 widget 的 `build()` 中根据 `Theme.of(context).brightness` 分支选择颜色，浅色模式行为不变。不新增文件、不修改主题基础设施。

**Tech Stack:** Flutter / Dart / Material 3 / Riverpod（仅读取现有 provider，不修改）

## Global Constraints

- 浅色模式视觉效果不做任何改变
- 不新增主题色常量或 ThemeContext getter
- `flutter analyze lib test` 无新增警告
- 现有测试全部通过

---

### Task 1: 修复专辑详情页 `_ActionButton` 深色模式按钮色

**Files:**
- Modify: `lib/screens/album_detail_screen.dart:246-258`

**Interfaces:**
- Consumes: `context.surfaceColor`, `context.primaryColor`（来自 `ThemeContext` 扩展）
- Produces: 无新接口

- [ ] **Step 1: 修改 `_ActionButton.build()` 中的按钮样式**

将 `ElevatedButton.styleFrom` 的 `backgroundColor` 和 `foregroundColor` 按亮度分支：

```dart
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? context.surfaceColor
              : (light ? context.surfaceColor : context.primaryColor),
          foregroundColor: isDark
              ? context.primaryColor
              : (light ? context.primaryColor : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          elevation: 0,
        ),
      ),
    );
  }
```

- [ ] **Step 2: 运行静态分析验证**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter analyze lib/screens/album_detail_screen.dart
```

Expected: No issues found.

- [ ] **Step 3: 运行现有测试**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/album_detail_screen.dart
git commit -m "fix: dark mode button colors in album detail _ActionButton"
```

---

### Task 2: 修复播放页播放/暂停大圆按钮深色模式色

**Files:**
- Modify: `lib/screens/now_playing_screen.dart:797-813`

**Interfaces:**
- Consumes: `context.surfaceColor`, `context.primaryColor`（来自 `ThemeContext` 扩展）
- Produces: 无新接口

- [ ] **Step 1: 修改播放/暂停按钮的 Container 和 Icon 颜色**

将 `BoxDecoration.color` 和 `Icon.color` 按亮度分支：

```dart
                  // Play / Pause (large CTA)
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: isDark ? context.surfaceColor : context.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: isDark ? context.primaryColor : Colors.white,
                        size: 40,
                      ),
                      onPressed: () => notifier.togglePlayPause(),
                    ),
                  ),
```

> 注意：变量 `isDark` 声明放在 `Container(` 之前，与周围代码风格一致。

- [ ] **Step 2: 运行静态分析验证**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter analyze lib/screens/now_playing_screen.dart
```

Expected: No issues found.

- [ ] **Step 3: 运行现有测试**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/now_playing_screen.dart
git commit -m "fix: dark mode play/pause button color in now playing screen"
```

---

### Task 3: 修复设置页 `_SettingsHubItem` 卡片深色模式色

**Files:**
- Modify: `lib/screens/settings_hub_screen.dart:166-195`

**Interfaces:**
- Consumes: `context.surfaceColor`, `context.primaryColor`, `context.secondaryColor`（来自 `ThemeContext` 扩展）
- Produces: 无新接口

- [ ] **Step 1: 将硬编码颜色替换为上下文感知 getter**

三处替换：

```dart
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,                                    // was: AppTheme.surfaceLight
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: AppTheme.spacingMD,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, size: 20, color: context.primaryColor),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        color: context.primaryColor,                   // was: AppTheme.primaryText
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.secondaryColor,                 // was: AppTheme.secondaryText
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Icon(Icons.chevron_right, color: context.secondaryColor),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 2: 运行静态分析验证**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter analyze lib/screens/settings_hub_screen.dart
```

Expected: No issues found.

- [ ] **Step 3: 运行现有测试**

```bash
cd c:\Users\Moye\Desktop\Joyal-mainFDS; flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_hub_screen.dart
git commit -m "fix: dark mode card colors in settings hub _SettingsHubItem"
```

---

## Verification (Post-Implementation)

在所有 task 完成后执行：

- [ ] 全量静态分析：`flutter analyze lib test`
- [ ] 全量测试：`flutter test`
- [ ] 构建 arm64 Release APK 用于实机复核：`flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`
