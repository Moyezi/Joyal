import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/models/cache_stats.dart';

void main() {
  test('totalBytes sums every cache category', () {
    const stats = CacheStats(
      streamBytes: 10,
      imageBytes: 20,
      metaBytes: 30,
      downloadBytes: 40,
    );

    expect(stats.totalBytes, 100);
  });

  test('limit labels and slider presets map consistently', () {
    expect(CacheStats.limitToLabel(500), '500 MB');
    expect(CacheStats.limitToLabel(1024), '1 GB');
    expect(CacheStats.limitToLabel(2048), '2 GB');
    expect(CacheStats.limitToLabel(5120), '5 GB');
    expect(CacheStats.limitToLabel(0), '无限制');

    expect(CacheStats.sliderValueToLimit(0), 500);
    expect(CacheStats.sliderValueToLimit(1), 1024);
    expect(CacheStats.sliderValueToLimit(2), 2048);
    expect(CacheStats.sliderValueToLimit(3), 5120);
    expect(CacheStats.sliderValueToLimit(4), 0);
  });

  test('copyWith updates selected fields and preserves the rest', () {
    final updated = const CacheStats(
      streamBytes: 1,
      maxLimitMb: 500,
    ).copyWith(imageBytes: 2, isCalculating: true);

    expect(updated.streamBytes, 1);
    expect(updated.imageBytes, 2);
    expect(updated.maxLimitMb, 500);
    expect(updated.isCalculating, true);
  });
}
