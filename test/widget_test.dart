import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyal_music/app.dart';
import 'package:joyal_music/models/album.dart';
import 'package:joyal_music/providers/library_provider.dart';
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
    await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));

    // Verify the three primary navigation tabs and home search entrance.
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('曲库'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('搜索歌曲、专辑或艺人'), findsOneWidget);
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
        MaterialApp(
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
      );

      // Search icon should be present (opacity at 0.5, not 0)
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'GlassTopBar does NOT render search icon when searchAnimation is null',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [const GlassTopBar(height: 92, child: Text('Greeting'))],
          ),
        ),
      );

      expect(find.byIcon(Icons.search_rounded), findsNothing);
    },
  );

  testWidgets('Favorites tab no longer shows My floating action button', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));

    await tester.tap(find.text('收藏'));
    await tester.pump();

    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('Home sidebar settings button opens settings hub', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: JoyalMusicApp()));

    await tester.drag(find.text('搜索歌曲、专辑或艺人'), const Offset(360, 0));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('服务器连接'), findsOneWidget);
    expect(find.text('刷新曲库'), findsOneWidget);
    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('缓存管理'), findsOneWidget);
    expect(find.text('关于 Joyal Music'), findsOneWidget);
  });

  testWidgets('Home content does not scroll vertically while opening sidebar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(
            (ref) => _TestLibraryNotifier(_libraryWithManyAlbums()),
          ),
        ],
        child: const JoyalMusicApp(),
      ),
    );
    await tester.pumpAndSettle();

    final homeScrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere(
          (state) => state.position.axisDirection == AxisDirection.down,
        );
    expect(homeScrollable.position.pixels, 0);

    await tester.dragFrom(const Offset(120, 160), const Offset(260, -90));
    await tester.pump();

    expect(homeScrollable.position.pixels, 0);
  });
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
