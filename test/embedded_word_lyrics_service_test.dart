import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/lyrics.dart';
import 'package:joyal_music/models/song.dart';
import 'package:joyal_music/services/app_cache_service.dart';
import 'package:joyal_music/services/lyrics_service.dart';
import 'package:joyal_music/services/subsonic_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory cacheDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'joyal_embedded_word_lyrics_test_',
    );
    cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}cache');
    AppCacheService.debugCacheDirectoryOverride = cacheDir;
  });

  tearDown(() async {
    AppCacheService.debugCacheDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('groups enhanced OpenSubsonic cues into complete lyric lines', () async {
    final requests = <Uri>[];
    final service = _serviceFor(_enhancedLyricsResponse, requests);

    final lyrics = await service.fetch(_song);

    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['enhanced'], 'true');
    expect(lyrics.source, LyricsContentSource.embeddedWordByWord);
    expect(lyrics.lines, hasLength(2));
    expect(lyrics.lines.map((line) => line.text), ['孤雏', '我的伤心']);
    expect(lyrics.lines.first.words.map((word) => word.text), ['孤', '雏']);
    expect(
      lyrics.lines.first.words.last.end,
      const Duration(milliseconds: 1672),
    );
  });

  test(
    'parses LDDC angle-bracket timing without one character per line',
    () async {
      final requests = <Uri>[];
      final service = _serviceFor(_lddcLyricsResponse, requests);

      final lyrics = await service.fetch(_song);

      expect(requests, hasLength(1));
      expect(lyrics.source, LyricsContentSource.embeddedWordByWord);
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].text, '孤雏 - AGA');
      expect(lyrics.lines[0].words.map((word) => word.text), [
        '孤',
        '雏',
        ' - ',
        'AGA',
      ]);
      expect(lyrics.lines[1].text, '我的伤心');
      expect(lyrics.lines[1].words, hasLength(4));
      expect(lyrics.lines[1].start, const Duration(milliseconds: 23321));
    },
  );
}

LyricsService _serviceFor(dynamic responseData, List<Uri> requests) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options.uri);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: responseData,
          ),
        );
      },
    ),
  );
  return LyricsService(
    api: const SubsonicApi(
      baseUrl: 'https://music.example.test',
      username: 'alice',
      password: 'secret',
    ),
    dio: dio,
    amllIndex: AmlLyricsIndex(loadAsset: () async => ''),
  );
}

const _song = Song(
  id: 'song-1',
  parent: 'album-1',
  title: '孤雏',
  album: 'Ginadoll Concert Live',
  artist: 'AGA',
  duration: 270,
  coverArt: 'cover-1',
  contentType: 'audio/mpeg',
  suffix: 'mp3',
);

const _enhancedLyricsResponse = {
  'subsonic-response': {
    'status': 'ok',
    'lyricsList': {
      'structuredLyrics': [
        {
          'kind': 'main',
          'synced': true,
          'line': [
            {'start': 993, 'value': '孤雏'},
            {'start': 23321, 'value': '我的伤心'},
          ],
          'cueLine': [
            {
              'index': 0,
              'start': 993,
              'end': 1672,
              'value': '孤雏',
              'cue': [
                {
                  'start': 993,
                  'end': 1336,
                  'value': '孤',
                  'byteStart': 0,
                  'byteEnd': 2,
                },
                {
                  'start': 1336,
                  'end': 1672,
                  'value': '雏',
                  'byteStart': 3,
                  'byteEnd': 5,
                },
              ],
            },
            {
              'index': 1,
              'start': 23321,
              'end': 25048,
              'value': '我的伤心',
              'cue': [
                {
                  'start': 23321,
                  'end': 23642,
                  'value': '我',
                  'byteStart': 0,
                  'byteEnd': 2,
                },
                {
                  'start': 23642,
                  'end': 23897,
                  'value': '的',
                  'byteStart': 3,
                  'byteEnd': 5,
                },
                {
                  'start': 23897,
                  'end': 24368,
                  'value': '伤',
                  'byteStart': 6,
                  'byteEnd': 8,
                },
                {
                  'start': 24368,
                  'end': 25048,
                  'value': '心',
                  'byteStart': 9,
                  'byteEnd': 11,
                },
              ],
            },
          ],
        },
      ],
    },
  },
};

const _lddcLyricsResponse = {
  'subsonic-response': {
    'status': 'ok',
    'lyricsList': {
      'structuredLyrics': [
        {
          'synced': true,
          'line': [
            {
              'start': 993,
              'value':
                  '[00:00.993]<00:00.993>孤<00:01.336>雏<00:01.672><00:01.673> - <00:02.009>AGA<00:02.408>\n'
                  '[00:23.321]<00:23.321>我<00:23.642>的<00:23.897>伤<00:24.368>心<00:25.048>',
            },
          ],
        },
      ],
    },
  },
};
