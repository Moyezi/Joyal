import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _keyPrefix = 'glass_effect_blur_';

enum GlassEffectTarget {
  topBar('top_bar', '顶栏', 10),
  miniPlayer('mini_player', '迷你播放栏', 18),
  searchBar('search_bar', '搜索框', 16),
  bottomNav('bottom_nav', '导航栏', 18);

  const GlassEffectTarget(this.storageName, this.label, this.defaultBlur);

  final String storageName;
  final String label;
  final double defaultBlur;
}

class GlassEffectState {
  final Map<GlassEffectTarget, double> blurSigmas;
  final bool isLoading;

  const GlassEffectState({required this.blurSigmas, this.isLoading = true});

  factory GlassEffectState.defaults({bool isLoading = true}) {
    return GlassEffectState(
      blurSigmas: {
        for (final target in GlassEffectTarget.values)
          target: target.defaultBlur,
      },
      isLoading: isLoading,
    );
  }

  double blurFor(GlassEffectTarget target) =>
      blurSigmas[target] ?? target.defaultBlur;

  GlassEffectState copyWith({
    Map<GlassEffectTarget, double>? blurSigmas,
    bool? isLoading,
  }) {
    return GlassEffectState(
      blurSigmas: blurSigmas ?? this.blurSigmas,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GlassEffectNotifier extends StateNotifier<GlassEffectState> {
  GlassEffectNotifier() : super(GlassEffectState.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final values = <GlassEffectTarget, double>{};
    for (final target in GlassEffectTarget.values) {
      final saved = await _storage.read(key: _keyFor(target));
      values[target] = (double.tryParse(saved ?? '') ?? target.defaultBlur)
          .clamp(0.0, 30.0)
          .toDouble();
    }
    state = GlassEffectState(blurSigmas: values, isLoading: false);
  }

  Future<void> setBlur(GlassEffectTarget target, double value) async {
    final next = value.clamp(0.0, 30.0).toDouble();
    state = state.copyWith(
      blurSigmas: {...state.blurSigmas, target: next},
      isLoading: false,
    );
    await _storage.write(key: _keyFor(target), value: next.toStringAsFixed(1));
  }

  static String _keyFor(GlassEffectTarget target) =>
      '$_keyPrefix${target.storageName}';
}

final glassEffectProvider =
    StateNotifierProvider<GlassEffectNotifier, GlassEffectState>((ref) {
      return GlassEffectNotifier();
    });
