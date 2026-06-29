class Song {
  final String id;
  final String parent;
  final String title;
  final String album;
  final String artist;
  final int? track;
  final int duration;
  final String coverArt;
  final int? size;
  final String contentType;
  final String suffix;

  const Song({
    required this.id,
    required this.parent,
    required this.title,
    required this.album,
    required this.artist,
    this.track,
    required this.duration,
    required this.coverArt,
    this.size,
    required this.contentType,
    required this.suffix,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      parent: json['parent'] as String? ?? json['albumId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      album: json['album'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      track: (json['track'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      coverArt: json['coverArt'] as String? ?? '',
      size: (json['size'] as num?)?.toInt(),
      contentType: json['contentType'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent': parent,
    'title': title,
    'album': album,
    'artist': artist,
    'track': track,
    'duration': duration,
    'coverArt': coverArt,
    'size': size,
    'contentType': contentType,
    'suffix': suffix,
  };

  /// Formatted duration string (e.g. "3:42")
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
