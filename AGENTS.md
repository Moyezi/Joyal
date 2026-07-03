# Joyal Music 项目记忆

## 项目定位

Joyal Music 是 iOS/Android Flutter 私人音乐播放器，连接用户自建 Navidrome，通过 Subsonic/OpenSubsonic API 获取曲库、封面、歌词和音频。

视觉方向：极简、沉浸、黑白灰冷色调、大圆角、柔和层次。UI 改动优先保持整体空间关系和观感，不机械复刻单个尺寸。

## 技术与安全

- Flutter / Dart / Material 3，Riverpod 管共享状态；播放用 `just_audio`，请求用 `dio`，封面缓存优先走本地磁盘。
- 凭据、搜索历史、播放进度、主题、页面背景路径、缓存上限、毛玻璃强度等偏好写入 `flutter_secure_storage`；缓存上限另写 `AppCacheService` JSON 兜底。
- Subsonic 认证使用随机 salt + `md5(password + salt)` token。禁止写入或传输真实明文凭据；公网 Navidrome 优先 HTTPS。
- Android 媒体桥只传播放元数据和本地封面路径，不传流媒体 URL、token、密码或 baseUrl。`OppoFluidCloudBridge` 仅作未来 SDK 预留，当前依赖标准 `MediaSession`。

## 关键路径

- API/播放：`lib/services/subsonic_api.dart`、`lib/services/audio_player_service.dart`、`lib/providers/player_provider.dart`、`lib/providers/listening_stats_provider.dart`。
- 曲库/搜索/收藏：首页、曲库、收藏、搜索相关代码在 `lib/providers/library_provider.dart` 与 `lib/screens/home_screen.dart`、`library_screen.dart`、`hotlist_screen.dart`、`search_screen.dart`。
- 导航/设置/Dock：`lib/app.dart`、`lib/widgets/home_sidebar.dart`、`mini_player.dart`、`bottom_nav.dart`、`play_queue_sheet.dart`、`lib/screens/settings_hub_screen.dart`、`personalization_screen.dart`。
- 视觉/毛玻璃/背景：`lib/providers/page_background_provider.dart`、`glass_effect_provider.dart`、`visual_effect_provider.dart`、`mini_player_color_provider.dart`、`lib/widgets/frosted_glass.dart`、`glass_top_bar.dart`、`page_custom_background.dart`、`dynamic_album_background.dart`、`album_visual_palette.dart`、`mini_player_chrome.dart`。
- 播放页/歌词：`lib/screens/now_playing_screen.dart`、`lyrics_screen.dart`、`lib/providers/lyrics_provider.dart`、`lib/widgets/waveform_progress.dart`、`now_playing_transition.dart`。
- 下载/缓存：`lib/services/app_cache_service.dart`、`cache_repository.dart`、`lib/providers/cache_provider.dart`、`lib/screens/cache_management_screen.dart`、`lib/widgets/cached_disk_image.dart`。
- Android 媒体桥：`android/app/src/main/kotlin/com/example/joyal_music/`。

## 导航与界面约定

- 主导航只有：首页、曲库、收藏；搜索从首页大搜索框或顶栏搜索图标进入。旧 widget 测试可能仍按 `主页` 文案断言。
- 主页面用全屏 `Stack` 铺底，固定 `GlassTopBar` 覆盖状态栏，内容从状态栏下方开始并避让顶栏。曲库“歌曲/专辑” TabBar 是顶栏下方额外区域，不应改变标题/按钮位置。
- 根页面由 `PageView` 承载主页面；`MiniPlayer` 与 `AppBottomNav` 是透明 Dock 上的悬浮胶囊。列表底部 padding 必须动态避让 Dock；有播放栏时额外避让 `MiniPlayer` 高度。
- `AppBottomNav` 区域支持横向拖动切换页面，跨项触发选择振动，页面应从边缘滑入而不是瞬间替换。
- `MiniPlayer` 右滑折叠为右下旋转专辑封面按钮，状态由 `_MainShellState` 管；底部 Dock 区域不触发主页侧边栏右滑。折叠/展开保持固定高度轨道，避免竖向瞬移。
- 歌曲列表行优先复用 `SongTile` + `SongActionsSheet`；“下一首播放”加入队列后要 toast 确认。
- 首页每日推荐：从 `LibraryState.songs` 按当天日期稳定随机选 24 首，栏内 3 首；“查看更多”复用 `PlayQueueSheet`，歌曲卡片复用 `QueueSongCard`，点击推荐歌曲以这 24 首建立真实播放队列。
- 首页随机专辑：从 `LibraryState.albums` 按当天日期稳定随机选 8 张；“查看更多”切到曲库页并选中“专辑”Tab；底部文案固定 `----到底了----`。
- 首页右滑打开 `HomeSidebar`：侧边栏约 70% 宽，主页内容、MiniPlayer、Dock 随进度右移/缩小/变暗。“最近添加”横向列表是排除区，由 `HomeScreen.onExclusionZoneChanged` 上报。
- 侧边栏动画优先流畅：用 `_drawerController` + `AnimatedBuilder` 驱动预览层，主页面内容作为静态 child/RepaintBoundary；开合过程中不要用全屏动态 `BackdropFilter`。
- 侧边栏只放真实状态和明确标记“预留”的占位；底部按钮进入设置、个性化或循环主题。

