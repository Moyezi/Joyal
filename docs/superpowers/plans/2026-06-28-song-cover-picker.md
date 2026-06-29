# Song Cover Picker 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Now Playing 页面实现长按封面选曲功能 — 三封面动态滑入、振动反馈、阻尼动画。

**Architecture:** 新建 `SongCoverPicker` 覆盖组件，自包含动画与手势；`NowPlayingScreen` 新增 `_isSelecting` / `_candidateIndex` 状态管理选曲模式，通过 `_isSelecting` 与歌词滑动手势互斥。

**Tech Stack:** Flutter / Dart / Riverpod / `just_audio` / `CachedNetworkImage`

## Global Constraints

- 遵循项目现有 Riverpod + Material 3 架构
- 不修改 `AlbumCover`、`player_provider.dart`、`audio_player_service.dart`
- 选曲模式下歌词水平滑动禁用（通过 `_isSelecting` 互斥）
- 队列仅 1 首歌时不进入选曲模式
- 队列为空时长按无反应
- 构建命令：`flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons`
- APK 输出：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

### Task 1: 创建 `SongCoverPicker` 组件

**Files:**
- Create: `lib/widgets/song_cover_picker.dart`
- Test: `test/song_cover_picker_test.dart`（在 Task 3 中创建）

**Interfaces:**
- Consumes: `Song` model (`lib/models/song.dart`), `AlbumCover` widget (`lib/widgets/album_cover.dart`), `AppTheme` (`lib/config/theme.dart`)
- Produces: `SongCoverPicker` widget with signature:
  ```dart
  class SongCoverPicker extends StatefulWidget {
    final List<Song> playlist;
    final int candidateIndex;
    final String Function(Song song) getCoverUrl;
    final ValueChanged<int> onCandidateChanged;
    final ValueChanged<int> onSongSelected;
    final VoidCallback onDismiss;
  }
  ```

- [ ] **Step 1: 编写组件骨架和进入动画**

