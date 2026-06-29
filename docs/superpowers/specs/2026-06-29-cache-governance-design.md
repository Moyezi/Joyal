# 全面缓存治理 — 设计文档

> 日期：2026-06-29 | 状态：待审核

## 1. 目标

将 Joyal Music 的所有缓存类型（临时音频、图片封面、歌词元数据、离线下载、专辑详情、艺人数据、搜索历史与结果）纳入统一的缓存管理体系，实现：

- 每种缓存独立可见的容量统计
- 按类型手动清理
- 统一总容量上限 + 按类型开关的自动清理
- 专辑详情、艺人页、搜索结果采用「缓存优先」加载策略

## 2. 架构

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  CacheManagementScreen  │  AlbumDetail / Artist  │
│                          │  / Search              │
└────────────┬───────────────┬─────────────────────┘
             │ 读取统计/清理  │ 读缓存 / 写缓存
             ▼               ▼
┌─────────────────────────────────────────────────┐
│            CacheRepository (单例)                │
│  · 注册所有 CacheBucket                          │
│  · 聚合统计 → CacheStats                        │
│  · 统一自动清理（总上限 + 分类开关）              │
│  · 提供数据存取便利方法                          │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ StreamBucket │ ImageBucket │ MetaBucket           │
│ DownloadBucket │ AlbumBucket │ ArtistBucket       │
│ SearchBucket                                     │
│ (均实现 CacheBucket 接口)                         │
└─────────────────────────────────────────────────┘
```

### 2.1 新增文件

- `lib/services/cache_repository.dart` — 仓库中枢
- `lib/services/cache_bucket.dart` — 统一接口定义
- `lib/services/buckets/stream_cache_bucket.dart`
- `lib/services/buckets/image_cache_bucket.dart`
- `lib/services/buckets/meta_cache_bucket.dart`
- `lib/services/buckets/download_cache_bucket.dart`
- `lib/services/buckets/album_cache_bucket.dart`
- `lib/services/buckets/artist_cache_bucket.dart`
- `lib/services/buckets/search_cache_bucket.dart`

### 2.2 重构文件

- `lib/providers/cache_provider.dart` — 改为依赖 `CacheRepository`
- `lib/screens/cache_management_screen.dart` — UI 扩展至 7 类
- `lib/services/cache_stats_service.dart` — 逻辑下沉到各 bucket，可废弃
- `lib/services/app_cache_service.dart` — JSON 存取迁移到对应 bucket
- `lib/providers/library_provider.dart` — 专辑/艺人接入缓存优先
- `lib/screens/search_screen.dart` / `lib/providers/search_provider.dart` — 搜索接入缓存优先

## 3. CacheBucket 接口

### 3.1 基础接口

```dart
abstract class CacheBucket {
  String get id;
  String get label;
  IconData get icon;

  Future<int> calculateSize();        // Isolate 递归扫描，返回字节数
  Future<void> clear();               // 清空全部
  Future<void> pruneByLru(int targetBytes); // LRU 至目标字节以下

