# Joyal Music 项目记忆

## 项目定位

Joyal Music 是 iOS/Android Flutter 私人音乐播放器，连接用户自建 Navidrome，通过 Subsonic/OpenSubsonic API 获取曲库、封面、歌词和音频。

视觉方向：极简、沉浸、黑白灰冷色调、大圆角、柔和层次。UI 改动优先保持整体空间关系和观感，不机械复刻单个尺寸。

## 技术与安全

- Flutter / Dart / Material 3，Riverpod 管共享状态；播放用 `just_audio`，请求用 `dio`，封面缓存优先走本地磁盘。
- 凭据、搜索历史、播放进度、主题、页面背景路径、缓存上限、毛玻璃模糊强度和遮罩强度等偏好写入 `flutter_secure_storage`；缓存上限另写 `AppCacheService` JSON 兜底。
- Subsonic 认证使用随机 salt + `md5(password + salt)` token。禁止写入或传输真实明文凭据；公网 Navidrome 优先 HTTPS。
- Android 媒体桥只传播放元数据和本地封面路径，不传流媒体 URL、token、密码或 baseUrl。`OppoFluidCloudBridge` 仅作未来 SDK 预留，当前依赖标准 `MediaSession`。

## 关键路径

- API/播放：`lib/services/subsonic_api.dart`、`lib/services/audio_player_service.dart`、`lib/providers/player_provider.dart`、`lib/providers/listening_stats_provider.dart`。
- 曲库/搜索/发现：首页、曲库、发现（旧 `HotlistScreen` 文件名）、搜索相关代码在 `lib/providers/library_provider.dart` 与 `lib/screens/home_screen.dart`、`library_screen.dart`、`hotlist_screen.dart`、`search_screen.dart`。
- 导航/设置/Dock：`lib/app.dart`、`lib/widgets/home_sidebar.dart`、`mini_player.dart`、`bottom_nav.dart`、`play_queue_sheet.dart`、`lib/screens/settings_hub_screen.dart`、`personalization_screen.dart`、`lib/providers/sidebar_image_provider.dart`。
- 视觉/毛玻璃/背景：`lib/providers/page_background_provider.dart`、`glass_effect_provider.dart`、`visual_effect_provider.dart`、`mini_player_color_provider.dart`、`lib/widgets/frosted_glass.dart`、`glass_top_bar.dart`、`page_custom_background.dart`、`dynamic_album_background.dart`、`album_visual_palette.dart`、`mini_player_chrome.dart`。
- 播放页/歌词：`lib/screens/now_playing_screen.dart`、`lyrics_screen.dart`、`lib/providers/lyrics_provider.dart`、`lyrics_personalization_provider.dart`、`lib/widgets/waveform_progress.dart`、`now_playing_transition.dart`。
- 下载/缓存：`lib/services/app_cache_service.dart`、`cache_repository.dart`、`lib/providers/cache_provider.dart`、`lib/screens/cache_management_screen.dart`、`lib/widgets/cached_disk_image.dart`。
- 智能分类：`lib/models/music_classification.dart`、`lib/services/deepseek_classification_service.dart`、`lib/services/music_classification_repository.dart`、`lib/providers/music_classification_provider.dart`、`lib/screens/music_classification_screen.dart`；发现页入口和卡片在 `hotlist_screen.dart`。
- Android 媒体桥：`android/app/src/main/kotlin/com/example/joyal_music/`。

## 导航与界面约定

