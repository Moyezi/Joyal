import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _backgroundStyleKey = 'background_visual_style';

enum BackgroundVisualStyle { flowingHalo, staticGradient, albumCoverGlass }

class VisualEffectNotifier extends StateNotifier<BackgroundVisualStyle> {
  VisualEffectNotifier() : super(BackgroundVisualStyle.flowingHalo) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _backgroundStyleKey);
    state = switch (saved) {
      'staticGradient' => BackgroundVisualStyle.staticGradient,
      'albumCoverGlass' => BackgroundVisualStyle.albumCoverGlass,
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

class CoverGlassBackgroundState {
  static const defaultBlurSigma = 18.0;
  static const defaultOverlayOpacity = 0.46;
  static const minBlurSigma = 0.0;
  static const maxBlurSigma = 32.0;
  static const minOverlayOpacity = 0.12;
  static const maxOverlayOpacity = 0.80;

  final double blurSigma;
  final double overlayOpacity;
  final bool isLoading;

  const CoverGlassBackgroundState({
    this.blurSigma = defaultBlurSigma,
    this.overlayOpacity = defaultOverlayOpacity,
    this.isLoading = true,
  });

  CoverGlassBackgroundState copyWith({
    double? blurSigma,
    double? overlayOpacity,
    bool? isLoading,
  }) {
    return CoverGlassBackgroundState(
      blurSigma: blurSigma ?? this.blurSigma,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CoverGlassBackgroundNotifier
    extends StateNotifier<CoverGlassBackgroundState> {
  CoverGlassBackgroundNotifier() : super(const CoverGlassBackgroundState()) {
    _load();
  }

  static const _blurKey = 'playback_cover_glass_blur_sigma';
  static const _overlayOpacityKey = 'playback_cover_glass_overlay_opacity';

  Future<void> _load() async {
    final values = await Future.wait([
      _storage.read(key: _blurKey),
      _storage.read(key: _overlayOpacityKey),
    ]);
    if (!state.isLoading) return;

    final blurSigma =
        (double.tryParse(values[0] ?? '') ??
                CoverGlassBackgroundState.defaultBlurSigma)
            .clamp(
              CoverGlassBackgroundState.minBlurSigma,
              CoverGlassBackgroundState.maxBlurSigma,
            )
            .toDouble();
    final overlayOpacity =
        (double.tryParse(values[1] ?? '') ??
                CoverGlassBackgroundState.defaultOverlayOpacity)
            .clamp(
              CoverGlassBackgroundState.minOverlayOpacity,
              CoverGlassBackgroundState.maxOverlayOpacity,
            )
            .toDouble();
    state = CoverGlassBackgroundState(
      blurSigma: blurSigma,
      overlayOpacity: overlayOpacity,
      isLoading: false,
    );
  }

  Future<void> setBlurSigma(double value, {bool persist = true}) async {
    final next = value
        .clamp(
          CoverGlassBackgroundState.minBlurSigma,
          CoverGlassBackgroundState.maxBlurSigma,
        )
        .toDouble();
    state = state.copyWith(blurSigma: next, isLoading: false);
    if (persist) {
      await _storage.write(key: _blurKey, value: next.toStringAsFixed(1));
    }
  }

  Future<void> setOverlayOpacity(double value, {bool persist = true}) async {
    final next = value
        .clamp(
          CoverGlassBackgroundState.minOverlayOpacity,
          CoverGlassBackgroundState.maxOverlayOpacity,
        )
        .toDouble();
    state = state.copyWith(overlayOpacity: next, isLoading: false);
    if (persist) {
      await _storage.write(
        key: _overlayOpacityKey,
        value: next.toStringAsFixed(2),
      );
    }
  }
}

final coverGlassBackgroundProvider =
    StateNotifierProvider<
      CoverGlassBackgroundNotifier,
      CoverGlassBackgroundState
    >((ref) {
      return CoverGlassBackgroundNotifier();
    });
