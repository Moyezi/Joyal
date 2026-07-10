import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _blurKeyPrefix = 'glass_effect_blur_';
const _opacityKeyPrefix = 'glass_effect_opacity_';
const _liquidGlassEnabledKey = 'glass_effect_liquid_enabled';

enum GlassEffectTarget {
  topBar('top_bar', '顶栏', 10, 0.46),
  miniPlayer('mini_player', '迷你播放栏', 18, 0.58),
  searchBar('search_bar', '搜索框', 16, 0.40),
  bottomNav('bottom_nav', '导航栏', 18, 0.48),
  nowPlayingControls('now_playing_controls', '播放控制栏', 18, 0.48),
  songCard('song_card', '歌曲卡片', 14, 0.42),
  lyricsPage('lyrics_page', '非当前歌词', 5, 0.50),
  lyricsDrawer('lyrics_drawer', '歌词抽屉', 14, 0.33);

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
  final bool liquidGlassEnabled;
  final bool isLoading;

  const GlassEffectState({
    required this.blurSigmas,
    required this.tintOpacities,
    this.liquidGlassEnabled = false,
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
      liquidGlassEnabled: false,
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
    bool? liquidGlassEnabled,
    bool? isLoading,
  }) {
    return GlassEffectState(
      blurSigmas: blurSigmas ?? this.blurSigmas,
      tintOpacities: tintOpacities ?? this.tintOpacities,
      liquidGlassEnabled: liquidGlassEnabled ?? this.liquidGlassEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GlassEffectNotifier extends StateNotifier<GlassEffectState> {
  GlassEffectNotifier() : super(GlassEffectState.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>([
      Future.wait(
        GlassEffectTarget.values.map((target) async {
          final values = await Future.wait([
            _storage.read(key: _blurKeyFor(target)),
            _storage.read(key: _opacityKeyFor(target)),
          ]);
          return _LoadedGlassEffect(
            target: target,
            blur: (double.tryParse(values[0] ?? '') ?? target.defaultBlur)
                .clamp(0.0, 30.0)
                .toDouble(),
            opacity: (double.tryParse(values[1] ?? '') ?? target.defaultOpacity)
                .clamp(0.0, 1.0)
                .toDouble(),
          );
        }),
      ),
      _storage.read(key: _liquidGlassEnabledKey),
    ]);
    final loaded = results[0] as List<_LoadedGlassEffect>;
    final liquidGlassEnabled = results[1] == 'true';
    state = GlassEffectState(
      blurSigmas: {for (final value in loaded) value.target: value.blur},
      tintOpacities: {for (final value in loaded) value.target: value.opacity},
      liquidGlassEnabled: liquidGlassEnabled,
      isLoading: false,
    );
  }

  Future<void> setBlur(
    GlassEffectTarget target,
    double value, {
    bool persist = true,
  }) async {
    final next = value.clamp(0.0, 30.0).toDouble();
    final current = state.blurFor(target);
    if ((current - next).abs() > 0.001 || state.isLoading) {
      state = state.copyWith(
        blurSigmas: {...state.blurSigmas, target: next},
        isLoading: false,
      );
    }
    if (persist) {
      await _storage.write(
        key: _blurKeyFor(target),
        value: next.toStringAsFixed(1),
      );
    }
  }

  Future<void> setOpacity(
    GlassEffectTarget target,
    double value, {
    bool persist = true,
  }) async {
    final next = value.clamp(0.0, 1.0).toDouble();
    final current = state.opacityFor(target);
    if ((current - next).abs() > 0.001 || state.isLoading) {
      state = state.copyWith(
        tintOpacities: {...state.tintOpacities, target: next},
        isLoading: false,
      );
    }
    if (persist) {
      await _storage.write(
        key: _opacityKeyFor(target),
        value: next.toStringAsFixed(2),
      );
    }
  }

  Future<void> setLiquidGlassEnabled(bool enabled) async {
    if (state.liquidGlassEnabled != enabled || state.isLoading) {
      state = state.copyWith(liquidGlassEnabled: enabled, isLoading: false);
    }
    await _storage.write(
      key: _liquidGlassEnabledKey,
      value: enabled ? 'true' : 'false',
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

class _LoadedGlassEffect {
  final GlassEffectTarget target;
  final double blur;
  final double opacity;

  const _LoadedGlassEffect({
    required this.target,
    required this.blur,
    required this.opacity,
  });
}
