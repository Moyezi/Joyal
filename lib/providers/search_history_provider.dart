import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_provider.dart';

const _historyKey = 'search_history';

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final FlutterSecureStorage _storage;

  SearchHistoryNotifier(this._storage) : super(const []);

  Future<void> load() async {
    try {
      final value = await _storage.read(key: _historyKey);
      if (value == null) return;
      final decoded = jsonDecode(value) as List<dynamic>;
      state = decoded.whereType<String>().take(10).toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> add(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final updated = [
      normalized,
      ...state.where((item) => item.toLowerCase() != normalized.toLowerCase()),
    ].take(10).toList();
    state = updated;
    try {
      await _persist();
    } catch (_) {
      // Keep the in-memory history available if persistence is unavailable.
    }
  }

  Future<void> clear() async {
    state = const [];
    try {
      await _storage.delete(key: _historyKey);
    } catch (_) {
      // The visible history has already been cleared.
    }
  }

  Future<void> _persist() =>
      _storage.write(key: _historyKey, value: jsonEncode(state));
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
      final storage = ref.watch(secureStorageProvider);
      return SearchHistoryNotifier(storage)..load();
    });