  bool autoCleanEnabled;              // 是否参与自动清理，默认 true
}
```

### 3.2 数据型 Bucket 扩展

```dart
abstract class DataCacheBucket<T> extends CacheBucket {
  Future<T?> load(String key);
  Future<void> save(String key, T data);
  Future<void> remove(String key);
  Future<List<String>> keys();
}
```

### 3.3 七个 Bucket 清单

| Bucket | 类型 | 存储内容 | 存储位置 |
|--------|------|---------|---------|
| `StreamBucket` | 文件型 | just_audio 临时音频 | `temp/exo/` |
| `ImageBucket` | 文件型 | 封面 + 图片缓存 | `temp/libCachedImageData/` + DefaultCacheManager |
| `MetaBucket` | 文件型 | 歌词 JSON + 现有元数据 | `appSupport/cache/*.json`（排除 album/ / artist/ / search/ 子目录） |
| `DownloadBucket` | 文件型 | 离线下载文件 | `Documents/Joyal DL/` / MediaStore |
| `AlbumBucket` | 数据型 | 专辑歌曲列表 JSON | `appSupport/cache/album/` |
| `ArtistBucket` | 数据型 | 艺人详情+歌曲 JSON | `appSupport/cache/artist/` |
| `SearchBucket` | 数据型 | 搜索历史+结果 JSON | `appSupport/cache/search/` |

> **目录隔离规则**：`MetaBucket.calculateSize()` 扫描 `appSupport/cache/` 根目录的 `*.json`，跳过 `album/`、`artist/`、`search/` 三个子目录，避免与数据型 bucket 重复统计。

## 4. CacheRepository

```dart
class CacheRepository {
  final List<CacheBucket> _buckets = [
    StreamBucket(), ImageBucket(), MetaBucket(),
    DownloadBucket(), AlbumBucket(), ArtistBucket(), SearchBucket(),
  ];

  // 查询
  Future<CacheStats> getStats();     // 并行聚合 7 个 bucket 大小
  CacheBucket? bucket(String id);

  // 操作
  Future<void> clearBucket(String id);
  Future<void> enforceAutoLimit(int maxBytes); // 跨 bucket LRU

  // 数据存取（转发）
  Future<List<Song>?> loadAlbumSongs(String albumId);
  Future<void> saveAlbumSongs(String albumId, List<Song> songs);
  Future<ArtistDetailData?> loadArtistDetail(String artistId);
  Future<void> saveArtistDetail(String artistId, ArtistDetailData data);
  Future<List<Song>?> loadArtistSongs(String artistName);
  Future<void> saveArtistSongs(String artistName, List<Song> songs);
  Future<List<String>?> loadSearchHistory();
  Future<void> saveSearchHistory(List<String> history);
  Future<SearchResultData?> loadSearchResult(String query);
  Future<void> saveSearchResult(String query, SearchResultData data);
}
```

### 4.1 关键设计决策

- **单例**，通过 Riverpod `cacheRepositoryProvider` 暴露
- **`getStats()` 并行**：`Future.wait` 包裹 7 个 `calculateSize()`，均在 `Isolate.run` 内
- **跨 bucket LRU**：扫描所有 `autoCleanEnabled == true` 的 bucket 目录，按文件修改时间全局排序，从最旧删除直到低于上限
- **数据存取方法**为 thin wrapper，JSON 序列化在各自 bucket 内

## 5. 缓存优先加载策略

### 5.1 通用流程

```
进入页面 → bucket.load(key)
  ├─ 命中 → 立即渲染缓存数据 → 后台发起 API 请求
  │           ├─ 成功 → 写缓存 + 更新 UI
  │           └─ 失败 → 静默保留缓存展示
  └─ 未命中 → 骨架屏 → API 请求
                ├─ 成功 → 写缓存 + 渲染
                └─ 失败 → 错误态 + 重试按钮
```

### 5.2 各页面详情

| 页面 | 缓存 Key | 缓存内容 | 首次进入 | 再次进入 |
|------|---------|---------|---------|---------|
| 专辑详情 | `albumId` | `List<Song>` + 专辑元信息 | 骨架屏 → API → 渲染+写缓存 | 瞬间渲染 → 后台刷新 |
| 艺人页 | `artistId` | 专辑列表 + 歌曲列表 + 头像URL | 骨架屏 → API → 渲染+写缓存 | 瞬间渲染 → 后台刷新 |
| 搜索结果 | `query` (小写trim) | 歌曲列表 + 专辑列表 | 骨架屏 → API → 渲染+写缓存 | 瞬间渲染 → 后台刷新 |
| 搜索历史 | 固定 key `history` | `List<String>` (最多30条) | 空列表 | 历史列表 |

### 5.3 数据新鲜度

- 手动刷新为主，不设自动过期时间
- 后台刷新成功后覆盖缓存和 UI
- 网络失败时，有缓存则静默保留，从未缓存过才展示错误

## 6. 缓存管理页 UI

### 6.1 布局

```
┌──────────────────────────────────────┐
│  AppBar: "缓存管理"                   │
├──────────────────────────────────────┤
│   ┌─── 概览卡片 ──────────────────┐  │
│   │  环形图（7色）                  │  │
│   │  中央：总大小 + "App 缓存"       │  │
│   │  图例：7行（色点+名称+大小）     │  │
│   └──────────────────────────────┘  │
│                                      │
│   ── 分类清理 ────────────────────   │
│   🎵 临时音频      128 MB    [清理]  │
│   🖼️ 图片封面       45 MB    [清理]  │
│   📝 歌词元数据      2 MB    [清理]  │
│   📥 离线下载      320 MB  [查看管理]│
│   💿 专辑缓存       12 MB    [清理]  │
│   🎤 艺人缓存        8 MB    [清理]  │
│   🔍 搜索缓存        1 MB    [清理]  │
│                                      │
│   ── 自动清理 ────────────────────   │
│   总缓存上限：[====○====] 2 GB       │
│   参与类型：[✓]音频 [✓]图片 [ ]元数据 │
│            [✓]专辑 [ ]艺人 [ ]搜索   │
└──────────────────────────────────────┘
```

### 6.2 改动要点

1. **环形图**：从 4 段扩展到 7 段，图例可滚动
2. **分类清理**：从 4 项扩展到 7 项，新增三类点击即清无需确认
3. **自动清理开关**：每 bucket 独立 Checkbox，持久化到 `flutter_secure_storage`
4. **离线下载**：保持跳转到 `DownloadManagerScreen`

## 7. 测试策略

| 层级 | 测试内容 | 文件 |
|------|---------|------|
| Bucket 单元 | `calculateSize`、`clear`、`pruneByLru`、JSON 存取往返 | `test/cache_bucket_test.dart` |
| Repository 单元 | `getStats()` 聚合、`enforceAutoLimit` 跨 bucket LRU、开关过滤、边界 | `test/cache_repository_test.dart` |
| Provider 单元 | `CacheProvider` 通过 Repository 获取统计、触发清理、开关状态 | `test/cache_provider_test.dart` |
| Widget | 7 项列表渲染、环形图 7 段、开关切换、清理按钮触发 | `test/cache_management_screen_test.dart` |
| 加载策略 | 缓存命中/未命中、API 成功/失败时的 UI 行为 | `test/cache_first_loading_test.dart` |

测试原则：
- Bucket 测试使用 `Directory.systemTemp.createTemp()` 隔离
- Repository 测试注入 mock bucket
- Widget 测试使用 `ProviderScope` 包裹 mock Repository
- 复用现有 `flutter test` 基础设施

## 8. 模型变更

### 8.1 CacheStats 扩展

现有 `lib/models/cache_stats.dart` 增加三个字段：

```dart
class CacheStats {
  // ... 现有字段不变 ...
  final int streamBytes;
  final int imageBytes;
  final int metaBytes;
  final int downloadBytes;
  final int albumBytes;    // 新增
  final int artistBytes;   // 新增
  final int searchBytes;   // 新增

  int get totalBytes =>
      streamBytes + imageBytes + metaBytes + downloadBytes +
      albumBytes + artistBytes + searchBytes;

  // copyWith 同步扩展
}
```

### 8.2 自动清理开关持久化

现有自动清理上限 `maxLimitMb` 已存储在 `flutter_secure_storage`（key: `cache_max_limit_mb`）。新增 7 个开关状态，存储 key 格式：

```
cache_auto_clean_stream   → 'true' / 'false'
cache_auto_clean_image    → 'true' / 'false'
cache_auto_clean_meta     → 'true' / 'false'
cache_auto_clean_album    → 'true' / 'false'
cache_auto_clean_artist   → 'true' / 'false'
cache_auto_clean_search   → 'true' / 'false'
```

（`download` 不参与自动清理，无需开关）

默认值：`stream`、`image` 默认 `true`；其余默认 `false`。

## 9. 风险与边界

- **目录隔离**：`MetaBucket` 扫描 `appSupport/cache/*.json` 时须排除 `album/`、`artist/`、`search/` 子目录
- **DownloadBucket** 的 `clear()` 不会删除离线文件（保持跳转下载管理），`pruneByLru` 同样跳过下载
- **SearchBucket** 的搜索历史最多保留 30 条，与现有内存缓存行为一致
- **现有歌词缓存**（`lyrics_service.dart` 的 30 天 prune 逻辑）保留不变，仅统计纳入 `MetaBucket`
- **艺人头像**非磁盘缓存重点，仅缓存艺人详情 JSON（含头像 URL），图片本身由 `ImageBucket` 覆盖
- **现有测试兼容**：`CacheStats` 扩展字段后，现有构造调用需补齐默认值（已有默认参数 `= 0` 不受影响）
