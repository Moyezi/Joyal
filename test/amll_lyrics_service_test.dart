import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/services/app_cache_service.dart';
import 'package:joyal_music/services/lyrics_service.dart';
import 'package:joyal_music/services/subsonic_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory cacheDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('joyal_amll_lyrics_test_');
    cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}cache');
    AppCacheService.debugCacheDirectoryOverride = cacheDir;
  });

  tearDown(() async {
    AppCacheService.debugCacheDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('matches QQ metadata, parses TTML word timing, and caches it', () async {
    final requests = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.uri.toString());
          handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: _ttml,
            ),
          );
        },
      ),
    );
    final service = LyricsService(
      api: SubsonicApi(
        baseUrl: 'https://music.example.test',
        username: 'alice',
        password: 'secret',
      ),
      dio: dio,
      amllIndex: AmlLyricsIndex(loadAsset: () async => _matchingIndex),
    );

    final first = await service.fetch(_song);
    final second = await service.fetch(_song);

    expect(requests, [
      'https://raw.githubusercontent.com/amll-dev/amll-ttml-db/'
          'refs/heads/main/qq-lyrics/464890166.ttml',
    ]);
    expect(first.synced, isTrue);
    expect(first.lines, hasLength(1));
    expect(first.lines.single.text, '你好 世界');
    expect(first.lines.single.words, hasLength(3));
    expect(first.lines.single.words.first.start, const Duration(seconds: 1));
    expect(first.lines.single.words[1].end, const Duration(milliseconds: 1400));
    expect(second.toJson(), first.toJson());

    await service.clearCachedLyrics(_song);
    await service.fetch(_song);
    expect(requests, hasLength(2));
  });

  test('bundled AMLL index resolves the supplied White Night example', () async {
    final reference = await AmlLyricsIndex().match(_song);

    expect(reference, isNotNull);
    expect(reference!.directory, 'qq-lyrics');
    expect(reference.lyricId, '464890166');
  });
}

const _song = Song(
  id: 'song-1',
  parent: 'album-1',
  title: '不眠之夜',
  album: '不眠之夜',
  artist: '张杰; HOYO-MiX',
  duration: 128,
  coverArt: 'cover-1',
  contentType: 'audio/flac',
  suffix: 'flac',
);

const _matchingIndex =
    '{"metadata":[["album",["不眠之夜"]],["artists",["张杰","HOYO-MiX"]],["musicName",["不眠之夜"]],["qqMusicId",["464890166"]]],"rawLyricFile":"example.ttml"}';

const _ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body><div>
    <p begin="00:01.000" end="00:02.000"><span begin="00:01.000" end="00:01.200">你</span><span begin="00:01.200" end="00:01.400">好</span> <span begin="00:01.400" end="00:02.000">世界</span></p>
  </div></body>
</tt>
''';
