import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
