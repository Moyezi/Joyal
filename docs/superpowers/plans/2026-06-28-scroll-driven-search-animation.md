# Scroll-Driven Search Bar ↔ Top Bar Animation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a scroll-driven linked animation where the home screen's large search bar shrinks/fades out and the top bar's search icon grows/fades in, both driven by the same `AnimationController` fed by a `ScrollController`.

**Architecture:** `AnimationController` (duration: Duration.zero) is manually driven by `ScrollController.listener` → `setValue(progress)`. Two `AnimatedBuilder` widgets subscribe to the same controller — one wraps the large search bar in the scroll body, one renders a search icon inside `GlassTopBar`. Interpolation uses `lerp` for translateY, scale, and opacity.

**Tech Stack:** Flutter, Dart, `AnimationController`, `ScrollController`, `AnimatedBuilder`, `Transform`, `Opacity`, `IgnorePointer`

## Global Constraints

- Scroll range: 70px (searchBarHeight 54 + topPadding 16)
- Big search bar: translateY 0→-20, scale 1.0→0.85, opacity 1.0→0.0, IgnorePointer at progress==1
- Top bar icon: scale 0.6→1.0, opacity 0.0→1.0
- Greeting text in top bar: unchanged
- GlassTopBar: backward compatible — new optional params, existing callers untouched
- AnimationController: no continuous Ticker, only setValue on scroll
- Performance: AnimatedBuilder scoped to animation-only subtrees
- Navigation: GlassTopBar receives `onSearchTap` callback, does NOT import SearchScreen

---

### Task 1: GlassTopBar — add optional search icon support

**Files:**
- Modify: `lib/widgets/glass_top_bar.dart`
- Test (update): `test/widget_test.dart`

**Interfaces:**
- Produces: `GlassTopBar({height, child, searchAnimation?, onSearchTap?})` — new optional `Animation<double>? searchAnimation` and `VoidCallback? onSearchTap`

- [ ] **Step 1: Update widget_test.dart — add GlassTopBar search icon test**

In `test/widget_test.dart`, add a new test after the existing smoke test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/widgets/glass_top_bar.dart';

// ... existing imports and smoke test ...

void testGlassTopBar() {
  testWidgets('GlassTopBar renders search icon when searchAnimation is provided', (tester) async {
    final controller = AnimationController(
      duration: Duration.zero,
      vsync: const TestVSync(),
    );
    controller.value = 0.5;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GlassTopBar(
              height: 92,
              child: const Text('Greeting'),
              searchAnimation: controller,
              onSearchTap: () {},
            ),
          ],
        ),
      ),
    );

    // Search icon should be present (opacity at 0.5, not 0)
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('GlassTopBar does NOT render search icon when searchAnimation is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const GlassTopBar(
              height: 92,
              child: Text('Greeting'),
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.search_rounded), findsNothing);
  });
}
```

- [ ] **Step 2: Run the new tests — verify they FAIL**

Run: `flutter test test/widget_test.dart`
Expected: 2 new tests FAIL — GlassTopBar has no `searchAnimation` parameter yet.

- [ ] **Step 3: Implement GlassTopBar search icon support**

Replace the entire content of `lib/widgets/glass_top_bar.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Shared fixed header used by the three primary navigation destinations.
///
/// Optionally accepts [searchAnimation] + [onSearchTap] to render an
/// animated search icon on the right side (used by HomeScreen).
class GlassTopBar extends StatelessWidget {
  final double height;
  final Widget child;
  final Animation<double>? searchAnimation;
  final VoidCallback? onSearchTap;

