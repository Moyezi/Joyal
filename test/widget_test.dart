import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyal_music/app.dart';
import 'package:joyal_music/models/album.dart';
import 'package:joyal_music/providers/auth_provider.dart';
import 'package:joyal_music/providers/library_provider.dart';
import 'package:joyal_music/providers/player_provider.dart';
import 'package:joyal_music/screens/home_screen.dart';
import 'package:joyal_music/screens/library_canvas_screen.dart';
import 'package:joyal_music/services/app_cache_service.dart';
import 'package:joyal_music/services/cache_repository.dart';
import 'package:joyal_music/services/buckets/album_cache_bucket.dart';
import 'package:joyal_music/services/buckets/artist_cache_bucket.dart';
import 'package:joyal_music/services/buckets/download_cache_bucket.dart';
import 'package:joyal_music/services/buckets/image_cache_bucket.dart';
import 'package:joyal_music/services/buckets/meta_cache_bucket.dart';
import 'package:joyal_music/services/buckets/search_cache_bucket.dart';
import 'package:joyal_music/services/buckets/stream_cache_bucket.dart';
import 'package:joyal_music/widgets/glass_top_bar.dart';

void main() {
  testWidgets('App smoke test – main shell renders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());

    // Verify the three primary navigation tabs and home search entrance.
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('曲库'), findsWidgets);
    expect(find.text('发现'), findsWidgets);
    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);
  });

  testWidgets('Home spread opens canvas and canvas pinch returns home', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final outwardLeft = await tester.createGesture(pointer: 11);
    final outwardRight = await tester.createGesture(pointer: 12);
    await outwardLeft.down(const Offset(280, 320));
    await outwardRight.down(const Offset(520, 320));
    await outwardLeft.moveTo(const Offset(225, 320));
    await tester.pump();
    await outwardLeft.up();
    await outwardRight.up();
    await tester.pumpAndSettle();

    expect(find.byType(LibraryCanvasScreen), findsOneWidget);

    final inwardLeft = await tester.createGesture(pointer: 13);
    final inwardRight = await tester.createGesture(pointer: 14);
    await inwardLeft.down(const Offset(240, 320));
    await inwardRight.down(const Offset(560, 320));
    await inwardLeft.moveTo(const Offset(315, 320));
    await tester.pump();
    await inwardLeft.up();
    await inwardRight.up();
    await tester.pumpAndSettle();

    expect(find.byType(LibraryCanvasScreen), findsNothing);
    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);
  });

  testWidgets('Two fingers freeze every home scroll direction', (tester) async {
    await tester.pumpWidget(
      _testApp(
        overrides: [
          libraryProvider.overrideWith(
            (ref) => _TestLibraryNotifier(_libraryWithManyAlbums()),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final scrollables = tester
        .stateList<ScrollableState>(
          find.descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          ),
        )
        .toList(growable: false);
    final initialOffsets = <ScrollableState, double>{
      for (final state in scrollables) state: state.position.pixels,
    };

    final first = await tester.createGesture(pointer: 21);
    final second = await tester.createGesture(pointer: 22);
    await first.down(const Offset(200, 400));
    await second.down(const Offset(400, 400));
    await first.moveTo(const Offset(300, 250));
    await second.moveTo(const Offset(500, 250));
    await tester.pump();

    for (final entry in initialOffsets.entries) {
      expect(entry.key.position.pixels, moreOrLessEquals(entry.value));
    }
    expect(find.byType(LibraryCanvasScreen), findsNothing);

    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  });

  // ━━━ GlassTopBar search icon tests ━━━━━━━━━━━━━━━━━━━━━━

  testWidgets(
    'GlassTopBar renders search icon when searchAnimation is provided',
    (tester) async {
      final vsync = TestVSync();
      final controller = AnimationController(
        duration: Duration.zero,
        vsync: vsync,
      );
      controller.value = 0.5;
      addTearDown(() {
        controller.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Stack(
              children: [
                GlassTopBar(
                  height: 92,
                  searchAnimation: controller,
                  onSearchTap: () {},
                  child: const Text('Greeting'),
                ),
              ],
            ),
          ),
        ),
      );

      // Search icon should be present (opacity at 0.5, not 0)
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'GlassTopBar does NOT render search icon when searchAnimation is null',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Stack(
              children: [
                const GlassTopBar(height: 92, child: Text('Greeting')),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_rounded), findsNothing);
    },
  );

  testWidgets('Discover tab no longer shows My floating action button', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.text('发现').last);
    await tester.pump();

    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('Bottom navigation switches tabs while dragging across items', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);

    await tester.dragFrom(const Offset(620, 580), const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(find.text('歌曲  0'), findsOneWidget);

    await tester.dragFrom(const Offset(360, 580), const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);
  });

  testWidgets('Home sidebar settings button opens settings hub', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.flingFrom(const Offset(48, 320), const Offset(520, 0), 1800);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('服务器连接'), findsOneWidget);
    expect(find.text('个性化设置'), findsOneWidget);
    expect(find.text('刷新曲库'), findsNothing);
    expect(find.text('外观'), findsNothing);
    expect(find.text('下载管理'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('缓存管理'), findsOneWidget);
    expect(find.text('关于 Joyal'), findsOneWidget);
  });

  testWidgets('Home content does not scroll vertically while opening sidebar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        overrides: [
          libraryProvider.overrideWith(
            (ref) => _TestLibraryNotifier(_libraryWithManyAlbums()),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final homeScrollable = _homeVerticalScrollable(tester);
    expect(homeScrollable.position.pixels, 0);

    await tester.dragFrom(const Offset(120, 160), const Offset(260, -90));
    await tester.pump();

    final currentHomeScrollable = _homeVerticalScrollable(tester);
    expect(currentHomeScrollable, same(homeScrollable));
    expect(currentHomeScrollable.position.pixels, 0);
  });

  testWidgets('Home sidebar drag preserves existing home scroll offset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        overrides: [
          libraryProvider.overrideWith(
            (ref) => _TestLibraryNotifier(_libraryWithManyAlbums()),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final homeScrollable = _homeVerticalScrollable(tester);

    await tester.drag(_homeCustomScrollView(), const Offset(0, -260));
    await tester.pumpAndSettle();
    final scrolledOffset = homeScrollable.position.pixels;
    expect(scrolledOffset, greaterThan(0));

    await tester.dragFrom(const Offset(120, 240), const Offset(260, -90));
    await tester.pump();

    final currentHomeScrollable = _homeVerticalScrollable(tester);
    expect(currentHomeScrollable, same(homeScrollable));
    expect(
      currentHomeScrollable.position.pixels,
      moreOrLessEquals(scrolledOffset),
    );
  });

  testWidgets('Home sidebar closes on a fast left fling', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final searchField = find.text('搜索歌曲、专辑或艺人');
    final closedLeft = tester.getTopLeft(searchField).dx;

    await tester.flingFrom(const Offset(48, 320), const Offset(520, 0), 1800);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(searchField).dx, greaterThan(closedLeft + 240));

    await tester.flingFrom(const Offset(700, 320), const Offset(-520, 0), 1800);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(searchField).dx, moreOrLessEquals(closedLeft));
  });
}

