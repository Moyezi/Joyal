import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _backgroundStyleKey = 'background_visual_style';

enum BackgroundVisualStyle { flowingHalo, staticGradient }

class VisualEffectNotifier extends StateNotifier<BackgroundVisualStyle> {
  VisualEffectNotifier() : super(BackgroundVisualStyle.flowingHalo) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _backgroundStyleKey);
    state = switch (saved) {
      'staticGradient' => BackgroundVisualStyle.staticGradient,
      _ => BackgroundVisualStyle.flowingHalo,
    };
  }

  Future<void> setBackgroundStyle(BackgroundVisualStyle style) async {
    if (state == style) return;
    state = style;
    await _storage.write(key: _backgroundStyleKey, value: style.name);
  }
}

final visualEffectProvider =
    StateNotifierProvider<VisualEffectNotifier, BackgroundVisualStyle>((ref) {
      return VisualEffectNotifier();
    });
