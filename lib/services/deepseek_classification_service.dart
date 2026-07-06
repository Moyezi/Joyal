import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/music_classification.dart';
import '../models/song.dart';

class DeepSeekClassificationService {
  final Dio _dio;

  const DeepSeekClassificationService(this._dio);

  Future<void> testConnection({
    required String apiKey,
    required AiClassificationSettings settings,
  }) async {
    await _request(
      apiKey: apiKey,
      settings: settings,
      songs: const [],
      testOnly: true,
    );
  }

  Future<List<SongClassification>> classifySongs({
    required String apiKey,
    required AiClassificationSettings settings,
    required List<Song> songs,
  }) async {
    if (songs.isEmpty) return const [];
    final payload = await _request(
      apiKey: apiKey,
      settings: settings,
      songs: songs,
      testOnly: false,
    );
    final decoded = _decodeClassificationPayload(payload);
    return decoded
        .map((item) {
          final songId = item['songId'] as String? ?? '';
          final song = songs.firstWhere(
            (candidate) => candidate.id == songId,
            orElse: () => songs.first,
          );
          return SongClassification(
            songId: songId.isEmpty ? song.id : songId,
            genres: _allowedList(
              item['genres'],
              ClassificationVocabulary.genres,
            ),
            moods: _allowedList(item['moods'], ClassificationVocabulary.moods),
            scenes: _allowedList(
              item['scenes'],
              ClassificationVocabulary.scenes,
            ),
            language: _allowedValue(
              item['language'],
              ClassificationVocabulary.languages,
              fallback: '其他语言',
            ),
            energy: ((item['energy'] as num?)?.toInt() ?? 50).clamp(0, 100),
            confidence: ((item['confidence'] as num?)?.toDouble() ?? 0.5).clamp(
              0,
              1,
            ),
            metadataHash: metadataHashForSong(song),
            vocabularyVersion: ClassificationVocabulary.version,
            model: settings.model,
            source: ClassificationSource.ai,
            updatedAt: DateTime.now(),
          );
        })
        .toList(growable: false);
  }

  Future<String> _request({
    required String apiKey,
    required AiClassificationSettings settings,
    required List<Song> songs,
    required bool testOnly,
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
            'content': testOnly
                ? '请只返回 {"ok":true}，用于测试当前模型是否可用。'
                : jsonEncode({
                    'songs': songs.map(_songPayload).toList(),
                    'genres': ClassificationVocabulary.genres,
                    'moods': ClassificationVocabulary.moods,
                    'scenes': ClassificationVocabulary.scenes,
                    'languages': ClassificationVocabulary.languages,
                  }),
          },
        ],
      },
    );

    final data = response.data;
    final content =
        ((data?['choices'] as List<dynamic>?)?.firstOrNull
                as Map<String, dynamic>?)?['message']
            as Map<String, dynamic>?;
    final text = content?['content'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('DeepSeek 返回格式异常');
    }
    if (testOnly) return text;
    return text;
  }

  Map<String, dynamic> _songPayload(Song song) => {
    'songId': song.id,
    'title': song.title,
    'artist': song.artist,
    'album': song.album,
  };

  List<Map<String, dynamic>> _decodeClassificationPayload(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? decoded['songs'] ?? decoded['results']
        : decoded;
    if (list is! List) {
      throw const FormatException('DeepSeek 返回格式异常');
    }
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  List<String> _allowedList(Object? value, List<String> allowed) {
    final values = (value as List<dynamic>? ?? [])
        .whereType<String>()
        .where(allowed.contains)
        .take(3)
        .toList(growable: false);
    return values.isEmpty ? ['其他'] : values;
  }

  String _allowedValue(
    Object? value,
    List<String> allowed, {
    required String fallback,
  }) {
    final text = value as String?;
    return text != null && allowed.contains(text) ? text : fallback;
  }

  static const _systemPrompt = '''
你是音乐曲库分类器。请根据歌曲名称、歌手和专辑进行分类。
流派、情绪、场景和语言只能从用户给定词表中选择，不允许创造新分类。
每首歌曲最多选择3个流派、3个情绪和3个场景。
无法确定时降低confidence，不得编造歌曲事实。
必须返回合法JSON，不得输出解释文字。
返回格式：{"songs":[{"songId":"...","genres":[],"moods":[],"scenes":[],"language":"...","energy":50,"confidence":0.5}]}。
''';
}
