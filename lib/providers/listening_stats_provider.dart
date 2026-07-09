import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_provider.dart';

class ListeningStatsState {
  final Set<String> heardSongIds;
  final List<String> recentSongIds;
  final bool isLoading;

  const ListeningStatsState({
    this.heardSongIds = const <String>{},
    this.recentSongIds = const <String>[],
    this.isLoading = true,
  });

  int get heardSongCount => heardSongIds.length;

  ListeningStatsState copyWith({
    Set<String>? heardSongIds,
    List<String>? recentSongIds,
    bool? isLoading,
  }) {
    return ListeningStatsState(
      heardSongIds: heardSongIds ?? this.heardSongIds,
      recentSongIds: recentSongIds ?? this.recentSongIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ListeningStatsNotifier extends StateNotifier<ListeningStatsState> {
  static const maxRecentSongs = 24;
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
      final recentSongIds = _dedupeRecentSongIds(
        (json['recentSongIds'] as List<dynamic>? ?? []).whereType<String>(),
      );
      state = ListeningStatsState(
        heardSongIds: Set.unmodifiable(heardSongIds),
        recentSongIds: List.unmodifiable(recentSongIds),
        isLoading: false,
      );
    } catch (_) {
      state = const ListeningStatsState(isLoading: false);
    }
  }

  Future<void> markSongHeard(String songId) async {
    if (songId.isEmpty) return;
    await _initialization;

    final alreadyHeard = state.heardSongIds.contains(songId);
    final recentSongIds = _dedupeRecentSongIds([
      songId,
      ...state.recentSongIds.where((id) => id != songId),
    ]);
    final recentUnchanged = _sameOrderedIds(state.recentSongIds, recentSongIds);
    if (alreadyHeard && recentUnchanged) return;

    final heardSongIds = alreadyHeard
        ? state.heardSongIds
        : Set.unmodifiable({...state.heardSongIds, songId});
    state = state.copyWith(
      heardSongIds: heardSongIds,
      recentSongIds: List.unmodifiable(recentSongIds),
    );
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode({
          'heardSongIds': state.heardSongIds.toList(),
          'recentSongIds': state.recentSongIds,
        }),
      );
    } catch (_) {
      // Listening stats are nice-to-have and must never interrupt playback.
    }
  }

  static List<String> _dedupeRecentSongIds(Iterable<String> songIds) {
    final seen = <String>{};
    final recent = <String>[];
    for (final songId in songIds) {
      if (songId.isEmpty || !seen.add(songId)) continue;
      recent.add(songId);
      if (recent.length == maxRecentSongs) break;
    }
    return recent;
  }

  static bool _sameOrderedIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final listeningStatsProvider =
    StateNotifierProvider<ListeningStatsNotifier, ListeningStatsState>((ref) {
      return ListeningStatsNotifier(ref.watch(secureStorageProvider));
    });