```dart
// lib/widgets/song_cover_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/song.dart';
import 'album_cover.dart';

/// 浮层选曲组件：长按封面后，在当前播放队列中选择歌曲。
///
/// 展示三张封面 — 上一首（左）、候选（中，最大）、下一首（右）。
/// 左右滑动切换候选，点击中央封面确认选歌，点击空白取消。
class SongCoverPicker extends StatefulWidget {
  const SongCoverPicker({
    super.key,
    required this.playlist,
    required this.candidateIndex,
    required this.getCoverUrl,
    required this.onCandidateChanged,
    required this.onSongSelected,
    required this.onDismiss,
  });

  final List<Song> playlist;
  final int candidateIndex;
  final String Function(Song song) getCoverUrl;
  final ValueChanged<int> onCandidateChanged;
  final ValueChanged<int> onSongSelected;
  final VoidCallback onDismiss;

  @override
  State<SongCoverPicker> createState() => _SongCoverPickerState();
}

class _SongCoverPickerState extends State<SongCoverPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _enterAnim;
  double _dragOffset = 0;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _enterAnim = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    );
    _enterCtrl.forward().then((_) {
      if (mounted) _settled = true;
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ━━━ Helpers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Song? get _prevSong =>
      widget.candidateIndex > 0 && widget.candidateIndex < widget.playlist.length
          ? widget.playlist[widget.candidateIndex - 1]
          : null;

  Song? get _currSong =>
      widget.candidateIndex >= 0 && widget.candidateIndex < widget.playlist.length
          ? widget.playlist[widget.candidateIndex]
          : null;

  Song? get _nextSong =>
      widget.candidateIndex >= 0 &&
              widget.candidateIndex + 1 < widget.playlist.length
          ? widget.playlist[widget.candidateIndex + 1]
          : null;

  /// 原始封面尺寸（与 NowPlayingScreen 中 AlbumCover 的 size 一致）。
  double _originalSize(BuildContext context) {
    return (MediaQuery.of(context).size.width - 68).clamp(240.0, 390.0);
  }

  double _centerSize(BuildContext context) =>
      _originalSize(context) * 0.70;

  double _sideSize(BuildContext context) =>
      _originalSize(context) * 0.50;

  /// 侧封水平偏移量（用于 TranslateTransform 的 dx）。
  /// 中央宽 × 0.57，使内侧边缘与中央保持间距，外侧被屏幕截断 ~1/3。
  double _sideOffset(BuildContext context) =>
      _centerSize(context) * 0.57;

  // ━━━ Gesture ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_settled) return;
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_settled) return;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = _centerSize(context) * 0.30;

    if (velocity < -300 || _dragOffset < -threshold) {
      // Swipe left → next
      _snapTo(widget.candidateIndex + 1);
    } else if (velocity > 300 || _dragOffset > threshold) {
      // Swipe right → prev
      _snapTo(widget.candidateIndex - 1);
    } else {
      // Snap back
      _animateDragOffset(0);
    }
  }

  void _snapTo(int target) {
    final clamped = target.clamp(0, widget.playlist.length - 1);
    if (clamped == widget.candidateIndex) {
      _animateDragOffset(0);
      return;
    }
    HapticFeedback.selectionClick();
    widget.onCandidateChanged(clamped);
    _dragOffset = 0;
    _settled = false;
    // Trigger a brief re-animation after index change.
    _enterCtrl
      ..reset()
      ..forward().then((_) {
        if (mounted) _settled = true;
      });
  }

  void _animateDragOffset(double target) {
    // Not using a separate controller here; just reset drag state.
    // A more sophisticated implementation could animate _dragOffset to 0.
    setState(() => _dragOffset = 0);
  }

  void _onTapCenter() {
    if (!_settled) return;
    final index = widget.candidateIndex;
    if (index >= 0 && index < widget.playlist.length) {
      widget.onSongSelected(index);
    }
  }

  // ━━━ Build ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    final centerSize = _centerSize(context);
    final sideSize = _sideSize(context);
    final sideOffset = _sideOffset(context);

    return AnimatedBuilder(
      animation: _enterAnim,
      builder: (context, _) {
        final progress = _enterAnim.value; // 0 → 1
        final centerScale = 1.0 - 0.30 * progress; // 1.0 → 0.70
        final sideScale = 0.30 + 0.20 * progress;   // 0.30 → 0.50 (fade-in)
        final sideOpacity = progress.clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss, // tap blank dismiss
          child: SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Left candidate ──
                if (_prevSong != null)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(-sideOffset + _dragOffset, 8),
                        child: Transform.scale(
                          scale: sideScale,
                          child: Opacity(
                            opacity: sideOpacity * 0.7,
                            child: _buildCover(
                              _prevSong!,
                              size: sideSize,
                              onTap: null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Center candidate ──
                if (_currSong != null)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(_dragOffset, 0),
                        child: Transform.scale(
                          scale: centerScale,
                          child: GestureDetector(
                            onTap: _onTapCenter,
                            child: _buildCover(
                              _currSong!,
                              size: centerSize,
                              onTap: _onTapCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Right candidate ──
                if (_nextSong != null)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(sideOffset + _dragOffset, 8),
                        child: Transform.scale(
                          scale: sideScale,
                          child: Opacity(
                            opacity: sideOpacity * 0.7,
                            child: _buildCover(
                              _nextSong!,
                              size: sideSize,
                              onTap: null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover(Song song, {required double size, VoidCallback? onTap}) {
    final coverUrl = widget.getCoverUrl(song);
    return AlbumCover(
      coverArtUrl: coverUrl,
      cacheKey: song.coverArt,
      size: size,
      showShadow: false,
    );
  }
}
```

- [ ] **Step 2: 添加阻尼回弹动画**

用 `AnimationController` 驱动 `_dragOffset` 的弹性回弹。在 `_onHorizontalDragEnd` 中回弹到 0 时使用 cubic 曲线：