## 主题与视觉

- `ThemeNotifier` 三态循环：light -> dark -> system，首次启动默认 `system`。
- Widget 优先通过 `ThemeContext` 取颜色和文字样式；不要直接用 `AppTheme.primaryText` 等静态颜色做 UI。
- 深色背景 `#121212` / `#1E1E1E`，正文 `#E0E0E0`，标题 `#FFFFFF`，辅助文字 `#9E9E9E`；避免纯黑 `#000000`。
- `context.primaryColor` 是主文字色，不可做按钮/图标容器/圆形底等背景；深色模式用 `context.surfaceColor` 做底、`context.primaryColor` 做前景。
- Toast 统一用 `showAppToast(...)`；宽度按文案自适应，优先 `BoxConstraints`，不要用 `TextPainter` 手算。
- 封面取色由 `AlbumVisualPalette` 处理，缓存键含 brightness；动态背景尽量用稳定 `coverArtId`，避免认证 URL 刷新导致重复取色。
- 主页面背景由 `PageBackgroundProvider` + `PageCustomBackground` 管：首页、曲库、收藏可选择本地图片，不改变列表、顶栏和 Dock 空间关系。
- 毛玻璃统一由 `glass_effect_provider.dart` 管强度，通用容器用 `FrostedGlass`。`GlassEffectTarget` 包含顶栏、迷你播放栏、搜索框、导航栏、歌曲卡片；新增毛玻璃 UI 要接入个性化“毛玻璃”横向预览。
- 迷你播放栏颜色由 `mini_player_color_provider.dart` 控制，个性化可切换“默认颜色/动态取色”；默认保持 `AppTheme.miniPlayerBg`，动态取色复用 `AlbumVisualPalette`，胶囊 tint 和折叠悬浮封面圆形外框需同步遵循，并继续走 `FrostedGlass` 的 blur 强度。
- 真实迷你播放栏与个性化“毛玻璃”迷你播放栏预览共用 `mini_player_chrome.dart` 的动态取色解析；预览在动态取色模式下必须跟随当前播放歌曲封面，不要硬编码候选色。未拿到封面 palette 前可暂用中性 fallback，不要用 `coverArtId` hash 伪造候选色，避免与真实封面色调不符。
- 个性化毛玻璃预览用类似 iOS 后台的横向堆叠卡，滑动时触发选择振动；预览背景固定冷色底图和两个大渐变圆。不要用整卡 `Opacity` 包住 `BackdropFilter`。
- `GlassTopBar` 保持可独立渲染；主页面从 provider 读取 blur 后通过参数传入，不让顶栏 widget 强依赖外层 `ProviderScope`。
- 播放详情页/歌词页背景由 `DynamicAlbumBackground` 统一实现；流动光影用 `CustomPainter` + `sin/cos`，避免每帧全屏高斯模糊；静态渐变应停止动画控制器。

## 曲库、播放与歌词

- 启动从安全存储恢复 Navidrome 凭据；认证恢复后等待依赖 Provider 重建再刷新曲库。启动遮罩覆盖凭据读取和本地播放会话恢复，避免 MiniPlayer/Dock 闪现。
- `refreshLibrary()` 并行刷新专辑、全量歌曲和收藏。专辑用 `getAlbumList2.view` 分页；全量歌曲用空查询 `search3.view` + `songOffset` 分页。
- 曲库页刷新走 `refreshLibrary()`，收藏页刷新走 `fetchStarred()`；防重复触发，未连接时提示，刷新后用 `showAppToast(...)` 明确成功或失败。
- 收藏采用共享状态和乐观更新，失败回滚；收藏页无需手动刷新即可同步。
- 播放器使用 `just_audio` 多曲目音源序列；搜索、收藏、专辑、全曲库歌曲都用当前集合建立真实队列。`PlayerNotifier.playAtIndex()` 是切歌和队列点选统一入口。
- `ListeningStatsNotifier` 只记录本机已听过的去重歌曲 id；侧边栏“听歌概览”进度 = 已听歌曲数 / 当前曲库全部歌曲数，不描述成服务端统计。
- 用户明确要求：不要恢复异常自动下一首、回跳和额外 seek 保护逻辑；播放链路尽量单纯从 Navidrome `stream.view&format=raw` 播放。
- 切歌时后台预取当前歌曲和下一首歌词并写入本地 JSON 缓存；不承诺应用彻底关闭后恢复完整队列和进度。
- 歌词缓存键按 `baseUrl + username + song.id` 作用域生成；空歌词短期缓存，失败后移除内存 Future 缓存。
- `LyricsScreen` 初始化后立即加载，不等横滑动画完成。歌词页不显示返回键和标题“歌词”，顶部只固定当前歌曲名和歌手。
- 歌词页出现或横滑过渡中时，播放详情页外层下滑关闭手势禁用；退出歌词页走现有横滑/切换逻辑。
- MiniPlayer 中间区域显示当前句和下一句歌词，不显示歌名/歌手；换句共用同一垂直轨道，动画时长按相邻歌词时间差调整。歌词边界通过 Row 布局、间距、外层 padding/transform 调整，不要在歌词内部 `ClipRect` 里负偏移文本导致左侧截断；当前实机校准为封面后间距 `1px`，歌词显示窗口左边界左移 `2px`、右边界左移 `4px`。

