# Joyal Music 项目记忆

## 项目定位

Joyal Music 是 iOS/Android Flutter 私人音乐播放器，连接用户自建 Navidrome，通过 Subsonic/OpenSubsonic API 获取曲库、封面、歌词和音频。

视觉方向：极简、沉浸、黑白灰冷色调、大圆角、柔和层次。UI 改动优先保持整体空间关系和观感，不机械复刻单个尺寸。

## 技术与安全

- Flutter / Dart / Material 3，Riverpod 管共享状态；播放用 `just_audio`，请求用 `dio`，封面缓存优先走本地磁盘。
- 凭据、搜索历史、播放进度、主题和缓存上限写入 `flutter_secure_storage`；缓存上限另写 `AppCacheService` JSON 兜底。
- Subsonic 认证使用随机 salt + `md5(password + salt)` token。禁止写入或传输真实明文凭据；公网 Navidrome 优先 HTTPS。
- Android 媒体桥只传播放元数据和本地封面路径，不传流媒体 URL、token、密码或 baseUrl。`OppoFluidCloudBridge` 仅作未来 SDK 预留，当前依赖标准 `MediaSession`。

## 关键路径

- API/播放：`lib/services/subsonic_api.dart`、`lib/services/audio_player_service.dart`、`lib/providers/player_provider.dart`。
- 曲库/搜索/收藏：`lib/providers/library_provider.dart`、`lib/screens/home_screen.dart`、`lib/screens/library_screen.dart`、`lib/screens/hotlist_screen.dart`、`lib/screens/search_screen.dart`。
- 导航/设置/Dock：`lib/app.dart`、`lib/widgets/home_sidebar.dart`、`lib/screens/settings_hub_screen.dart`、`lib/screens/personalization_screen.dart`、`lib/widgets/glass_top_bar.dart`、`lib/widgets/mini_player.dart`、`lib/widgets/bottom_nav.dart`、`lib/widgets/play_queue_sheet.dart`。
- 播放页/歌词/视觉：`lib/screens/now_playing_screen.dart`、`lib/screens/lyrics_screen.dart`、`lib/providers/lyrics_provider.dart`、`lib/providers/visual_effect_provider.dart`、`lib/widgets/waveform_progress.dart`、`lib/widgets/album_visual_palette.dart`、`lib/widgets/dynamic_album_background.dart`。
- 下载/缓存：`lib/services/app_cache_service.dart`、`lib/services/cache_repository.dart`、`lib/providers/cache_provider.dart`、`lib/screens/cache_management_screen.dart`、`lib/widgets/cached_disk_image.dart`。
- Android 媒体桥：`android/app/src/main/kotlin/com/example/joyal_music/`。

## 导航与界面约定

- 主导航只有：首页、曲库、收藏；搜索从首页大搜索框或顶栏搜索图标进入。
- 三个主页面使用固定毛玻璃顶栏 `GlassTopBar`，标题/按钮行用 `GlassTopBarTitleRow`。曲库“歌曲/专辑” TabBar 是额外下方区域，不影响标题和按钮位置。
- 根页面用 `Stack`；页面铺底，`MiniPlayer` 与 `AppBottomNav` 组成透明 Dock 覆盖底部。列表底部内边距要动态避让 Dock，并区分无播放栏/有播放栏两种情况；有播放栏时额外加上 `MiniPlayer` 高度。
- 迷你播放栏支持在自身区域右滑折叠成右下悬浮旋转专辑封面按钮，点击按钮展开；折叠态必须同步收回 Dock 外层藏青色背景，底部导航回到页面背景色。该交互由 `_MainShellState` 管折叠状态，`MiniPlayer` 只负责展开/折叠形态和手势回调；底部 Dock 区域不应触发主页侧边栏右滑。
- 迷你播放栏折叠/展开应保持固定高度轨道，封面作为共享元素从左侧非线性收缩到右侧悬浮按钮；不要用不同高度组件切换导致结束时竖向瞬移。Dock 外层藏青色背景与迷你播放栏主体要使用同一时长/曲线/淡出进度，避免底部导航左右上角色块提前消失或出现。
- 独立详情页的返回按钮固定在页面级左上安全区；复用内容组件不要自带返回栏或改变 TabBar/标题区域高度。
- 歌曲列表行优先复用 `SongTile` + `SongActionsSheet`，保持播放态、下载标记、更多菜单和排版一致。
- 歌曲操作里的“下一首播放”应在加入队列后显示 toast 确认，不做无反馈的静默操作。
- 首页“每日推荐”从 `LibraryState.songs` 中按当天日期稳定随机选 24 首，栏内展示 3 首；“查看更多”复用 `PlayQueueSheet` 抽屉，歌曲卡片复用 `QueueSongCard`。点击推荐歌曲应以这 24 首建立真实播放队列。
- 首页“全部专辑”只展示 4 行专辑（双列共 8 张）；标题右侧灰色“查看更多”切换到底部导航的曲库页并选中“专辑”Tab。首页专辑区底部文案固定为 `----到底了----`。
- 首页右滑打开 `HomeSidebar`：侧边栏约占屏幕 70%，右侧保留主页预览；主页内容、MiniPlayer 和 Dock 随进度右移、轻微缩小并模糊。手势由 `_MainShellState` 驱动，“最近添加”横向列表是排除区，由 `HomeScreen.onExclusionZoneChanged` 上报。
- 侧边栏只放真实状态和明确标记为“预留”的占位内容；“个性化”进入 `PersonalizationScreen`，左下角设置按钮进入 `SettingsHubScreen`。

