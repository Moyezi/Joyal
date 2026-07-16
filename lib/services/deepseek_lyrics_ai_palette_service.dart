import 'package:dio/dio.dart';

import '../models/lyrics_ai_palette.dart';
import '../models/lyrics.dart';
import '../models/music_classification.dart';
import '../models/song.dart';
import 'lyrics_ai_palette_protocol.dart';

class DeepSeekLyricsAiPaletteService {
  final Dio _dio;

  const DeepSeekLyricsAiPaletteService(this._dio);

  Future<LyricsAiPalette> generate({
    required String apiKey,
    required AiClassificationSettings settings,
    required Song song,
    required LyricsData lyrics,
    LyricsAiVisualContext? visualContext,
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
      data: buildLyricsAiPaletteRequestBody(
        settings: settings,
        song: song,
        lyrics: lyrics,
        visualContext: visualContext,
      ),
    );
    final content =
        (((response.data?['choices'] as List<dynamic>?)?.firstOrNull
                    as Map?)?['message']
                as Map?)?['content']
            as String?;
    final keywords = parseLyricsAiPaletteResponse(
      content ?? '',
      lyrics: lyrics,
      visualContext: visualContext,
    );
    return LyricsAiPalette(
      keywords: keywords,
      metadataHash: lyricsAiPaletteMetadataHash(
        song,
        lyrics,
        visualContext: visualContext,
      ),
      model: settings.model,
      promptVersion: lyricsAiPalettePromptVersion,
      generatedAt: DateTime.now(),
    );
  }
}
