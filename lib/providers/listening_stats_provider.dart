import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_provider.dart';

class ListeningStatsState {
  final Set<String> heardSongIds;
  final bool isLoading;

  const ListeningStatsState({
    this.heardSongIds = const <String>{},
    this.isLoading = true,
  });

  int get heardSongCount => heardSongIds.length;

  ListeningStatsState copyWith({Set<String>? heardSongIds, bool? isLoading}) {
    return ListeningStatsState(
      heardSongIds: heardSongIds ?? this.heardSongIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ListeningStatsNotifier extends StateNotifier<ListeningStatsState> {
  static const _storageKey = 'listening_stats_v1';

  final FlutterSecureStorage _storage;
  Future<void>? _initialization;

  ListeningStatsNotifier(this._storage) : super(const ListeningStatsState()) {
    _initialization = _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) {
        state = const ListeningStatsState(isLoading: false);
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final heardSongIds = (json['heardSongIds'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toSet();
      state = ListeningStatsState(
        heardSongIds: Set.unmodifiable(heardSongIds),
        isLoading: false,
      );
    } catch (_) {
      state = const ListeningStatsState(isLoading: false);
    }
  }

  Future<void> markSongHeard(String songId) async {
    if (songId.isEmpty) return;
    await _initialization;
    if (state.heardSongIds.contains(songId)) return;

    final heardSongIds = {...state.heardSongIds, songId};
    state = state.copyWith(heardSongIds: Set.unmodifiable(heardSongIds));
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode({'heardSongIds': state.heardSongIds.toList()}),
      );
    } catch (_) {
      // Listening stats are nice-to-have and must never interrupt playback.
    }
  }
}

final listeningStatsProvider =
    StateNotifierProvider<ListeningStatsNotifier, ListeningStatsState>((ref) {
      return ListeningStatsNotifier(ref.watch(secureStorageProvider));
    });