- 主导航只有：首页、曲库、发现；搜索从首页大搜索框或顶栏搜索图标进入。旧 widget 测试可能仍按 `主页` 文案断言。
- 主页面用全屏 `Stack` 铺底，固定 `GlassTopBar` 覆盖状态栏，内容从状态栏下方开始并避让顶栏。曲库“歌曲/专辑” TabBar 是顶栏下方额外区域，不应改变标题/按钮位置。
- 根页面在 `lib/app.dart` 用预挂载 sliding stack 承载首页、曲库、发现，避免首次切页才创建目标页导致卡顿；保持屏幕外页面 state，但通过 `TickerMode`、`IgnorePointer`、`ExcludeSemantics` 限制后台动画、交互和语义暴露。`MiniPlayer` 与 `AppBottomNav` 是透明 Dock 上的悬浮胶囊。列表底部 padding 必须动态避让 Dock；有播放栏时额外避让 `MiniPlayer` 高度。
- `AppBottomNav` 区域支持横向拖动切换页面，跨项触发选择振动，页面应从边缘滑入而不是瞬间替换。
- `MiniPlayer` 右滑折叠为右下旋转专辑封面按钮，状态由 `_MainShellState` 管；底部 Dock 区域不触发主页侧边栏右滑。折叠/展开保持固定高度轨道，避免竖向瞬移；动画应让迷你栏整体朝右下悬浮框位置移动并收缩成圆形专辑封面，不用淡入淡出切换两套 UI。
- 歌曲列表行优先复用 `SongTile` + `SongActionsSheet`；“下一首播放”加入队列后要 toast 确认。“查看详情”弹窗承载歌曲文件信息和智能分类轻量修正入口。
- 首页每日推荐：从 `LibraryState.songs` 按当天日期稳定随机选 24 首，栏内 3 首；“查看更多”复用 `PlayQueueSheet`，歌曲卡片复用 `QueueSongCard`，点击推荐歌曲以这 24 首建立真实播放队列。每日推荐、随机专辑等 build 内派生列表要按日期和源列表 identity 缓存，避免切页动画期间重复 shuffle。
- 发现页仍在 `lib/screens/hotlist_screen.dart`，顶部是基于 `LibraryState.songs` 按日期稳定随机的歌曲 Cover Flow：中心封面约 65% 屏宽、24px 圆角，左右各 2～3 张逐级缩小、降低透明度并轻微模糊，卡片部分重叠形成平面克制的景深；不要做明显透视倾斜或传统旋转木马。轮播需支持在封面区域直接横向拖动，首尾用虚拟页循环；快速滑动速度 `<180` 只吸附最近页，`180-1000` 跳 1 张，`1001-2000` 跳 2 张，`>2000` 跳 3 张，并触发轻选择振动。分页圆点当前页蓝紫色、其他浅灰。中心卡右下播放按钮必须跟随真实播放状态在播放/暂停间切换；点击非当前歌曲时以轮播歌曲集合建立真实播放队列。
- 发现页轮播下方保留“收藏歌曲”区块，复用首页每日推荐/播放队列的 `QueueSongCard` 样式；默认只露出少量歌曲，“查看更多”复用 `PlayQueueSheet`，点击收藏歌曲以当前收藏歌曲集合建立真实播放队列。
- 发现页“为你发现”横向卡片优先用本地智能分类标签筛选歌曲；分类不足时只能退化到收藏/随机等真实本地集合，不要展示没有数据支撑的 AI 推荐。发现页顶部轮播、“为你发现”分类扫描、随机漫游等派生列表要缓存，避免页面重建时全曲库重复扫描/洗牌。
- 首页随机专辑：从 `LibraryState.albums` 按当天日期稳定随机选 8 张；“查看更多”切到曲库页并选中“专辑”Tab；底部文案固定 `----到底了----`。
- 首页右滑打开 `HomeSidebar`：侧边栏约 70% 宽，主页内容、MiniPlayer、Dock 随进度右移/缩小/变暗。“最近添加”横向列表是排除区，由 `HomeScreen.onExclusionZoneChanged` 上报。
- 侧边栏动画优先流畅：用 `_drawerController` + `AnimatedBuilder` 驱动预览层，主页面内容作为静态 child/RepaintBoundary；预览层包裹结构必须稳定，拖拽开始时不要临时插入/移除 `ClipRRect` 等父节点，避免主页滚动状态回到初始位置；开合过程中不要用全屏动态 `BackdropFilter`。
- 侧边栏只放真实状态；Navidrome 已连接时不显示整张连接卡，只在标题区显示连接图标，未连接/恢复中才显示提示卡。底部按钮进入设置、个性化或循环主题。
- 侧边栏自定义图片是纯展示区：以 16:9 圆角图片显示，不在侧边栏里放选择/裁切控件；图片选择、清除和 16:9 取景调整入口放在个性化页，状态由 `sidebar_image_provider.dart` 持久化。

## 主题与视觉