## 主题与视觉

- `ThemeNotifier` 三态循环：light -> dark -> system，首次启动默认 `system`。
- Widget 优先通过 `ThemeContext` 取颜色和文字样式，例如 `context.primaryColor`、`context.surfaceColor`、`context.textTitleMedium`；不要直接引用 `AppTheme.primaryText` 等静态颜色做 UI。
- 深色背景 `#121212` / `#1E1E1E`，正文 `#E0E0E0`，标题 `#FFFFFF`，辅助文字 `#9E9E9E`；避免纯黑 `#000000`。
- `context.primaryColor` 是主文字色，不可做按钮、图标容器、圆形底等背景；深色模式应使用 `context.surfaceColor` 做底、`context.primaryColor` 做前景。
- Toast 统一用 `lib/utils/app_toast.dart` 的 `showAppToast(...)`，不要散落 `ScaffoldMessenger.showSnackBar(...)`。
- Toast 宽度应按文案自适应，优先用 `BoxConstraints` 让文本自然布局，不要用 `TextPainter` 手算容器宽度；少于 10 个字保持单行完整显示，10 个字及以上才允许最多两行，避免短提示提前省略。
- 封面取色由 `AlbumVisualPalette` 处理，缓存键含 brightness；动态背景尽量使用稳定 `coverArtId`，避免认证 URL 刷新导致重复取色。
- 播放详情页/歌词页背景由 `DynamicAlbumBackground` 统一实现；`VisualEffectNotifier` 持久化 `BackgroundVisualStyle`（流动光影/静态渐变）。流动光影用 `CustomPainter` + `sin/cos` 闭环轨迹绘制柔和光晕，避免每帧全屏 `BackdropFilter` 高斯模糊导致掉帧；静态渐变应停止动画控制器。

## 曲库、播放与歌词

- 启动从安全存储恢复 Navidrome 凭据；认证恢复后等待依赖 Provider 重建，再刷新曲库。启动遮罩应覆盖凭据读取和 `PlayerNotifier` 本地播放会话恢复，避免主界面先显示无 MiniPlayer/Dock 状态再闪现播放栏。
- `refreshLibrary()` 并行刷新专辑、全量歌曲和收藏。专辑用 `getAlbumList2.view` 分页；全量歌曲用空查询 `search3.view` + `songOffset` 分页。
- 收藏采用共享状态和乐观更新，失败回滚；收藏页无需手动刷新即可同步。
- 播放器使用 `just_audio` 多曲目音源序列；搜索、收藏、专辑、全曲库歌曲都会用当前集合建立真实队列。`PlayerNotifier.playAtIndex()` 是切歌和队列点选统一入口。
- 用户明确要求：不要恢复异常自动下一首、回跳和额外 seek 保护逻辑；播放链路尽量单纯地从 Navidrome `stream.view&format=raw` 播放。
- 切歌时后台预取当前歌曲和下一首歌词并写入本地 JSON 缓存；不承诺应用进程彻底关闭后恢复完整队列和进度。
- 歌词缓存键按 `baseUrl + username + song.id` 作用域生成；空歌词也要短期缓存。失败后移除内存 Future 缓存。
- `LyricsScreen` 初始化后应立即加载内容，不要等横滑动画完成才 load。
- 迷你播放栏中间区域显示当前句歌词和下一句歌词，不显示歌名/歌手；换句时下一句应向上滚到当前句位置，并淡入淡出，不要整块刷新。当前句长歌词可显示两行。
- 迷你播放栏歌词静止态和滚动态要共用同一套垂直轨道。间距应按文本实际高度和可用宽度自适应；动画时长应按相邻歌词时间差动态调整，避免短句切换时瞬移。

## 播放页与选曲模式

