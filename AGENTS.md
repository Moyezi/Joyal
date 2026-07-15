# Joyal Music 项目摘要

本文件只保留项目级摘要和 skill 索引。详细项目记忆位于 `.agents/skills/*/SKILL.md`，较大的主题由入口 `SKILL.md` 再路由到同目录 `references/`；做非平凡改动前，先完整读取入口文件，再只读取与任务相关的 reference。任务范围不清时，先读 `.agents/skills/joyal-project-core/SKILL.md`。

## 项目定位

Joyal Music 是 Flutter iOS/Android 私人音乐播放器，连接用户自建 Navidrome，通过 Subsonic/OpenSubsonic API 获取曲库、封面、歌词和音频。视觉方向是极简、沉浸、黑白灰冷色调、大圆角和柔和层次；UI 改动优先保持整体空间关系和观感。

核心技术：Flutter / Dart / Material 3、Riverpod、`just_audio`、`dio`、本地磁盘封面缓存。安全底线：真实凭据和 DeepSeek API Key 只能进 secure storage；Android 媒体桥不得传流媒体 URL、token、密码或 `baseUrl`；分类请求只发歌曲文字元数据。歌词高潮分析可发送歌曲名、歌手、专辑、时长和带时间歌词；AI 歌词配色可发送歌曲名、歌手、专辑和纯歌词文本。两者均不得发送凭据、服务地址、媒体 URL 或封面 URL。

## 项目 Skills

- `.agents/skills/joyal-project-core/SKILL.md`：项目定位、技术栈、安全规则、关键路径、协作边界。
- `.agents/skills/joyal-navigation-shell/SKILL.md`：主导航、根页面栈、`GlassTopBar`、侧边栏、MiniPlayer、Dock、设置入口。
- `.agents/skills/joyal-home-discovery/SKILL.md`：首页每日推荐/随机专辑、发现页 Cover Flow、收藏歌曲、“为你发现”卡片和推荐种子。
- `.agents/skills/joyal-visual-glass-theme/SKILL.md`：主题颜色、`ThemeContext`、页面背景、封面取色、`FrostedGlass`、液态玻璃、视觉性能。
- `.agents/skills/joyal-library-playback-lyrics/SKILL.md`：凭据恢复、曲库刷新、排序、收藏、播放队列、听歌统计、歌词缓存和歌词页。
- `.agents/skills/joyal-classification/SKILL.md`：小Jo同学、标签分类、高潮缓存管理、DeepSeek 安全、固定词表和手动修正。
- `.agents/skills/joyal-now-playing-selection/SKILL.md`：播放详情页、Hero 转场、波形进度、封面切歌、长按封面选曲模式。
- `.agents/skills/joyal-settings-cache-release/SKILL.md`：设置、缓存/下载、`CachedDiskImage`、`AppCacheService`、验证命令、Release APK 构建坑点。

## 常用验证

- 静态分析：`dart analyze lib test` 或 `flutter analyze`。
- 测试：`flutter test`。
- 常用单测：`flutter test test/widget_test.dart`、`flutter test test/home_search_animation_test.dart`、`flutter test test/now_playing_visual_song_test.dart`、`flutter test test/cache_provider_test.dart`、`flutter test test/lyrics_provider_test.dart`。
- 默认实机复核构建：`flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`。
- APK 输出：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。

## 协作边界

- 保留用户已有修改，只改任务范围内文件。
- 旧文件可能有中文乱码；不要因 PowerShell 显示乱码批量重写无关代码，读中文文件优先显式 UTF-8。
- 添加 UI 操作前先确认 provider/service 已有能力，不把占位 UI 描述为完成。
- 遇到厂商 SDK、账号、远程服务等外部依赖时，明确区分“已预留/已桥接”和“已真实接入”。