- `ThemeNotifier` 三态循环：light -> dark -> system，首次启动默认 `system`。
- Widget 优先通过 `ThemeContext` 取颜色和文字样式；不要直接用 `AppTheme.primaryText` 等静态颜色做 UI。
- 深色背景 `#121212` / `#1E1E1E`，正文 `#E0E0E0`，标题 `#FFFFFF`，辅助文字 `#9E9E9E`；避免纯黑 `#000000`。
- `context.primaryColor` 是主文字色，不可做按钮/图标容器/圆形底等背景；深色模式用 `context.surfaceColor` 做底、`context.primaryColor` 做前景。
- Toast 统一用 `showAppToast(...)`；宽度按文案自适应，优先 `BoxConstraints`，不要用 `TextPainter` 手算。
- 封面取色由 `AlbumVisualPalette` 处理，缓存键含 brightness；动态背景尽量用稳定 `coverArtId`，避免认证 URL 刷新导致重复取色。
- 主页面背景由 `PageBackgroundProvider` + `PageCustomBackground` 管：首页、曲库、发现共用本地图片，不改变列表、顶栏和 Dock 空间关系；内部枚举仍叫 `PageBackgroundTarget.favorites`，显示文案应是“发现”。
- 毛玻璃统一由 `glass_effect_provider.dart` 管模糊强度 `blurFor(...)` 和遮罩强度 `opacityFor(...)`，通用容器用 `FrostedGlass`。`GlassEffectTarget` 包含顶栏、迷你播放栏、搜索框、导航栏、歌曲卡片、歌词页；新增毛玻璃 UI 要接入个性化“毛玻璃”横向预览，并支持模糊/遮罩两条滑杆。
- 迷你播放栏颜色由 `mini_player_color_provider.dart` 控制，个性化可切换“默认颜色/动态取色”；默认保持 `AppTheme.miniPlayerBg`，动态取色复用 `AlbumVisualPalette`，胶囊 tint 和折叠悬浮封面圆形外框需同步遵循，并继续走 `glass_effect_provider.dart` 的 blur/opacity 参数。
- 真实迷你播放栏与个性化“毛玻璃”迷你播放栏预览共用 `mini_player_chrome.dart` 的动态取色解析；预览在动态取色模式下必须跟随当前播放歌曲封面，不要硬编码候选色。未拿到封面 palette 前可暂用中性 fallback，不要用 `coverArtId` hash 伪造候选色，避免与真实封面色调不符。
- 个性化毛玻璃预览用类似 iOS 后台的横向堆叠卡，滑动时触发选择振动；预览背景固定冷色底图和两个大渐变圆。遮罩强度越低越通透、越能透出背景色；不要用整卡 `Opacity` 包住 `BackdropFilter`。
- `GlassTopBar` 保持可独立渲染；主页面从 provider 读取 blur 和 opacity 后通过参数传入，不让顶栏 widget 强依赖外层 `ProviderScope`。
- 播放详情页/歌词页背景由 `DynamicAlbumBackground` 统一实现；流动光影用 `CustomPainter` + `sin/cos`，避免每帧全屏高斯模糊；静态渐变应停止动画控制器。

## 曲库、播放与歌词

- 启动从安全存储恢复 Navidrome 凭据；认证恢复后等待依赖 Provider 重建再刷新曲库。启动遮罩覆盖凭据读取和本地播放会话恢复，避免 MiniPlayer/Dock 闪现。
- `refreshLibrary()` 并行刷新专辑、全量歌曲和收藏。专辑用 `getAlbumList2.view` 分页；全量歌曲用空查询 `search3.view` + `songOffset` 分页。
- 曲库页刷新走 `refreshLibrary()`；发现页顶栏刷新当前仍走 `fetchStarred()` 刷新收藏歌曲，未连接时提示，刷新后用 `showAppToast(...)` 明确成功或失败。
- 曲库页歌曲排序按钮放右上角，与定位当前歌曲、刷新同一行；点击后弹出底部抽屉，提供按添加时间、歌曲语言、歌曲名、艺术家排序，每种都有正序/倒序，选择后关闭并写入 `flutter_secure_storage` 记忆。歌曲名和艺术家排序遇到中文时按开头第一个汉字的拼音首字母排序；点击播放队列和定位当前歌曲都必须使用当前排序后的歌曲列表。
- 曲库歌曲 Tab 为性能采用 UI 层渐进展示：初始约 50 首，接近底部再追加；排序结果按源列表、分类 map 和排序条件缓存。播放、定位当前歌曲、队列建立必须仍使用完整排序后的歌曲列表，不能因为可见数量限制截断真实队列。
- 收藏采用共享状态和乐观更新，失败回滚；发现页的“收藏歌曲”区块无需手动刷新即可同步。
- 播放器使用 `just_audio` 多曲目音源序列；搜索、发现轮播、收藏歌曲、专辑、全曲库歌曲都用当前集合建立真实队列。`PlayerNotifier.playAtIndex()` 是切歌和队列点选统一入口。
- `ListeningStatsNotifier` 只记录本机已听过的去重歌曲 id；侧边栏“听歌概览”进度 = 已听歌曲数 / 当前曲库全部歌曲数，不描述成服务端统计。
- 用户明确要求：不要恢复异常自动下一首、回跳和额外 seek 保护逻辑；播放链路尽量单纯从 Navidrome `stream.view&format=raw` 播放。
- 切歌时后台预取当前歌曲和下一首歌词并写入本地 JSON 缓存；不承诺应用彻底关闭后恢复完整队列和进度。
- 歌词缓存键按 `baseUrl + username + song.id` 作用域生成；空歌词短期缓存，失败后移除内存 Future 缓存。
- `LyricsScreen` 初始化后立即加载，不等横滑动画完成。歌词页不显示返回键和标题“歌词”，顶部只固定当前歌曲名和歌手。
- 歌词页出现或横滑过渡中时，播放详情页外层下滑关闭手势禁用；退出歌词页走现有横滑/切换逻辑。
- 歌词页支持双指捏合打开就地个性化抽屉；偏好由 `lyrics_personalization_provider.dart` 写入 `flutter_secure_storage`，包含歌词颜色（跟随系统/黑/白/动态浅色封面取色）、对齐（居中/左/两端）、字号和字体族（系统/黑体/圆体/手写体）。歌词页毛玻璃的模糊和遮罩强度仍走 `glass_effect_provider.dart`。动态浅色只在选中该模式时才触发封面调色板解析，字体族优先用系统字体 fallback，不引入字体资源时不要承诺特定字体必然命中。
- MiniPlayer 中间区域显示当前句和下一句歌词，不显示歌名/歌手；换句共用同一垂直轨道，动画时长按相邻歌词时间差调整。歌词边界通过 Row 布局、间距、外层 padding/transform 调整，不要在歌词内部 `ClipRect` 里负偏移文本导致左侧截断；当前实机校准为展开态圆形封面左移 `12px`、封面与歌词可视起点间距 `12px`，歌词显示窗口左边界左移 `2px`、右边界左移 `4px`。

