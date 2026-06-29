class CacheStats {
  static const List<int> limitPresets = [500, 1024, 2048, 5120, 0];

  final int streamBytes;
  final int imageBytes;
  final int metaBytes;
  final int downloadBytes;
  final int albumBytes;
  final int artistBytes;
  final int searchBytes;
  final bool isCalculating;
  final DateTime? lastUpdated;
  final int maxLimitMb;

  const CacheStats({
    this.streamBytes = 0,
    this.imageBytes = 0,
    this.metaBytes = 0,
    this.downloadBytes = 0,
    this.albumBytes = 0,
    this.artistBytes = 0,
    this.searchBytes = 0,
    this.isCalculating = false,
    this.lastUpdated,
    this.maxLimitMb = 0,
  });

  int get totalBytes =>
      streamBytes + imageBytes + metaBytes + downloadBytes +
      albumBytes + artistBytes + searchBytes;

  int get limitPresetIndex {
    final index = limitPresets.indexOf(maxLimitMb);
    return index >= 0 ? index : limitPresets.length - 1;
  }

  double get sliderMax => (limitPresets.length - 1).toDouble();

  int get sliderDivisions => limitPresets.length - 1;

  String get maxLimitLabel => limitToLabel(maxLimitMb);

  int get maxLimitBytes => maxLimitMb <= 0 ? 0 : maxLimitMb * 1024 * 1024;

  bool get hasLimit => maxLimitMb > 0;

  CacheStats copyWith({
    int? streamBytes,
    int? imageBytes,
    int? metaBytes,
    int? downloadBytes,
    int? albumBytes,
    int? artistBytes,
    int? searchBytes,
    bool? isCalculating,
    DateTime? lastUpdated,
    int? maxLimitMb,
  }) {
    return CacheStats(
      streamBytes: streamBytes ?? this.streamBytes,
      imageBytes: imageBytes ?? this.imageBytes,
      metaBytes: metaBytes ?? this.metaBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      albumBytes: albumBytes ?? this.albumBytes,
      artistBytes: artistBytes ?? this.artistBytes,
      searchBytes: searchBytes ?? this.searchBytes,
      isCalculating: isCalculating ?? this.isCalculating,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      maxLimitMb: maxLimitMb ?? this.maxLimitMb,
    );
  }

  static int sliderValueToLimit(double value) {
    final index = value.round().clamp(0, limitPresets.length - 1);
    return limitPresets[index];
  }

  static String limitToLabel(int mb) {
    return switch (mb) {
      0 => '无限制',
      1024 => '1 GB',
      2048 => '2 GB',
      5120 => '5 GB',
      _ => '$mb MB',
    };
  }
}