- 播放页爱心、更多、播放队列等操作按钮普通态要与播放控制按钮统一使用 `context.primaryColor`（浅色偏黑、深色偏白）；收藏态保留 `context.favoriteRedColor`，禁用态只降透明度。
- 波形进度条为等长离散短柱 + 涟漪行波动画，非 PCM 振幅；颜色由当前视觉歌曲的 `AlbumVisualPalette` 驱动，并通过亮暗模式可读性校正后使用。
- 波形进度条已播放区要持续染上当前动态取色；拖动时用手指位置对应的显示进度作为染色边界，颜色必须随拖动实时变化。
- 播放页点击下一首/上一首时封面使用非线性横向切换动画：下一首为当前封面向左完全移出屏幕、新封面从右侧进入；上一首方向相反。离场封面边缘必须完全离开屏幕后再清理状态，不能在屏幕边缘残留一截后瞬间消失。
- 长按播放页封面进入选曲模式；左右滑动只切换候选，不立即播放；点击中央封面确认 `playAtIndex()`，点击空白取消。
- 待选封面应由屏幕边界自然截断，不得被封面槽、当前封面、局部 `ClipRect` 或可见遮罩/亮色槽截断。
- 选曲模式下标题、艺人、动态背景和波形颜色跟随候选歌曲；逻辑通过 `nowPlayingVisualSong(...)` 统一选择视觉歌曲。选曲逻辑保留在 `lib/screens/now_playing_screen.dart` 的 `_NowPlayingScreenState`，不拆额外组件。

## 设置、下载与缓存

- 设置入口：主页右滑侧边栏左下角设置按钮 -> `SettingsHubScreen`。刷新曲库走 `libraryProvider.notifier.refreshLibrary()`；未连接时不误报成功，刷新中禁用重复点击。
- 缓存统计/清理由 `CacheRepository` 和各 bucket 管理，耗时目录统计用 `Isolate.run`，避免阻塞 UI。离线下载只跳转下载管理，避免误删。
- 图片显示优先使用 `CachedDiskImage`：先用稳定 `cacheKey` 查磁盘命中再走网络。专辑/歌曲封面 key 用稳定 `coverArtId`；歌手头像不要用 `String.hashCode` 做持久 key。
- Subsonic 封面 URL 每次会因随机 salt/token 变化；新封面/头像 UI 不要直接用 `CachedNetworkImage`。
- `AppCacheService` 管理小型 JSON 缓存。不要在实例方法里用捕获实例字段的 `Isolate.run(() => jsonEncode(value))`。
- 自动清理 Slider 档位：500MB / 1GB / 2GB / 5GB / 无限制。上限写入 secure storage，并同步写 `cache_settings` JSON 兜底；启动时先加载设置再允许刷新统计。

## 构建与验证

- 静态分析：`dart analyze lib test` 或 `flutter analyze`。
- 测试：`flutter test`。常用单测：`flutter test test/widget_test.dart`、`flutter test test/now_playing_visual_song_test.dart`、`flutter test test/cache_provider_test.dart`、`flutter test test/lyrics_provider_test.dart`。
- `test/widget_test.dart` 里设置页用例目前仍期待旧文案 `关于 Joyal Music`，当前 `SettingsHubScreen` 实际为 `关于 Joyal`；若只改无关交互，遇到该失败先确认是否为既有测试文案滞后。
- 侧边栏手势回归：`Home content does not scroll vertically while opening sidebar`、`Home sidebar closes on a fast left fling`。
- 播放页视觉/歌词手势回归：`test/now_playing_visual_song_test.dart`。
- APK 复核默认只构建 arm64 Release：`flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`。
- Release 输出：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。`--no-tree-shake-icons` 用于绕过当前项目遇到的图标树摇构建问题。

## 协作边界

- 认证解析、模型解析、播放器状态仍缺单元测试。
- 空查询 `search3.view` 枚举全库需继续在不同 Navidrome/Subsonic 服务上验证。
- Web CORS、iOS 真机局域网权限提示、不同服务端响应版本需要实机联调。
- 旧文件里可能有中文乱码；不要因为 PowerShell 显示乱码就批量重写无关代码。需要读中文文件时优先显式使用 UTF-8。
- 用户通常通过实机截图反馈 UI；改动后优先构建 arm64 Release APK 供复核。
- 添加 UI 操作前先确认 provider/service 已有对应能力，不把占位 UI 描述为完成。
- 保留用户已有修改，只改任务范围内文件。遇到厂商 SDK、账号、远程服务等外部依赖时，明确区分“已预留/已桥接”和“已真实接入”。
- 项目记忆允许继续适度精简：保留会影响实现判断的约束、路径、命令和坑点；删掉过时流水账和已能从代码直接读出的细枝末节。