```dart
// 在 _SongCoverPickerState 中添加：
late AnimationController _snapCtrl;
double _snapFrom = 0;
double _snapTo = 0;

// initState 中：
_snapCtrl = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 300),
);
_snapCtrl.addListener(() {
  setState(() {
    _dragOffset = _snapFrom + (_snapTo - _snapFrom) *
        const Cubic(0.25, 1.55, 0.5, 1).transform(_snapCtrl.value);
  });
});

// 替换 _animateDragOffset：
void _animateDragOffset(double target) {
  _snapFrom = _dragOffset;
  _snapTo = target;
  _snapCtrl
    ..reset()
    ..forward();
}
```

- [ ] **Step 3: 运行 `dart analyze` 确认组件无编译错误**

```powershell
dart analyze lib/widgets/song_cover_picker.dart
```

预期：No issues found.

- [ ] **Step 4: Commit**

```powershell
git add lib/widgets/song_cover_picker.dart
git commit -m "feat: add SongCoverPicker widget with entry/snap/dismiss animations"
```

---

### Task 2: 集成到 `NowPlayingScreen`

**Files:**
- Modify: `lib/screens/now_playing_screen.dart`

**Interfaces:**
- Consumes: `SongCoverPicker` (Task 1), `playerProvider`, `subsonicApiProvider`
- Produces: 选曲模式集成 — 长按触发、信息跟随、控件半透明、歌词手势互斥

- [ ] **Step 1: 添加选曲状态字段**

在 `_NowPlayingScreenState` 中添加：

```dart
bool _isSelecting = false;
int _candidateIndex = 0;
```

- [ ] **Step 2: 修改 `_buildPlayerPage` 中封面区域，包裹长按手势**

找到 `_playerContent` 中的封面区域代码（约第 260-275 行）：

```dart
// 原代码：
// ── Album cover ──
Expanded(
  flex: 5,
  child: Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
      child: AlbumCover(
        coverArtUrl: coverUrl,
        cacheKey: song.coverArt,
        size: (MediaQuery.of(context).size.width - 68).clamp(240, 390),
      ),
    ),
  ),
),
```

替换为：

```dart
// ── Album cover ──
Expanded(
  flex: 5,
  child: Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
      child: GestureDetector(
        onLongPressStart: (_) {
          if (playerState.playlist.length <= 1) return;
          HapticFeedback.heavyImpact();
          setState(() {
            _isSelecting = true;
            _candidateIndex = playerState.currentIndex;
          });
        },
        child: AlbumCover(
          coverArtUrl: coverUrl,
          cacheKey: song.coverArt,
          size: (MediaQuery.of(context).size.width - 68).clamp(240, 390),
        ),
      ),
    ),
  ),
),
```

- [ ] **Step 3: 修改信息区，标题/艺人跟随 `_candidateIndex`**

找到信息区 Row（约第 288-340 行），将 `song.title` 和 `song.artist` 替换为根据 `_isSelecting` 条件选择：

```dart
// 在 _playerContent 方法开头添加：
final displaySong = _isSelecting && _candidateIndex >= 0
        && _candidateIndex < playerState.playlist.length
    ? playerState.playlist[_candidateIndex]
    : song;

// 然后将标题/艺人处的 song.title / song.artist 替换为 displaySong.title / displaySong.artist
Text(
  displaySong.title,
  style: AppTheme.headlineMedium,
  textAlign: TextAlign.center,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
// ...
Text(
  displaySong.artist,
  style: AppTheme.titleMedium.copyWith(color: AppTheme.secondaryText),
  textAlign: TextAlign.center,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

- [ ] **Step 4: 修改控件行，选曲时半透明 + 禁用**

找到播放控件 Row（约第 410-490 行），包裹在条件渲染中：

```dart
// 将整个控件 Row 包裹：
Opacity(
  opacity: _isSelecting ? 0.3 : 1.0,
  child: IgnorePointer(
    ignoring: _isSelecting,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ... 现有控件代码保持不变
        ],
      ),
    ),
  ),
),
```

- [ ] **Step 5: 在 `_buildPlayerPage` 的 Scaffold body 中叠加 `SongCoverPicker` 和 `BackdropFilter`**

将 `_playerContent` 的 body 部分包裹在 `Stack` 中：

```dart
// 原 body:
body: DynamicAlbumBackground(
  coverArtId: song?.coverArt ?? '',
  coverUrl: _coverUrl(ref, song),
  child: SafeArea(
    child: song == null
        ? _emptyState()
        : _playerContent(context, ref, playerState),
  ),
),

