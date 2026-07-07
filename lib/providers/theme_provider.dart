import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _key = 'theme_mode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved == 'light') {
      state = ThemeMode.light;
    } else if (saved == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> cycleMode() async {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    state = next;
    await _storage.write(key: _key, value: next.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

final isDarkProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  return switch (mode) {
    ThemeMode.light => false,
    ThemeMode.dark => true,
    ThemeMode.system => platformBrightness == Brightness.dark,
  };
});