Widget _testApp({List<dynamic> overrides = const []}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => _TestAuthNotifier()),
      playerProvider.overrideWith((ref) => _TestPlayerNotifier()),
      ...overrides,
    ],
    child: const JoyalMusicApp(),
  );
}

Finder _homeCustomScrollView() {
  return find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byType(CustomScrollView),
  );
}

ScrollableState _homeVerticalScrollable(WidgetTester tester) {
  return tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        ),
      )
      .firstWhere(
        (state) => state.position.axisDirection == AxisDirection.down,
      );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier() : super(const FlutterSecureStorage(), Dio()) {
    state = const AuthState();
  }
}

class _TestPlayerNotifier extends PlayerNotifier {
  _TestPlayerNotifier() : super(null, const FlutterSecureStorage());
}

class _TestLibraryNotifier extends LibraryNotifier {
  _TestLibraryNotifier(LibraryState initial)
    : super(
        null,
        Dio(),
        AppCacheService.instance,
        CacheRepository(
          streamBucket: StreamBucket(),
          imageBucket: ImageBucket(),
          metaBucket: MetaBucket(),
          downloadBucket: DownloadBucket(),
          albumBucket: AlbumBucket(),
          artistBucket: ArtistBucket(),
          searchBucket: SearchBucket(),
        ),
      ) {
    state = initial;
  }
}

LibraryState _libraryWithManyAlbums() {
  return LibraryState(
    albums: List.generate(
      24,
      (index) => Album(
        id: 'album-$index',
        name: 'Album $index',
        artist: 'Artist $index',
        artistId: 'artist-$index',
        coverArt: '',
        songCount: 10,
        duration: 2400,
      ),
    ),
  );
}