## 播放页与选曲模式

- 播放页爱心、更多、播放队列等按钮普通态与播放控制按钮统一用 `context.primaryColor`；收藏态保留 `context.favoriteRedColor`。
- 点击 MiniPlayer 进入播放详情页使用透明 `PageRouteBuilder` + 页面内自绘转场；背景从底部铺满，专辑封面用共享 Hero 从迷你栏圆形头像移动到播放页。
- 迷你栏圆形封面可旋转且跨 Hero/重建保存相位；播放详情页大封面停留态静止。Hero 飞行层负责形状和阴影连续过渡，逻辑在 `now_playing_transition.dart`。
- 波形进度条为等长离散短柱 + 涟漪行波动画，非 PCM 振幅；颜色由当前视觉歌曲取色并按亮暗模式校正。拖动时染色边界跟随手指。
- 下一首/上一首封面横向切换：离场封面必须完全离开屏幕后再清理。
- 长按播放页封面进入选曲模式；左右滑只切候选，不立即播放；点击中央封面确认 `playAtIndex()`，点击空白取消。
- 待选封面由屏幕边界自然截断，不被封面槽、当前封面、局部 `ClipRect` 或可见遮罩截断。
- 选曲模式下标题、艺人、动态背景和波形颜色跟随候选歌曲；通过 `nowPlayingVisualSong(...)` 统一选择视觉歌曲。选曲逻辑保留在 `_NowPlayingScreenState`。

## 设置、下载与缓存

- 设置入口：主页右滑侧边栏左下角设置按钮 -> `SettingsHubScreen`。刷新曲库走 `libraryProvider.notifier.refreshLibrary()`，未连接不误报成功。
- 缓存统计/清理由 `CacheRepository` 和各 bucket 管理，耗时目录统计用 `Isolate.run`，避免阻塞 UI。离线下载只跳转下载管理，避免误删。
- 图片显示优先 `CachedDiskImage`：先用稳定 `cacheKey` 查磁盘再走网络。专辑/歌曲封面 key 用稳定 `coverArtId`；歌手头像不要用 `String.hashCode` 做持久 key。
- Subsonic 封面 URL 会因随机 salt/token 变化；新封面/头像 UI 不要直接用 `CachedNetworkImage`。异步取色、provider family、磁盘缓存等身份 key 必须使用稳定来源（如 `coverArtId + baseUrl + username + brightness`），不要把带随机 token 的 `coverUrl` 放进 equality/hash，否则会反复重建请求并长期拿不到封面色。
- `AppCacheService` 管理小型 JSON 缓存。不要在实例方法里用捕获实例字段的 `Isolate.run(() => jsonEncode(value))`。
- 自动清理 Slider 档位：500MB / 1GB / 2GB / 5GB / 无限制。上限写 secure storage，并同步写 `cache_settings` JSON 兜底；启动先加载设置再允许刷新统计。

## 构建与验证

- 静态分析：`dart analyze lib test` 或 `flutter analyze`。
- 测试：`flutter test`。常用：`flutter test test/widget_test.dart`、`test/home_search_animation_test.dart`、`test/now_playing_visual_song_test.dart`、`test/cache_provider_test.dart`、`test/lyrics_provider_test.dart`。
- 侧边栏手势回归：`Home content does not scroll vertically while opening sidebar`、`Home sidebar closes on a fast left fling`。
- 播放页视觉/歌词手势回归：`test/now_playing_visual_song_test.dart`。
- APK 复核默认构建 arm64 Release：`flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`。
- Release 输出：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。`--no-tree-shake-icons` 用于绕过当前项目遇到的图标树摇构建问题。

## 协作边界

- 认证解析、模型解析、播放器状态仍缺单元测试。空查询 `search3.view` 枚举全库需继续在不同 Navidrome/Subsonic 服务上验证。
- 旧文件里可能有中文乱码；不要因为 PowerShell 显示乱码就批量重写无关代码。需要读中文文件时优先显式使用 UTF-8。
- 用户通常通过实机截图反馈 UI；改动后优先构建 arm64 Release APK 供复核。
- 添加 UI 操作前先确认 provider/service 已有对应能力，不把占位 UI 描述为完成。
- 保留用户已有修改，只改任务范围内文件。遇到厂商 SDK、账号、远程服务等外部依赖时，明确区分“已预留/已桥接”和“已真实接入”。
- 项目记忆可继续适度精简：保留会影响实现判断的约束、路径、命令和坑点；删掉过时流水账和已能从代码直接读出的细节。
