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
    tempDir = await Directory.systemTemp.createTemp('joyal_lyrics_cache_test_');
    cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}cache');
    AppCacheService.debugCacheDirectoryOverride = cacheDir;
  });

  tearDown(() async {
    AppCacheService.debugCacheDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'caches empty lyrics results to avoid repeated network lookups',
    () async {
      var requests = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: _emptyLyricsResponse,
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
      );

      final first = await service.fetch(_song);
      final afterFirst = requests;
      final files = cacheDir
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toList();
      final second = await service.fetch(_song);

      expect(first.isEmpty, isTrue);
      expect(second.isEmpty, isTrue);
      expect(files, isNotEmpty);
      expect(afterFirst, 2);
      expect(requests, afterFirst);
    },
  );
}

const _song = Song(
  id: 'song-1',
  parent: 'album-1',
  title: 'Silent Track',
  album: 'Quiet Record',
  artist: 'No Words',
  duration: 180,
  coverArt: 'cover-1',
  contentType: 'audio/flac',
  suffix: 'flac',
);

const _emptyLyricsResponse = {
  'subsonic-response': {
    'status': 'ok',
    'lyrics': {'value': ''},
  },
};
