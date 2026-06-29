class Artist {
  final String id;
  final String name;
  final int albumCount;
  final String? avatarUrl;

  const Artist({
    required this.id,
    required this.name,
    this.albumCount = 0,
    this.avatarUrl,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      albumCount: (json['albumCount'] as num?)?.toInt() ?? 0,
      avatarUrl: json['largeImageUrl'] as String? ??
          json['mediumImageUrl'] as String? ??
          json['smallImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'albumCount': albumCount,
    'avatarUrl': avatarUrl,
  };

  /// Returns the first character of the artist name,
  /// used as avatar fallback. Returns '?' for empty names.
  String get initial {
    if (name.isEmpty) return '?';
    return name.substring(0, 1);
  }
}
