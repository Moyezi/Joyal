import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joyal_music/providers/listening_stats_provider.dart';

void main() {
  const storageKey = 'listening_stats_v1';

  test(
    'markSongHeard keeps recent songs ordered, unique, and capped',
    () async {
      final storage = _MemorySecureStorage();
      final notifier = ListeningStatsNotifier(storage);

      for (var index = 0; index < 30; index += 1) {
        await notifier.markSongHeard('song-$index');
      }

      expect(notifier.state.heardSongCount, 30);
      expect(
        notifier.state.recentSongIds,
        hasLength(ListeningStatsNotifier.maxRecentSongs),
      );
      expect(notifier.state.recentSongIds.first, 'song-29');
      expect(notifier.state.recentSongIds.last, 'song-6');

      await notifier.markSongHeard('song-20');

      expect(notifier.state.heardSongCount, 30);
      expect(
        notifier.state.recentSongIds,
        hasLength(ListeningStatsNotifier.maxRecentSongs),
      );
      expect(notifier.state.recentSongIds.first, 'song-20');
      expect(
        notifier.state.recentSongIds.where((id) => id == 'song-20'),
        hasLength(1),
      );

      await Future<void>.delayed(Duration.zero);
      final persisted =
          jsonDecode(storage.values[storageKey]!) as Map<String, dynamic>;
      expect(persisted['recentSongIds'], notifier.state.recentSongIds);
    },
  );

  test(
    'legacy heard songs can become recent without inflating stats',
    () async {
      final storage = _MemorySecureStorage(
        initialValues: {
          storageKey: jsonEncode({
            'heardSongIds': ['legacy-song'],
          }),
        },
      );
      final notifier = ListeningStatsNotifier(storage);

      await notifier.markSongHeard('legacy-song');

      expect(notifier.state.heardSongIds, contains('legacy-song'));
      expect(notifier.state.heardSongCount, 1);
      expect(notifier.state.recentSongIds, ['legacy-song']);
    },
  );
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage({Map<String, String> initialValues = const {}})
    : values = Map<String, String>.from(initialValues);

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
