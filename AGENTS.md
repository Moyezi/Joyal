# Joyal Music 项目记忆

## 项目定位

Joyal Music 是面向 iOS/Android 的 Flutter 私人音乐播放器，连接用户自建 Navidrome，通过 Subsonic/OpenSubsonic API 获取曲库、封面、歌词和音频。

视觉方向：极简、沉浸、黑白灰冷色调、大圆角、柔和阴影。UI 改动优先保持整体空间关系和观感，不机械复刻单个尺寸。

## 技术栈与安全

- Flutter / Dart / Material 3，Riverpod 管理共享状态。
- `just_audio` 负责 HTTP/本地音频和真实多曲目队列。
- `dio` 请求 Subsonic API；`cached_network_image` + `flutter_cache_manager` 管理封面缓存；`flutter_secure_storage` 保存凭据、搜索历史、播放器进度和缓存上限。
- Subsonic 认证使用随机 salt + `md5(password + salt)` token。禁止写入或传输真实明文凭据；公网 Navidrome 优先 HTTPS。

## 关键文件

- API 与播放：`lib/services/subsonic_api.dart`、`lib/services/audio_player_service.dart`、`lib/providers/player_provider.dart`。
- 曲库、搜索、收藏：`lib/providers/library_provider.dart`、`lib/screens/home_screen.dart`、`lib/screens/library_screen.dart`、`lib/screens/search_screen.dart`。
- 导航、侧边栏与 Dock：`lib/app.dart`、`lib/widgets/home_sidebar.dart`、`lib/screens/settings_hub_screen.dart`、`lib/widgets/glass_top_bar.dart`、`lib/widgets/mini_player.dart`、`lib/widgets/bottom_nav.dart`。
- 主题：`lib/config/theme.dart`、`lib/config/theme_context.dart`、`lib/providers/theme_provider.dart`。
- 播放页与选曲：`lib/screens/now_playing_screen.dart`、`lib/widgets/waveform_progress.dart`、`lib/widgets/album_visual_palette.dart`、`lib/widgets/dynamic_album_background.dart`。
- 歌词、下载与缓存：`lib/services/lyrics_service.dart`、`lib/screens/lyrics_screen.dart`、`lib/services/app_cache_service.dart`、`lib/services/download_service.dart`、`lib/screens/download_manager_screen.dart`、`lib/services/cache_stats_service.dart`、`lib/providers/cache_provider.dart`、`lib/screens/cache_management_screen.dart`。
- Android 原生桥：`android/app/src/main/kotlin/com/example/joyal_music/MainActivity.kt`、`JoyalMediaSessionManager.kt`、`PlaybackSnapshot.kt`、`OppoFluidCloudBridge.kt`。

## 导航与界面约定

- 主导航只有：首页、曲库、收藏。搜索从首页大搜索框或顶栏搜索图标进入，不占底部导航。
- 三个主页面使用统一固定毛玻璃顶栏 `GlassTopBar`。
- 根页面使用 `Stack`；页面铺底，`MiniPlayer` 与 `AppBottomNav` 组成透明 Dock 覆盖底部。
- 首页右滑打开 `HomeSidebar`；侧边栏约占屏幕 70%，右侧保留主页预览，主页内容、MiniPlayer 和 Dock 随进度右移、轻微缩小并逐渐模糊。
- 侧边栏手势由 `_MainShellState` 驱动。横向抽屉拖拽应参与 Flutter 手势竞争，避免右滑时首页 `CustomScrollView` 跟随手指上下滚动；回归测试见 `test/widget_test.dart` 的 `Home content does not scroll vertically while opening sidebar`。
- 侧边栏手势排除区由 `HomeScreen.onExclusionZoneChanged` 上报“最近添加”横向列表全局 `Rect`。排除矩形必须在 `build` 后通过 `addPostFrameCallback` + `_exclusionRectPending` 按需上报，不能只在 `initState` 上报。
- 侧边栏只放真实状态和明确标记为“预留”的占位内容，不把未实现能力做成可点击功能。左下角设置按钮进入 `SettingsHubScreen`。
- 有当前歌曲时显示迷你播放栏，无歌曲时隐藏。迷你播放栏高 104，仅顶部圆角 40；封面 72x72 圆形，播放时旋转。
- Dock 顶部圆角外必须透明，不给整个 Dock 加白色或深色衬底；深色衔接背景只放在 `AppBottomNav` 背后。
- 列表底部内边距动态避让 Dock：有 MiniPlayer 时 172，无歌曲时 68。

