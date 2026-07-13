import 'song.dart';

class DownloadProgress {
  final String songId;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final bool completed;
  final String? error;
  final String? filePath;
  final int? taskId;
  final String? systemStatus;
  final int? systemReason;

  const DownloadProgress({
    required this.songId,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.completed = false,
    this.error,
    this.filePath,
    this.taskId,
    this.systemStatus,
    this.systemReason,
  });
}

class DownloadFailure implements Exception {
  final String message;
  const DownloadFailure(this.message);

  @override
  String toString() => message;
}

class DownloadRecord {
  final Song song;
  final String uri;
  final String fileName;
  final int size;
  final DateTime downloadedAt;

  const DownloadRecord({
    required this.song,
    required this.uri,
    required this.fileName,
    required this.size,
    required this.downloadedAt,
  });

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
    song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
    uri: json['uri'] as String,
    fileName: json['fileName'] as String,
    size: (json['size'] as num?)?.toInt() ?? 0,
    downloadedAt:
        DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'uri': uri,
    'fileName': fileName,
    'size': size,
    'downloadedAt': downloadedAt.toUtc().toIso8601String(),
  };
}