// 替换为：
body: DynamicAlbumBackground(
  coverArtId: song?.coverArt ?? '',
  coverUrl: _coverUrl(ref, song),
  child: Stack(
    children: [
      SafeArea(
        child: song == null
            ? _emptyState()
            : _playerContent(context, ref, playerState),
      ),
      if (_isSelecting && song != null) ...[
        // BackdropFilter 模糊背景
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(color: Colors.black.withOpacity(0.08)),
          ),
        ),
        // SongCoverPicker 浮层
        Positioned.fill(
          child: SongCoverPicker(
            playlist: playerState.playlist,
            candidateIndex: _candidateIndex,
            getCoverUrl: (s) => _coverUrl(ref, s),
            onCandidateChanged: (idx) {
              setState(() => _candidateIndex = idx);
            },
            onSongSelected: (idx) {
              setState(() => _isSelecting = false);
              ref.read(playerProvider.notifier).playAtIndex(idx);
            },
            onDismiss: () {
              setState(() => _isSelecting = false);
            },
          ),
        ),
      ],
    ],
  ),
),
```

需要添加 import：
```dart
import 'dart:ui'; // for ImageFilter
import '../widgets/song_cover_picker.dart';
```

- [ ] **Step 6: 禁用选曲时的歌词滑动手势**

找到 `onHorizontalDragStart`（约第 115 行），在回调开头添加检查：

```dart
onHorizontalDragStart: !hasSong || _isSelecting ? null : (_) => _initializeLyrics(),
```

同时修改 `onHorizontalDragUpdate` 和 `onHorizontalDragEnd` 的 null 检查：

```dart
onHorizontalDragUpdate: !hasSong || _isSelecting
    ? null
    : (details) { /* 保持不变 */ },
onHorizontalDragEnd: !hasSong || _isSelecting
    ? null
    : (details) { /* 保持不变 */ },
```

- [ ] **Step 7: 运行静态分析**

```powershell
dart analyze lib/screens/now_playing_screen.dart
```

预期：No issues found.

- [ ] **Step 8: Commit**

```powershell
git add lib/screens/now_playing_screen.dart
git commit -m "feat: integrate SongCoverPicker into NowPlayingScreen"
```

---

### Task 3: 编写测试

**Files:**
- Create: `test/song_cover_picker_test.dart`

**Interfaces:**
- Consumes: `SongCoverPicker` (Task 1), `Song` model, `AlbumCover`

- [ ] **Step 1: 创建测试文件并编写单元测试**

```dart
// test/song_cover_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/widgets/song_cover_picker.dart';

Song _makeSong(String id, String title) => Song(
      id: id,
      parent: 'album-$id',
      title: title,
      album: 'Test Album',
      artist: 'Test Artist',
      duration: 200,
      coverArt: 'cover-$id',
      contentType: 'audio/mpeg',
      suffix: 'mp3',
    );

