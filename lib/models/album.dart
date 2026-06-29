class Album {
  final String id;
  final String name;
  final String artist;
  final String artistId;
  final String coverArt;
  final int songCount;
  final int duration;
  final int? year;
  final String? genre;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.artistId,
    required this.coverArt,
    required this.songCount,
    required this.duration,
    this.year,
    this.genre,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      artistId: json['artistId'] as String? ?? '',
      coverArt: json['coverArt'] as String? ?? '',
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artist': artist,
    'artistId': artistId,
    'coverArt': coverArt,
    'songCount': songCount,
    'duration': duration,
    'year': year,
    'genre': genre,
  };

  /// Formatted total duration (e.g. "1h 23min")
  String get formattedDuration {
    final totalMinutes = duration ~/ 60;
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}min';
    return '${mins}min';
  }
}
