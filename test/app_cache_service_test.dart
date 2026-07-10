import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/services/app_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('joyal_app_cache_test_');
    AppCacheService.debugCacheDirectoryOverride = tempDir;
  });

  tearDown(() async {
    AppCacheService.debugCacheDirectoryOverride = null;
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('large background-encoded JSON round trips without data loss', () async {
    final songs = List.generate(
      1500,
      (index) => {
        'id': 'song-$index',
        'title': 'Track $index',
        'artist': 'Artist ${index % 40}',
      },
    );

    await AppCacheService.instance.writeJson('large_snapshot', {
      'songs': songs,
    }, encodeInBackground: true);
    final restored = await AppCacheService.instance.readJson('large_snapshot');

    expect((restored?['songs'] as List<dynamic>).length, songs.length);
    expect((restored?['songs'] as List<dynamic>).last['id'], 'song-1499');
  });
}