## 智能分类

- DeepSeek API Key 只存 `flutter_secure_storage` 的 `deepseek_api_key`，不要写入 SQLite、JSON、日志、崩溃报告或 Git。设置页只显示“已保存”状态，不回显完整 key。
- `MusicClassificationProvider` 管理配置、连接测试、批量分类、暂停/继续/取消、低置信度和强制重分。普通分类会跳过 manual 来源和元数据 hash/模型/词表版本未变化的结果。
- 分类请求只发送歌曲文字元数据（当前 `Song` 模型已有的 id/title/artist/album），不上传音频、封面、Navidrome token、password、baseUrl 或流媒体 URL。
- 固定词表在 `ClassificationVocabulary`；DeepSeek 返回必须校验到词表内，每类最多 3 个标签，能量值限定 0-100，年代当前因 `Song` 未解析年份统一为“年份未知”。
- 当前第一版没有引入 SQLite 依赖；分类配置元数据和分类结果由 `MusicClassificationRepository` 通过 `AppCacheService` 写 `music_classification_store` JSON，本地库边界集中在 repository，后续换 SQLite 时不要改 UI/provider 合同。
- 歌曲“查看详情”里的分类标签支持轻量手动修正：长按已有风格/情绪/场景 tag 触发振动并显示对应完整词表多选；点击语言行显示语言列表单选。保存走 `MusicClassificationNotifier.updateManualClassification()`，写为 `ClassificationSource.manual`，每类仍最多 3 个标签。
- `MusicClassificationScreen` 是真实入口：设置 -> 智能分类，发现页顶部分类状态图标也进入此页。首次分类前若没有 API Key，应引导配置页，不把未配置状态描述为已接入。
- “创建歌单”“相似歌曲”的完整 UI 仍未落地；如果新增按钮，必须先补 provider/service 能力，不能只做占位入口。

## 播放页与选曲模式

- 播放页爱心、更多、播放队列等按钮普通态与播放控制按钮统一用 `context.primaryColor`；收藏态保留 `context.favoriteRedColor`。
- 点击 MiniPlayer 进入播放详情页使用透明 `PageRouteBuilder` + 页面内自绘转场；背景从底部铺满，专辑封面用共享 Hero 从迷你栏圆形头像移动到播放页。
- 迷你栏圆形封面可旋转且跨 Hero/重建保存相位；播放详情页大封面停留态静止。Hero 飞行层负责形状和阴影连续过渡，逻辑在 `now_playing_transition.dart`。
- 迷你栏播放键到播放页主播放键使用共享 Hero；从播放页/歌词页返回时黑底到迷你栏白底需要渐变过渡，不要落位后突然跳色。迷你歌词区不做跨页 Hero 动画。
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
- 侧边栏手势回归：`Home content does not scroll vertically while opening sidebar`、`Home sidebar drag preserves existing home scroll offset`、`Home sidebar closes on a fast left fling`。
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
