import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyal_music/models/lyrics_ai_palette.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/models/song_highlight.dart';
import 'package:joyal_music/providers/lyrics_ai_palette_provider.dart';
import 'package:joyal_music/providers/music_classification_provider.dart';
import 'package:joyal_music/providers/song_highlight_provider.dart';
import 'package:joyal_music/screens/music_classification_screen.dart';
import 'package:joyal_music/services/app_cache_service.dart';
import 'package:joyal_music/services/deepseek_classification_service.dart';
import 'package:joyal_music/services/music_classification_repository.dart';

void main() {
  testWidgets('小Jo同学按需读取高潮与配色记录', (tester) async {
    var highlightReads = 0;
    var paletteReads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicClassificationProvider.overrideWith(
            (ref) => _TestMusicClassificationNotifier(),
          ),
          recognizedSongHighlightsProvider.overrideWith((ref) async {
            highlightReads++;
            return const [];
          }),
          recognizedLyricsAiPalettesProvider.overrideWith((ref) async {
            paletteReads++;
            return const [];
          }),
          cachedRecognizedSongHighlightCountProvider.overrideWith(
            (ref) async => 7,
          ),
          cachedRecognizedLyricsAiPaletteCountProvider.overrideWith(
            (ref) async => 5,
          ),
        ],
        child: const MaterialApp(home: MusicClassificationScreen()),
      ),
    );
    await tester.pump();

    expect(highlightReads, 0);
    expect(paletteReads, 0);
    expect(_hasMetric(tester, '高潮', '7'), isTrue);
    expect(_hasMetric(tester, '配色', '5'), isTrue);

    await tester.tap(find.text('高潮').last);
    await tester.pump();
    expect(highlightReads, 1);
    expect(paletteReads, 0);

    await tester.tap(find.text('配色').last);
    await tester.pump();
    expect(highlightReads, 1);
    expect(paletteReads, 1);
  });

  testWidgets('高潮与配色记录可按歌曲、歌手和专辑分别搜索', (tester) async {
    final firstSong = _song(
      id: 'song-1',
      title: 'Midnight City',
      artist: 'M83',
      album: 'Hurry Up',
    );
    final secondSong = _song(
      id: 'song-2',
      title: '星河',
      artist: 'Muse',
      album: 'Night Album',
    );
    final highlights = [_highlight(firstSong), _highlight(secondSong)];
    final palettes = [_palette(firstSong), _palette(secondSong)];

    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicClassificationProvider.overrideWith(
            (ref) => _TestMusicClassificationNotifier(),
          ),
          recognizedSongHighlightsProvider.overrideWith(
            (ref) async => highlights,
          ),
          recognizedLyricsAiPalettesProvider.overrideWith(
            (ref) async => palettes,
          ),
          cachedRecognizedSongHighlightCountProvider.overrideWith(
            (ref) async => highlights.length,
          ),
          cachedRecognizedLyricsAiPaletteCountProvider.overrideWith(
            (ref) async => palettes.length,
          ),
        ],
        child: const MaterialApp(home: MusicClassificationScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('高潮').last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final highlightSearch = find.byType(TextField);
    expect(highlightSearch, findsOneWidget);
    await tester.enterText(highlightSearch, 'night album');
    await tester.pump();

    expect(find.text('星河'), findsOneWidget);
    expect(find.text('Midnight City'), findsNothing);
    expect(find.text('1/2 首符合搜索'), findsOneWidget);
    expect(find.text('清除筛选'), findsOneWidget);

    await tester.enterText(highlightSearch, '没有这首歌');
    await tester.pump();
    expect(find.text('没有找到相关记录'), findsOneWidget);

    await tester.tap(find.text('配色').last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final paletteSearch = find.byType(TextField);
    expect(paletteSearch, findsOneWidget);
    await tester.enterText(paletteSearch, 'M83 hurry');
    await tester.pump();

    expect(find.text('Midnight City'), findsOneWidget);
    expect(find.text('星河'), findsNothing);
    expect(find.text('1/2 首符合搜索'), findsOneWidget);

    await tester.tap(find.text('高潮').last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('没有找到相关记录'), findsOneWidget);
  });
}

bool _hasMetric(WidgetTester tester, String label, String value) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .any((widget) => widget.text.toPlainText() == '$label  $value');
}

class _TestMusicClassificationNotifier extends MusicClassificationNotifier {
  _TestMusicClassificationNotifier()
    : super(
        MusicClassificationRepository(
          AppCacheService.instance,
          const FlutterSecureStorage(),
        ),
        DeepSeekClassificationService(Dio()),
      );
}

Song _song({
  required String id,
  required String title,
  required String artist,
  required String album,
}) {
  return Song(
    id: id,
    parent: 'album-id',
    title: title,
    album: album,
    artist: artist,
    duration: 240,
    coverArt: '',
    contentType: 'audio/mpeg',
    suffix: 'mp3',
  );
}

RecognizedSongHighlight _highlight(Song song) {
  return RecognizedSongHighlight(
    song: song,
    timeline: SongHighlightTimeline(
      segments: const [
        SongHighlightSegment(
          start: Duration(seconds: 60),
          end: Duration(seconds: 90),
        ),
      ],
      lyricsHash: 'hash',
      model: 'model',
      analyzedAt: DateTime.utc(2026, 7, 15),
    ),
  );
}

RecognizedLyricsAiPalette _palette(Song song) {
  return RecognizedLyricsAiPalette(
    song: song,
    palette: LyricsAiPalette(
      keywords: const [LyricsAiKeywordColors(text: '月光', color: 0xFFCCDDEE)],
      metadataHash: 'hash',
      model: 'model',
      promptVersion: 1,
      generatedAt: DateTime.utc(2026, 7, 15),
    ),
  );
}
