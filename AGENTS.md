# Joyal Music 项目记忆

## 项目定位

Joyal Music 是 Flutter iOS/Android 私人音乐播放器，连接用户自建 Navidrome，通过 Subsonic/OpenSubsonic API 获取曲库、封面、歌词和音频。

视觉方向：极简、沉浸、黑白灰冷色调、大圆角、柔和层次。UI 改动优先保持整体空间关系和观感，不机械复刻单个尺寸。

## 技术与安全

- Flutter / Dart / Material 3，Riverpod 管状态；播放 `just_audio`，请求 `dio`，封面优先本地磁盘缓存。
- 凭据、搜索历史、播放进度、主题、页面背景、缓存上限、毛玻璃参数等偏好写入 `flutter_secure_storage`；缓存上限另写 `AppCacheService` JSON 兜底。
- Subsonic 认证使用随机 salt + `md5(password + salt)` token。禁止写入或传输真实明文凭据；公网 Navidrome 优先 HTTPS。
- Android 媒体桥只传播放元数据和本地封面路径，不传流媒体 URL、token、密码或 baseUrl。`OppoFluidCloudBridge` 仅为未来 SDK 预留，当前依赖标准 `MediaSession`。
- DeepSeek API Key 只存 secure storage 的 `deepseek_api_key`，不写 SQLite/JSON/日志/崩溃报告/Git；分类请求只发歌曲文字元数据。

## 关键路径

- API/播放：`lib/services/subsonic_api.dart`、`audio_player_service.dart`、`lib/providers/player_provider.dart`、`listening_stats_provider.dart`。
- 曲库/搜索/发现：`library_provider.dart`、`home_screen.dart`、`library_screen.dart`、`hotlist_screen.dart`、`search_screen.dart`。发现页文件仍叫 `HotlistScreen`。
- 导航/设置/Dock：`lib/app.dart`、`home_sidebar.dart`、`mini_player.dart`、`bottom_nav.dart`、`play_queue_sheet.dart`、`settings_hub_screen.dart`、`personalization_screen.dart`。
- 视觉/毛玻璃/背景：`page_background_provider.dart`、`glass_effect_provider.dart`、`visual_effect_provider.dart`、`mini_player_color_provider.dart`、`frosted_glass.dart`、`glass_top_bar.dart`、`page_custom_background.dart`、`dynamic_album_background.dart`、`album_visual_palette.dart`、`mini_player_chrome.dart`。
- 播放页/歌词：`now_playing_screen.dart`、`lyrics_screen.dart`、`lyrics_provider.dart`、`lyrics_personalization_provider.dart`、`waveform_progress.dart`、`now_playing_transition.dart`。
- 下载/缓存：`app_cache_service.dart`、`cache_repository.dart`、`cache_provider.dart`、`cache_management_screen.dart`、`cached_disk_image.dart`。
- 智能分类：`music_classification.dart`、`deepseek_classification_service.dart`、`music_classification_repository.dart`、`music_classification_provider.dart`、`music_classification_screen.dart`；发现页入口在 `hotlist_screen.dart`。
- Android 媒体桥：`android/app/src/main/kotlin/com/example/joyal_music/`。

## 导航与界面约定

- 主导航只有：首页、曲库、发现；搜索从首页搜索框或顶栏图标进入。旧测试可能仍按 `主页` 文案断言。
- 主页面用全屏 `Stack` 铺底，固定 `GlassTopBar` 覆盖状态栏，内容避让顶栏；曲库 TabBar 是顶栏下方额外区域，不改变标题/按钮位置。
- 根页面在 `lib/app.dart` 预挂载首页/曲库/发现 sliding stack；屏幕外页面保留 state，但用 `TickerMode`、`IgnorePointer`、`ExcludeSemantics` 限制后台动画、交互和语义。
- `MiniPlayer` 与 `AppBottomNav` 是透明 Dock 上的悬浮胶囊；列表底部 padding 动态避让 Dock，有播放栏时额外避让 MiniPlayer。
- BottomNav 支持横向拖动切页、跨项选择振动，页面从边缘滑入。
- MiniPlayer 右滑折叠为右下旋转专辑封面按钮，状态由 `_MainShellState` 管；折叠/展开保持固定高度轨道，整体移动并收缩成圆形封面，不淡入淡出两套 UI。
- 首页右滑打开 `HomeSidebar`：侧边栏约 70% 宽，主页内容/MiniPlayer/Dock 随进度右移、缩小、变暗；最近添加横向列表是排除区。
- 侧边栏动画重视流畅：主页面预览作为稳定 child/RepaintBoundary，拖拽开始不要临时插入/移除父节点，开合中不要用全屏动态 `BackdropFilter`。
- 侧边栏只放真实状态：已连接只在标题区显示连接图标，未连接/恢复中才显示提示卡；自定义图片只展示，选择/清除/16:9 取景在个性化页。