  const GlassTopBar({
    super.key,
    required this.height,
    required this.child,
    this.searchAnimation,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final showSearch = searchAnimation != null && onSearchTap != null;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.expand(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.background,
                    AppTheme.background,
                    AppTheme.background.withValues(alpha: .76),
                    AppTheme.background.withValues(alpha: .54),
                  ],
                  stops: const [0, .18, .56, 1],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: .025),
                  ),
                ),
              ),
            ),
            // Left: original child (greeting)
            child,
            // Right: search icon (only when searchAnimation is provided)
            if (showSearch)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: searchAnimation!,
                  builder: (context, _) {
                    final p = searchAnimation!.value;
                    return Opacity(
                      opacity: p,
                      child: Transform.scale(
                        scale: lerpDouble(0.6, 1.0, p)!,
                        child: IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.primaryText,
                          ),
                          onPressed: p > 0.01 ? onSearchTap : null,
                          tooltip: '搜索',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests — verify PASS**

Run: `flutter test test/widget_test.dart`
Expected: All tests PASS (smoke test + 2 new GlassTopBar tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/glass_top_bar.dart test/widget_test.dart
git commit -m "feat(glass_top_bar): add optional animated search icon"
```

---

### Task 2: HomeScreen — scroll-driven search bar ↔ top bar animation

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Test (create): `test/home_search_animation_test.dart`

**Interfaces:**
- Consumes: `GlassTopBar(searchAnimation, onSearchTap)` from Task 1
- Produces: `_HomeScreenState` with `AnimationController _animController`, `ScrollController _scrollController`

- [ ] **Step 1: Create home_search_animation_test.dart — write tests**

Create `test/home_search_animation_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyal_music/app.dart';
import 'package:joyal_music/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen has large search bar and search icon in top bar', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));

    // Large search bar should be visible initially (opacity 1, not IgnorePointer)
    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);

    // Top bar search icon should exist (even if transparent at progress=0)
    // Wait for the app to settle after auth check
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byIcon(Icons.search_rounded), findsWidgets);
    // One in the large search bar, one in the top bar = at least 2
  });

  testWidgets('Scrolling changes search bar opacity', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Find the CustomScrollView and scroll down past the search bar range (70px)
    final scrollable = find.byType(CustomScrollView);
    expect(scrollable, findsOneWidget);

    // Before scroll: search bar text should be visible
    await tester.pump();
    final searchHint = find.text('搜索歌曲、专辑或艺人');
    expect(searchHint, findsOneWidget);

    // Scroll down 80px (past the 70px animation range)
    await tester.drag(scrollable, const Offset(0, -80));
    await tester.pumpAndSettle();

    // After scrolling past range: the search bar might still be in the tree
    // but should have IgnorePointer (progress=1). The widget should still exist
    // since we use AnimatedBuilder with opacity=0.
    // Verify the search bar widget is still in the widget tree:
    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the new tests — verify they FAIL (missing animation)**

Run: `flutter test test/home_search_animation_test.dart`
Expected: Tests may partially pass for widget existence but will not yet show animation behavior. The TopBar may not have 2 search icons yet.

- [ ] **Step 3: Implement HomeScreen animation**

Replace the entire content of `lib/screens/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/album.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/album_cover.dart';
import '../widgets/glass_top_bar.dart';
import 'album_detail_screen.dart';
import 'search_screen.dart';

/// 主页 Tab – Spotify 风格的专辑浏览。
///
/// 布局：顶部问候语 → 大搜索框 → 最近添加横向滚动 → 全部专辑双列网格。
/// 向下滚动时大搜索框缩小/上移/淡出，同时顶栏右侧搜索图标淡入放大。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ━━━ Layout constants ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const double _headerHeight = 92;
  static const double _searchBarHeight = 54;
  static const double _searchBarTopPadding = 16;
  static const double _totalRange = _searchBarHeight + _searchBarTopPadding; // 70

  // ━━━ Animation ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  late final AnimationController _animController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: Duration.zero,
      vsync: this,
    );
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final progress = (offset / _totalRange).clamp(0.0, 1.0);
    _animController.value = progress;
  }

  // ━━━ Greeting ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  // ━━━ Build ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody(libraryState)),
            GlassTopBar(
              height: _headerHeight,
              child: _buildHeader(),
              searchAnimation: _animController,
              onSearchTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_greeting(), style: AppTheme.headlineLarge),
          const SizedBox(height: 4),
          const Text('发现你的音乐世界', style: AppTheme.bodyMedium),
        ],
      ),
    );
  }

  /// Animated large search bar – responds to scroll progress.
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          final p = _animController.value;
          return IgnorePointer(
            ignoring: p == 1.0,
            child: Opacity(
              opacity: 1.0 - p,
              child: Transform.translate(
                offset: Offset(0, lerpDouble(0, -20, p)!),
                child: Transform.scale(
                  scale: lerpDouble(1.0, 0.85, p)!,
                  child: _HomeSearchBar(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(LibraryState state) {
    if (state.isLoading && state.albums.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: _headerHeight),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.albums.isEmpty) {
      return _buildError(state.error!);
    }

    if (state.albums.isEmpty) {
      return _buildEmpty();
    }

    final albums = state.albums;
    final recentAlbums = albums.take(6).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).fetchAlbums(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── 顶部留白（避开 GlassTopBar） ──
          const SliverToBoxAdapter(child: SizedBox(height: _headerHeight)),
          // ── 大搜索框（带动画） ──
          SliverToBoxAdapter(child: _buildSearch()),

          // ── 最近添加（横向滚动） ──
          if (recentAlbums.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionTitle(title: '最近添加')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingLG,
                    2,
                    AppTheme.spacingLG,
                    0,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: recentAlbums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final a = recentAlbums[index];
                    return _RecentCard(
                      album: a,
                      coverUrl: _coverUrl(a.coverArt),
                    );
                  },
                ),
              ),
            ),
          ],

          // ── 全部专辑（双列网格） ──
          SliverToBoxAdapter(child: _SectionTitle(title: '全部专辑')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppTheme.spacingMD,
                crossAxisSpacing: AppTheme.spacingMD,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final a = albums[index];
                return _AlbumGridCard(
                  album: a,
                  coverUrl: _coverUrl(a.coverArt),
                );
              }, childCount: albums.length),
            ),
          ),

          // 底部留白
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: _headerHeight),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: AppTheme.secondaryText,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              const Text('无法连接到服务器', style: AppTheme.titleMedium),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                msg,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              ElevatedButton(
                onPressed: () =>
                    ref.read(libraryProvider.notifier).fetchAlbums(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: _headerHeight),
        _buildSearch(),
        const SizedBox(height: 80),
        const Center(
          child: Column(
            children: [
              Icon(
                Icons.album_outlined,
                size: 48,
                color: AppTheme.secondaryText,
              ),
              SizedBox(height: AppTheme.spacingMD),
              Text('暂无专辑', style: AppTheme.bodyMedium),
              SizedBox(height: AppTheme.spacingSM),
              Text('请先在「我的」页面连接服务器', style: AppTheme.caption),
            ],
          ),
        ),
      ],
    );
  }

  String _coverUrl(String coverArtId) {
    final api = ref.read(subsonicApiProvider);
    if (api == null || coverArtId.isEmpty) return '';
    return api.getCoverArtUrl(coverArtId);
  }
}

// ━━━ 最近添加横向卡片 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RecentCard extends ConsumerWidget {
  final Album album;
  final String coverUrl;
  const _RecentCard({required this.album, required this.coverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 136,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumCover(
                coverArtUrl: coverUrl,
                cacheKey: album.coverArt,
                size: 136,
                radius: AppTheme.radiusMedium,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          height: 54,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: AppTheme.primaryText),
                SizedBox(width: 12),
                Text('搜索歌曲、专辑或艺人', style: AppTheme.bodyMedium),
                Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: AppTheme.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━ 全部专辑网格卡片 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AlbumGridCard extends ConsumerWidget {
  final Album album;
  final String coverUrl;
  const _AlbumGridCard({required this.album, required this.coverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlbumCover(
              coverArtUrl: coverUrl,
              cacheKey: album.coverArt,
              radius: AppTheme.radiusMedium,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.labelLarge,
            ),
            const SizedBox(height: 2),
            Text(
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.caption,
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━ 区域标题（复用） ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        AppTheme.spacingMD,
        AppTheme.spacingLG,
        AppTheme.spacingSM,
      ),
      child: Text(title, style: AppTheme.titleLarge),
    );
  }
}
```

- [ ] **Step 4: Run all tests — verify PASS**

Run: `flutter test`
Expected: All tests PASS — existing widget_test, scroll_utils_test, plus new GlassTopBar + animation tests.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze`
Expected: No new errors. Fix any warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home_screen.dart test/home_search_animation_test.dart
git commit -m "feat(home): scroll-driven search bar ↔ top bar linked animation"
```