## 主题与深色模式

- `ThemeNotifier` 三态循环：light -> dark -> system，首次启动默认 `system`，持久化到 `flutter_secure_storage`。
- Widget 应优先通过 `ThemeContext` 获取颜色和文字样式，例如 `context.primaryColor`、`context.surfaceColor`、`context.textTitleMedium`。禁止直接引用 `AppTheme.primaryText` 等静态颜色做 UI。
- 深色颜色值：背景 `#121212` / `#1E1E1E`；正文 `#E0E0E0`；标题 `#FFFFFF`；辅助文字 `#9E9E9E`；避免纯黑 `#000000`。
- `context.primaryColor` 是主文字色，不可做按钮、图标容器、圆形底等背景；深色模式应使用 `context.surfaceColor` 做底、`context.primaryColor` 做前景。
- `GlassTopBar`、`BottomNav`、歌词等均跟随 `Theme.of(context)`，不要硬编码颜色。
- 封面取色由 `AlbumVisualPalette` 处理，缓存键含 brightness 维度；`DynamicAlbumBackground` 的回退色由 `AlbumVisualPalette.fallbackFor(brightness)` 提供，不再硬编码 `AppTheme.background`。

## 曲库、播放与歌词

- 启动从安全存储恢复 Navidrome 凭据；认证恢复后等待依赖 Provider 重建，再刷新曲库。
- `refreshLibrary()` 并行刷新专辑、全量歌曲和收藏。
- 专辑使用 `getAlbumList2.view` 分页；全量歌曲使用空查询 `search3.view` + `songOffset` 分页。
- 收藏采用共享状态和乐观更新，失败回滚；收藏页无需手动刷新即可同步。
- 播放器使用 `just_audio` 多曲目音源序列；搜索、收藏、专辑、全曲库歌曲都会用当前集合建立真实队列。
- `PlayerNotifier.playAtIndex()` 是切歌和队列点选统一入口。
- 用户明确要求：不要恢复异常自动下一首、回跳和额外 seek 保护逻辑；播放链路尽量单纯地从 Navidrome `stream.view&format=raw` 播放。
- 切歌时后台预取歌词并写入本地 JSON 缓存；不承诺应用进程彻底关闭后恢复完整队列和进度。

## 播放页与选曲模式

- 播放页取色由 `AlbumVisualPalette` 从封面生成并缓存，`DynamicAlbumBackground` 使用稳定 `coverArtId` 避免认证 URL 刷新导致重复取色。
- 波形进度条为等长离散短柱 + 涟漪行波动画，非 PCM 振幅；颜色由当前视觉歌曲的 `AlbumVisualPalette` 驱动。
- 长按播放页封面进入选曲模式；左右滑动只切换候选，不立即播放；点击中央封面确认 `playAtIndex()`，点击空白取消。
- 播放详情页支持下滑关闭，但关闭手势不能用整页垂直拖拽抢占手势竞技；避免影响封面长按进入选曲和选曲横滑。
- 待选封面应由屏幕边界自然截断，不得被封面槽、当前封面、局部 `ClipRect` 或可见遮罩/亮色槽截断。
- 选曲模式下标题、艺人、动态背景和波形颜色都跟随候选歌曲，不跟随实际正在播放歌曲。逻辑通过 `nowPlayingVisualSong(...)` 统一选择视觉歌曲；回归测试在 `test/now_playing_visual_song_test.dart`。
- 选曲逻辑保留在 `lib/screens/now_playing_screen.dart` 的 `_NowPlayingScreenState`，不拆额外组件。