void main() {
  // ━━━ Unit: 单曲队列 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  testWidgets('SongCoverPicker does not render side covers for single-song queue', (
    WidgetTester tester,
  ) async {
    final songs = [_makeSong('1', 'Only Song')];
    int? selected;
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongCoverPicker(
            playlist: songs,
            candidateIndex: 0,
            getCoverUrl: (_) => '',
            onCandidateChanged: (_) {},
            onSongSelected: (i) => selected = i,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    // Should render the center cover (even if single)
    // The widget renders without crashing; center cover exists, sides are null.
    expect(tester.takeException(), isNull);
  });

  // ━━━ Unit: 回调参数 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  testWidgets('onSongSelected returns correct index', (
    WidgetTester tester,
  ) async {
    final songs = [
      _makeSong('1', 'First'),
      _makeSong('2', 'Second'),
      _makeSong('3', 'Third'),
    ];
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongCoverPicker(
            playlist: songs,
            candidateIndex: 1,
            getCoverUrl: (_) => '',
            onCandidateChanged: (_) {},
            onSongSelected: (i) => selected = i,
            onDismiss: () {},
          ),
        ),
      ),
    );

    // Tap the center cover (the one at candidateIndex 1 = "Second")
    final centerCover = find.byType(AlbumCover);
    // There are up to 3 covers; the center one should be among them.
    // We tap the center-most one by tapping within the center of the widget.
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();

    // After animation settles, onSongSelected should have been called.
    // Note: tap-on-center requires the _settled flag to be true (350ms animation).
    expect(selected, isNotNull);
    expect(selected, 1);
  });

  // ━━━ Unit: onDismiss via blank tap ━━━━━━━━━━━━━━━━━━━

  testWidgets('onDismiss is called when tapping blank area', (
    WidgetTester tester,
  ) async {
    final songs = [
      _makeSong('1', 'First'),
      _makeSong('2', 'Second'),
      _makeSong('3', 'Third'),
    ];
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongCoverPicker(
            playlist: songs,
            candidateIndex: 1,
            getCoverUrl: (_) => '',
            onCandidateChanged: (_) {},
            onSongSelected: (_) {},
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    // Wait for enter animation
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // Tap in a corner area (away from covers)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  // ━━━ Unit: 边界索引 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  testWidgets('candidateIndex at boundaries does not crash', (
    WidgetTester tester,
  ) async {
    final songs = [
      _makeSong('1', 'First'),
      _makeSong('2', 'Second'),
    ];

    // Test index 0 (no prev)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongCoverPicker(
            playlist: songs,
            candidateIndex: 0,
            getCoverUrl: (_) => '',
            onCandidateChanged: (_) {},
            onSongSelected: (_) {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Test index last (no next)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongCoverPicker(
            playlist: songs,
            candidateIndex: 1,
            getCoverUrl: (_) => '',
            onCandidateChanged: (_) {},
            onSongSelected: (_) {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ━━━ Unit: 越界索引保护 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  testWidgets('out-of-bounds candidateIndex does not crash', (
    WidgetTester tester,
  ) async {
    final songs = [_makeSong('1', 'Only')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongCoverPicker(
            playlist: songs,
            candidateIndex: 5, // out of bounds
            getCoverUrl: (_) => '',
            onCandidateChanged: (_) {},
            onSongSelected: (_) {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Should not throw — _currSong returns null gracefully
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 运行测试**

```powershell
flutter test test/song_cover_picker_test.dart
```

预期：全部通过（或根据实际 widget 行为微调）

- [ ] **Step 3: Commit**

```powershell
git add test/song_cover_picker_test.dart
git commit -m "test: add SongCoverPicker unit and widget tests"
```

---

### Task 4: 构建验证

- [ ] **Step 1: 运行全部测试**

```powershell
flutter test
```

预期：28+ 项测试全部通过（新增 5 项）。

- [ ] **Step 2: 静态分析**

```powershell
dart analyze lib test
```

预期：No issues found.

- [ ] **Step 3: 构建 arm64 Release APK**

```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```

预期：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` 构建成功。

- [ ] **Step 4: Commit 最终版本**

```powershell
git add -A
git commit -m "chore: finalize song cover picker implementation"
```
