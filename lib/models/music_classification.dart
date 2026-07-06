import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'song.dart';

enum ClassificationTaskStatus { idle, running, paused, completed, failed }

enum ClassificationSource { ai, manual }

class ClassificationVocabulary {
  ClassificationVocabulary._();

  static const version = 1;

  static const genres = [
    '华语流行',
    '欧美流行',
    '日韩流行',
    '摇滚',
    '电子',
    '民谣',
    '嘻哈',
    'R&B',
    '爵士',
    '古典',
    '纯音乐',
    '原声',
    '轻音乐',
    '舞曲',
    '金属',
    '朋克',
    '独立音乐',
    '其他',
  ];

  static const moods = [
    '快乐',
    '治愈',
    '平静',
    '浪漫',
    '忧郁',
    '怀旧',
    '热血',
    '梦幻',
    '孤独',
    '黑暗',
    '温柔',
    '轻松',
    '压抑',
    '空灵',
  ];

  static const scenes = [
    '通勤',
    '驾驶',
    '学习',
    '工作',
    '睡前',
    '健身',
    '跑步',
    '聚会',
    '旅行',
    '独处',
    '放松',
    '咖啡馆',
    '阅读',
    '深夜',
    '清晨',
  ];

  static const languages = ['华语', '粤语', '英语', '日语', '纯音乐', '其他语言'];
}

class AiClassificationSettings {
  final bool apiKeyConfigured;
  final String provider;
  final String apiBaseUrl;
  final String model;
  final int batchSize;
  final int maxConcurrentRequests;
  final bool wifiOnly;
  final bool notificationsEnabled;

  const AiClassificationSettings({
    this.apiKeyConfigured = false,
    this.provider = 'deepseek',
    this.apiBaseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-chat',
    this.batchSize = 20,
    this.maxConcurrentRequests = 1,
    this.wifiOnly = true,
    this.notificationsEnabled = true,
  });

  AiClassificationSettings copyWith({
    bool? apiKeyConfigured,
    String? provider,
    String? apiBaseUrl,
    String? model,
    int? batchSize,
    int? maxConcurrentRequests,
    bool? wifiOnly,
    bool? notificationsEnabled,
  }) {
    return AiClassificationSettings(
      apiKeyConfigured: apiKeyConfigured ?? this.apiKeyConfigured,
      provider: provider ?? this.provider,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      model: model ?? this.model,
      batchSize: batchSize ?? this.batchSize,
      maxConcurrentRequests:
          maxConcurrentRequests ?? this.maxConcurrentRequests,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  factory AiClassificationSettings.fromJson(Map<String, dynamic> json) {
    return AiClassificationSettings(
      apiKeyConfigured: json['apiKeyConfigured'] as bool? ?? false,
      provider: json['provider'] as String? ?? 'deepseek',
      apiBaseUrl: json['apiBaseUrl'] as String? ?? 'https://api.deepseek.com',
      model: json['model'] as String? ?? 'deepseek-chat',
      batchSize: (json['batchSize'] as num?)?.toInt() ?? 20,
      maxConcurrentRequests:
          (json['maxConcurrentRequests'] as num?)?.toInt() ?? 1,
      wifiOnly: json['wifiOnly'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKeyConfigured': apiKeyConfigured,
    'provider': provider,
    'apiBaseUrl': apiBaseUrl,
    'model': model,
    'batchSize': batchSize,
    'maxConcurrentRequests': maxConcurrentRequests,
    'wifiOnly': wifiOnly,
    'notificationsEnabled': notificationsEnabled,
  };
}

class SongClassification {
  final String songId;
  final List<String> genres;
  final List<String> moods;
  final List<String> scenes;
  final String language;
  final int energy;
  final double confidence;
  final String metadataHash;
  final int vocabularyVersion;
  final String model;
  final ClassificationSource source;
  final DateTime updatedAt;

  const SongClassification({
    required this.songId,
    required this.genres,
    required this.moods,
    required this.scenes,
    required this.language,
    required this.energy,
    required this.confidence,
    required this.metadataHash,
    required this.vocabularyVersion,
    required this.model,
    required this.source,
    required this.updatedAt,
  });

  SongClassification copyWith({
    List<String>? genres,
    List<String>? moods,
    List<String>? scenes,
    String? language,
    int? energy,
    double? confidence,
    String? metadataHash,
    int? vocabularyVersion,
    String? model,
    ClassificationSource? source,
    DateTime? updatedAt,
  }) {
    return SongClassification(
      songId: songId,
      genres: genres ?? this.genres,
      moods: moods ?? this.moods,
      scenes: scenes ?? this.scenes,
      language: language ?? this.language,
      energy: energy ?? this.energy,
      confidence: confidence ?? this.confidence,
      metadataHash: metadataHash ?? this.metadataHash,
      vocabularyVersion: vocabularyVersion ?? this.vocabularyVersion,
      model: model ?? this.model,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool matchesCurrentSong(Song song, String model) {
    return metadataHash == metadataHashForSong(song) &&
        vocabularyVersion == ClassificationVocabulary.version &&
        this.model == model;
  }

  factory SongClassification.fromJson(Map<String, dynamic> json) {
    return SongClassification(
      songId: json['songId'] as String? ?? '',
      genres: _stringList(json['genres']),
      moods: _stringList(json['moods']),
      scenes: _stringList(json['scenes']),
      language: json['language'] as String? ?? '其他语言',
      energy: ((json['energy'] as num?)?.toInt() ?? 50).clamp(0, 100),
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      metadataHash: json['metadataHash'] as String? ?? '',
      vocabularyVersion:
          (json['vocabularyVersion'] as num?)?.toInt() ??
          ClassificationVocabulary.version,
      model: json['model'] as String? ?? 'deepseek-chat',
      source: (json['source'] as String?) == 'manual'
          ? ClassificationSource.manual
          : ClassificationSource.ai,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'genres': genres,
    'moods': moods,
    'scenes': scenes,
    'language': language,
    'energy': energy,
    'confidence': confidence,
    'metadataHash': metadataHash,
    'vocabularyVersion': vocabularyVersion,
    'model': model,
    'source': source == ClassificationSource.manual ? 'manual' : 'ai',
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? [])
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .map((item) => item.trim())
        .toList(growable: false);
  }
}

String metadataHashForSong(Song song) {
  final normalized = [
    song.id,
    song.title,
    song.artist,
    song.album,
    song.parent,
  ].map((item) => item.trim().toLowerCase()).join('|');
  return sha256.convert(utf8.encode(normalized)).toString();
}

String decadeLabelForSong(Song song) {
  // The current Song model does not expose a year yet. Keep this deterministic
  // and explicit until the Subsonic parser carries year metadata.
  return '年份未知';
}