## Android 媒体与 OPPO 流体云

- `lib/services/android_media_bridge.dart` 将 Flutter 播放状态桥接到 Android，payload 只传播放元数据和本地封面路径，不传流媒体 URL、token、密码或 baseUrl。
- Android 侧 `JoyalMediaSessionManager` 发布标准 `MediaSession` 元数据和播放状态，并将系统媒体控制转回 Flutter 执行；ColorOS 原生音乐流体云通过这套标准媒体信息展示。
- `OppoFluidCloudBridge` 仅保留为未来 OPPO 官方 SDK 专属接口的集中适配层；当前流体云能力来自 Android 标准媒体会话，不依赖 OPPO SDK。

## 设置、下载与缓存

- 入口：主页右滑侧边栏左下角设置按钮 -> `SettingsHubScreen`。设置总页包含服务器连接、刷新曲库、下载管理、缓存管理和关于。
- 刷新曲库走 `libraryProvider.notifier.refreshLibrary()`；未连接时不误报成功，刷新中禁用重复点击。
- 展示四类缓存：临时音频、图片封面、元数据歌词、离线下载。
- 统计使用 `Isolate.run` 递归计算目录大小，避免阻塞 UI。
- 临时音频清理 `getTemporaryDirectory()/exo/` 或临时目录；图片封面清理 `DefaultCacheManager().emptyCache()` + `libCachedImageData`；元数据歌词清理 `AppCacheService` 的 JSON 缓存且需要确认；离线下载只跳转下载管理，避免误删。
- 自动清理 Slider 档位：500MB / 1GB / 2GB / 5GB / 无限制；上限写入 `flutter_secure_storage`，超出后按文件修改时间 LRU 删除最旧临时音频。

## 构建与验证

- 静态分析：`dart analyze lib test` 或 `flutter analyze`。
- 测试：`flutter test`；播放页候选取色相关测试可单跑 `flutter test test/now_playing_visual_song_test.dart`。
- 只针对codex：Flutter / Dart 命令默认直接使用 `sandbox_permissions: "require_escalated"` 执行，常见原因是 SDK、Gradle、Pub cache 或后台进程访问会被沙箱限制；说明口径为“Flutter/Dart 需要访问 SDK/cache/process”。不要把沙箱卡住当作测试失败。
- APK 复核默认只构建 arm64 Release，不额外构建通用 Debug APK。
- arm64 Release：`flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`
- Release 输出：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `--no-tree-shake-icons` 用于绕过当前项目遇到的图标树摇构建问题。

## 已知边界

- 已有基础 Widget/逻辑测试，含 GlassTopBar 搜索图标、首页动画、主页侧边栏设置入口、收藏页无“我的”按钮、侧边栏右滑不纵向滚动、波形几何、封面取色基础和播放页视觉歌曲选择。
- 认证解析、模型解析、播放器状态仍缺单元测试。
- 空查询 `search3.view` 枚举全库需继续在不同 Navidrome/Subsonic 服务上验证。
- Web CORS、iOS 真机局域网权限提示、不同服务端响应版本需要实机联调。
- 旧文件里可能有中文乱码；不要因为 PowerShell 显示乱码就批量重写无关代码。需要读中文文件时优先显式使用 UTF-8。

## 协作约定

- 用户通常通过实机截图反馈 UI；改动后优先构建 arm64 Release APK 供复核。
- 添加 UI 操作前先确认 provider/service 已有对应能力，不把占位 UI 描述为完成。
- 保留用户已有修改，只改任务范围内文件。
- 遇到厂商 SDK、账号、远程服务等外部依赖时，明确区分“已预留/已桥接”和“已真实接入”。
- 项目记忆允许适度精简：保留会影响实现判断的约束、路径、命令和坑点；删掉过时流水账和已经可从代码直接读出的细枝末节。