## 首页与发现

- 首页每日推荐：按当天日期从 `LibraryState.songs` 稳定随机选 24 首，栏内 3 首；查看更多复用 `PlayQueueSheet`，卡片复用 `QueueSongCard`，点击用这 24 首建立真实队列。
- 首页随机专辑：按当天日期从 `LibraryState.albums` 稳定随机选 8 张；查看更多切到曲库页并选中“专辑”Tab；底部文案固定 `----到底了----`。
- build 内派生列表（每日推荐、随机专辑、发现轮播、分类扫描、随机漫游等）要按日期和源列表 identity 缓存，避免切页动画期间重复 shuffle/全库扫描。
- 发现页顶部 Cover Flow 基于 `LibraryState.songs` 稳定随机：中心封面约 65% 屏宽、24px 圆角，左右 2-3 张逐级缩小、降透明、轻微模糊，平面克制景深，不做明显透视倾斜。
- Cover Flow 支持封面区域横向拖动和虚拟页循环；快速滑动速度 `<180` 吸附最近页，`180-1000` 跳 1 张，`1001-2000` 跳 2 张，`>2000` 跳 3 张，并轻选择振动。
- 发现页保留“收藏歌曲”区块，复用 `QueueSongCard` 和 `PlayQueueSheet`；点击收藏歌曲以当前收藏集合建立真实队列。
- “为你发现”优先用本地智能分类标签筛歌；分类不足只能退化到收藏/随机等真实本地集合，不展示无数据支撑的 AI 推荐。

## 主题、毛玻璃与性能

- `ThemeNotifier` 三态循环：light -> dark -> system，首次启动默认 `system`。
- Widget 优先通过 `ThemeContext` 取颜色/文字样式；不要直接用 `AppTheme.primaryText` 等静态颜色。深色背景 `#121212` / `#1E1E1E`，避免纯黑。
- `context.primaryColor` 是主文字色，不做按钮/图标容器/圆形底背景；深色模式用 `context.surfaceColor` 做底、`context.primaryColor` 做前景。
- Toast 统一 `showAppToast(...)`，宽度用约束自适应，不用 `TextPainter` 手算。
- 封面取色由 `AlbumVisualPalette` 处理，缓存键含 brightness；动态背景和 provider identity 用稳定 `coverArtId/baseUrl/username`，不要用带随机 token 的 `coverUrl` 做 equality/hash。
- 主页面背景由 `PageBackgroundProvider` + `PageCustomBackground` 管：首页、曲库、发现共用本地图片；内部枚举 `PageBackgroundTarget.favorites` 的显示文案是“发现”。
- 毛玻璃参数统一走 `glass_effect_provider.dart`，通用容器用 `FrostedGlass`。新增毛玻璃 UI 要接入个性化“毛玻璃”横向预览，并支持 blur/opacity 两条滑杆。
- 毛玻璃性能约定：无有效 blur 或遮罩近乎不透明时不要创建 `BackdropFilter`；只模糊自身图片时用 `ImageFiltered`；避免全屏动态 `BackdropFilter`；滑杆拖动实时更新内存、松手再持久化。
- 搜索框、Dock、MiniPlayer、`SongTile`、`QueueSongCard` 等悬浮圆角玻璃组件不要画亮/灰描边，避免边缘出现白线或灰线；`FrostedGlass` 的 `borderOpacity` 为 0 时应彻底不创建 border，个性化预览需同步真实规则。
- 迷你播放栏颜色由 `mini_player_color_provider.dart` 控制；默认 `AppTheme.miniPlayerBg`，动态取色复用 `AlbumVisualPalette`，胶囊 tint 和折叠封面外框同步遵循，并继续走毛玻璃 blur/opacity。
- 真实 MiniPlayer 与个性化预览共用 `mini_player_chrome.dart`；动态取色预览跟随当前播放封面，未拿到 palette 用中性 fallback，不用 `coverArtId` hash 伪造颜色。
- 播放详情页/歌词页背景由 `DynamicAlbumBackground` 统一实现；流动光影用 `CustomPainter` + `sin/cos`，静态渐变停止动画控制器。
- 播放进度是高频状态：不要让 `position` 触发整页、整列表、背景、取色或毛玻璃重建；优先用 `provider.select` 或局部 `Consumer`。

