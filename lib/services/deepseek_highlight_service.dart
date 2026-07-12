import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/lyrics.dart';
import '../models/music_classification.dart';
import '../models/song.dart';
import '../models/song_highlight.dart';

class DeepSeekHighlightService {
  final Dio _dio;

  const DeepSeekHighlightService(this._dio);

  Future<List<SongHighlightSegment>> analyze({
    required String apiKey,
    required AiClassificationSettings settings,
    required Song song,
    required LyricsData lyrics,
  }) async {
    final uri = Uri.parse(settings.apiBaseUrl).resolve('/chat/completions');
    final response = await _dio.postUri<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': settings.model,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': jsonEncode({
              'song': {
                'title': song.title,
                'artist': song.artist,
                'album': song.album,
                'durationMs': song.duration * 1000,
              },
              'lyrics': _timedLyricsPayload(song, lyrics),
            }),
          },
        ],
      },
    );

    final content =
        (((response.data?['choices'] as List<dynamic>?)?.firstOrNull
                    as Map?)?['message']
                as Map?)?['content']
            as String?;
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('DeepSeek 返回的高潮时间轴为空');
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('DeepSeek 返回的高潮时间轴格式异常');
    }
    return normalizeHighlightSegments(
      decoded['highlights'] ?? decoded['segments'],
      songDuration: Duration(seconds: song.duration),
    );
  }

  List<Map<String, dynamic>> _timedLyricsPayload(Song song, LyricsData lyrics) {
    final result = <Map<String, dynamic>>[];
    for (var index = 0; index < lyrics.lines.length; index++) {
      final line = lyrics.lines[index];
      final start = line.start;
      if (start == null || line.text.trim().isEmpty) continue;
      final nextStart = index + 1 < lyrics.lines.length
          ? lyrics.lines[index + 1].start
          : null;
      final end = line.end ?? nextStart ?? Duration(seconds: song.duration);
      result.add({
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'text': line.text.trim(),
      });
    }
    return result;
  }

  static const _systemPrompt = '''
你是音乐结构分析器。根据歌曲名、歌手、专辑、歌曲时长和带时间歌词，找出真正的高潮段落。
高潮通常是情绪、主题或副歌最集中的连续区间；
只返回1到3个最重要的连续区间，时间必须位于歌曲时长内，并尽量贴合歌词行边界。
如果证据不足，可以返回空数组。必须返回合法 JSON，不得输出解释文字。
返回格式：{"highlights":[{"startMs":60000,"endMs":85000}]}。
''';
}
