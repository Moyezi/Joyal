import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _blurKeyPrefix = 'glass_effect_blur_';
const _opacityKeyPrefix = 'glass_effect_opacity_';

enum GlassEffectTarget {
  topBar('top_bar', '顶栏', 10, 0.46),
  miniPlayer('mini_player', '迷你播放栏', 18, 0.58),
  searchBar('search_bar', '搜索框', 16, 0.40),
  bottomNav('bottom_nav', '导航栏', 18, 0.48),
  songCard('song_card', '歌曲卡片', 14, 0.42),
  lyricsPage('lyrics_page', '歌词页', 14, 0.33);

  const GlassEffectTarget(
    this.storageName,
    this.label,
    this.defaultBlur,
    this.defaultOpacity,
  );

  final String storageName;
  final String label;
  final double defaultBlur;
  final double defaultOpacity;
}

class GlassEffectState {
  final Map<GlassEffectTarget, double> blurSigmas;
  final Map<GlassEffectTarget, double> tintOpacities;
  final bool isLoading;

  const GlassEffectState({
    required this.blurSigmas,
    required this.tintOpacities,
    this.isLoading = true,
  });

  factory GlassEffectState.defaults({bool isLoading = true}) {
    return GlassEffectState(
      blurSigmas: {
        for (final target in GlassEffectTarget.values)
          target: target.defaultBlur,
      },
      tintOpacities: {
        for (final target in GlassEffectTarget.values)
          target: target.defaultOpacity,
      },
      isLoading: isLoading,
    );
  }

  double blurFor(GlassEffectTarget target) =>
      blurSigmas[target] ?? target.defaultBlur;

  double opacityFor(GlassEffectTarget target) =>
      tintOpacities[target] ?? target.defaultOpacity;

  GlassEffectState copyWith({
    Map<GlassEffectTarget, double>? blurSigmas,
    Map<GlassEffectTarget, double>? tintOpacities,
    bool? isLoading,
  }) {
    return GlassEffectState(
      blurSigmas: blurSigmas ?? this.blurSigmas,
      tintOpacities: tintOpacities ?? this.tintOpacities,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GlassEffectNotifier extends StateNotifier<GlassEffectState> {
  GlassEffectNotifier() : super(GlassEffectState.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final blurValues = <GlassEffectTarget, double>{};
    final opacityValues = <GlassEffectTarget, double>{};
    for (final target in GlassEffectTarget.values) {
      final savedBlur = await _storage.read(key: _blurKeyFor(target));
      blurValues[target] =
          (double.tryParse(savedBlur ?? '') ?? target.defaultBlur)
              .clamp(0.0, 30.0)
              .toDouble();

      final savedOpacity = await _storage.read(key: _opacityKeyFor(target));
      opacityValues[target] =
          (double.tryParse(savedOpacity ?? '') ?? target.defaultOpacity)
              .clamp(0.0, 1.0)
              .toDouble();
    }
    state = GlassEffectState(
      blurSigmas: blurValues,
      tintOpacities: opacityValues,
      isLoading: false,
    );
  }

  Future<void> setBlur(GlassEffectTarget target, double value) async {
    final next = value.clamp(0.0, 30.0).toDouble();
    state = state.copyWith(
      blurSigmas: {...state.blurSigmas, target: next},
      isLoading: false,
    );
    await _storage.write(
      key: _blurKeyFor(target),
      value: next.toStringAsFixed(1),
    );
  }

  Future<void> setOpacity(GlassEffectTarget target, double value) async {
    final next = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(
      tintOpacities: {...state.tintOpacities, target: next},
      isLoading: false,
    );
    await _storage.write(
      key: _opacityKeyFor(target),
      value: next.toStringAsFixed(2),
    );
  }

  static String _blurKeyFor(GlassEffectTarget target) =>
      '$_blurKeyPrefix${target.storageName}';

  static String _opacityKeyFor(GlassEffectTarget target) =>
      '$_opacityKeyPrefix${target.storageName}';
}

final glassEffectProvider =
    StateNotifierProvider<GlassEffectNotifier, GlassEffectState>((ref) {
      return GlassEffectNotifier();
    });