## 曲库、播放与歌词

- 启动从 secure storage 恢复 Navidrome 凭据；认证恢复后等待依赖 Provider 重建再刷新曲库。启动遮罩覆盖凭据读取和本地播放会话恢复，避免 MiniPlayer/Dock 闪现。
- `refreshLibrary()` 并行刷新专辑、全量歌曲和收藏。专辑用 `getAlbumList2.view` 分页；全量歌曲用空查询 `search3.view` + `songOffset` 分页。
- 曲库页刷新走 `refreshLibrary()`；发现页顶栏刷新当前走 `fetchStarred()`，未连接提示，刷新后 toast 明确成功/失败。
- 曲库歌曲排序按钮在右上角，与定位当前歌曲、刷新同一行；排序条件写 secure storage。中文歌曲名/艺术家按开头汉字拼音首字母排序。
- 曲库歌曲 Tab 可 UI 层渐进展示，但播放、定位当前歌曲、队列建立必须使用完整排序列表，不能被可见数量截断。
- 收藏共享状态并乐观更新，失败回滚；发现页收藏区无需手动刷新即可同步。
- 播放器使用 `just_audio` 多曲目音源序列；搜索、发现轮播、收藏、专辑、全曲库歌曲都用当前集合建立真实队列。`PlayerNotifier.playAtIndex()` 是切歌和队列点选统一入口。
- 用户明确要求：不要恢复异常自动下一首、回跳和额外 seek 保护逻辑；播放链路尽量单纯从 Navidrome `stream.view&format=raw` 播放。
- `ListeningStatsNotifier` 只记录本机已听过的去重歌曲 id；侧边栏“听歌概览”进度 = 已听歌曲数 / 当前曲库全部歌曲数。
- 切歌时后台预取当前歌曲和下一首歌词并写入本地 JSON 缓存；不承诺应用彻底关闭后恢复完整队列和进度。
- 歌词缓存键按 `baseUrl + username + song.id` 作用域生成；空歌词短期缓存，失败后移除内存 Future 缓存。
- `LyricsScreen` 初始化后立即加载，不等横滑动画完成。歌词页不显示返回键和标题“歌词”，顶部只固定当前歌曲名和歌手。
- 歌词页出现或横滑过渡中，播放详情页外层下滑关闭手势禁用；退出歌词页走现有横滑/切换逻辑。
- 歌词页双指捏合打开就地个性化抽屉；偏好由 `lyrics_personalization_provider.dart` 写 secure storage，含颜色、对齐、字号、字体。自定义 `.ttf` 用 `file_picker` 选择后复制到应用支持目录并 `FontLoader` 注册；旧黑体/圆体/手写体值回退系统字体。
- MiniPlayer 中间区域显示当前句和下一句歌词，不显示歌名/歌手；换句共用同一垂直轨道，动画时长按相邻歌词时间差调整。歌词布局不要在内部 `ClipRect` 里负偏移导致左侧截断。

## 智能分类

- `MusicClassificationProvider` 管配置、连接测试、批量分类、暂停/继续/取消、低置信度和强制重分。普通分类跳过 manual 来源和元数据 hash/模型/词表版本未变化结果。
- 固定词表在 `ClassificationVocabulary`；DeepSeek 返回必须校验到词表内，每类最多 3 个标签，能量值 0-100，年代因 `Song` 未解析年份统一“年份未知”。
- 当前第一版不引入 SQLite；分类配置和结果由 `MusicClassificationRepository` 通过 `AppCacheService` 写 `music_classification_store` JSON。后续换 SQLite 时不要改 UI/provider 合同。
- 歌曲“查看详情”里的分类标签支持轻量手动修正：长按风格/情绪/场景 tag 显示完整词表多选，点击语言行单选；保存写为 `ClassificationSource.manual`。
- `MusicClassificationScreen` 是真实入口：设置 -> 智能分类，发现页顶部分类状态图标也进入。首次分类前若无 API Key，引导配置页，不把未配置描述成已接入。
- “创建歌单”“相似歌曲”完整 UI 未落地；新增按钮前必须先补 provider/service 能力，不做占位入口。

## 播放页与选曲模式

- 播放页爱心、更多、播放队列等按钮普通态与播放控制按钮统一用 `context.primaryColor`；收藏态保留 `context.favoriteRedColor`。
- 点击 MiniPlayer 进入播放详情页使用透明 `PageRouteBuilder` + 页面内自绘转场；背景从底部铺满，专辑封面 Hero 从迷你栏圆形头像移动到播放页。
- 迷你栏圆形封面可旋转且跨 Hero/重建保存相位；播放详情页大封面停留态静止。Hero 飞行层负责形状和阴影连续过渡，逻辑在 `now_playing_transition.dart`。
- 迷你栏播放键到播放页主播放键使用共享 Hero；从播放页/歌词页返回时黑底到迷你栏白底需要渐变过渡，不要落位后突然跳色。迷你歌词区不做跨页 Hero。
- 波形进度条为等长离散短柱 + 涟漪行波动画，非 PCM 振幅；颜色由当前视觉歌曲取色并按亮暗模式校正，拖动染色边界跟随手指。
- 下一首/上一首封面横向切换：离场封面完全离开屏幕后再清理。
- 长按播放页封面进入选曲模式；左右滑只切候选，不立即播放；点击中央封面确认 `playAtIndex()`，点击空白取消。
- 待选封面由屏幕边界自然截断，不被封面槽、当前封面、局部 `ClipRect` 或遮罩截断。
- 选曲模式下标题、艺人、动态背景和波形颜色跟随候选歌曲；通过 `nowPlayingVisualSong(...)` 统一选择视觉歌曲，逻辑保留在 `_NowPlayingScreenState`。

## 设置、下载与缓存

- 设置入口：主页右滑侧边栏左下角设置按钮 -> `SettingsHubScreen`。刷新曲库走 `libraryProvider.notifier.refreshLibrary()`，未连接不误报成功。
- 缓存统计/清理由 `CacheRepository` 和各 bucket 管理；耗时目录统计用 `Isolate.run`，避免阻塞 UI。离线下载只跳转下载管理，避免误删。
- 图片显示优先 `CachedDiskImage`：先用稳定 `cacheKey` 查磁盘再走网络。专辑/歌曲封面 key 用稳定 `coverArtId`；歌手头像不要用 `String.hashCode` 做持久 key。
- `AppCacheService` 管小型 JSON 缓存；不要在实例方法里用捕获实例字段的 `Isolate.run(() => jsonEncode(value))`。
- 自动清理 Slider 档位：500MB / 1GB / 2GB / 5GB / 无限制。上限写 secure storage，并同步写 `cache_settings` JSON 兜底；启动先加载设置再允许刷新统计。

## 构建与验证

- 静态分析：`dart analyze lib test` 或 `flutter analyze`。
- 测试：`flutter test`。常用：`flutter test test/widget_test.dart`、`test/home_search_animation_test.dart`、`test/now_playing_visual_song_test.dart`、`test/cache_provider_test.dart`、`test/lyrics_provider_test.dart`。
- 侧边栏手势回归：`Home content does not scroll vertically while opening sidebar`、`Home sidebar drag preserves existing home scroll offset`、`Home sidebar closes on a fast left fling`。
- APK 复核默认 arm64 Release：`flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`。
- Release 输出：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。`--no-tree-shake-icons` 用于绕过当前图标树摇构建问题。
- `file_picker` 固定 `10.3.3` 用于歌词自定义 `.ttf`；`11.x` 在当前 Flutter/AGP 组合下会出现 Android 插件类未编入问题，旧 `3.x` 仍用 `jcenter()`。`android/build.gradle.kts` 对 `:file_picker` 统一 Kotlin JVM target 到 11。

## 协作边界

- 认证解析、模型解析、播放器状态仍缺单元测试；空查询 `search3.view` 枚举全库需继续在不同 Navidrome/Subsonic 服务上验证。
- 旧文件可能有中文乱码；不要因 PowerShell 显示乱码批量重写无关代码。读中文文件优先显式 UTF-8。
- 用户通常通过实机截图反馈 UI；改动后优先构建 arm64 Release APK 供复核。
- 添加 UI 操作前先确认 provider/service 已有能力，不把占位 UI 描述为完成。
- 保留用户已有修改，只改任务范围内文件。遇到厂商 SDK、账号、远程服务等外部依赖时，明确区分“已预留/已桥接”和“已真实接入”。
- 项目记忆保持精简：保留会影响实现判断的约束、路径、命令和坑点；删掉过时流水账和能直接从代码读出的细节。
