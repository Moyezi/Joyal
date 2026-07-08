import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _colorModeKey = 'lyrics_color_mode';
const _alignmentKey = 'lyrics_alignment';
const _fontFamilyKey = 'lyrics_font_family';
const _fontSizeKey = 'lyrics_font_size';

enum LyricsColorMode {
  system('system', '跟随系统', '随当前深浅色自动切换黑白歌词'),
  black('black', '黑色字体', '始终使用黑色歌词'),
  white('white', '白色字体', '始终使用白色歌词'),
  dynamicLight('dynamic_light', '动态浅色', '从当前封面提取柔和浅色调');

  const LyricsColorMode(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;

  static LyricsColorMode fromStorageValue(String? value) {
    return LyricsColorMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => LyricsColorMode.system,
    );
  }
}

enum LyricsAlignmentMode {
  center('center', '居中对齐'),
  left('left', '左对齐'),
  justify('justify', '两端对齐');

  const LyricsAlignmentMode(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static LyricsAlignmentMode fromStorageValue(String? value) {
    return LyricsAlignmentMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => LyricsAlignmentMode.left,
    );
  }
}

enum LyricsFontFamily {
  system('system', '系统', null, []),
  hei('hei', '黑体', 'sans-serif', ['Roboto', 'Noto Sans CJK SC', 'PingFang SC']),
  rounded('rounded', '圆体', 'sans-serif-rounded', [
    'SF Pro Rounded',
    'PingFang SC',
    'sans-serif',
  ]),
  handwriting('handwriting', '手写体', 'casual', [
    'cursive',
    'Kaiti SC',
    'STKaiti',
    'serif',
  ]);

  const LyricsFontFamily(
    this.storageValue,
    this.label,
    this.fontFamily,
    this.fontFamilyFallback,
  );

  final String storageValue;
  final String label;
  final String? fontFamily;
  final List<String> fontFamilyFallback;

  static LyricsFontFamily fromStorageValue(String? value) {
    return LyricsFontFamily.values.firstWhere(
      (family) => family.storageValue == value,
      orElse: () => LyricsFontFamily.system,
    );
  }
}

class LyricsPersonalizationState {
  static const double minFontSize = 20;
  static const double maxFontSize = 44;
  static const double defaultFontSize = 30;

  final LyricsColorMode colorMode;
  final LyricsAlignmentMode alignment;
  final LyricsFontFamily fontFamily;
  final double fontSize;
  final bool isLoading;

  const LyricsPersonalizationState({
    this.colorMode = LyricsColorMode.system,
    this.alignment = LyricsAlignmentMode.left,
    this.fontFamily = LyricsFontFamily.system,
    this.fontSize = defaultFontSize,
    this.isLoading = true,
  });

  LyricsPersonalizationState copyWith({
    LyricsColorMode? colorMode,
    LyricsAlignmentMode? alignment,
    LyricsFontFamily? fontFamily,
    double? fontSize,
    bool? isLoading,
  }) {
    return LyricsPersonalizationState(
      colorMode: colorMode ?? this.colorMode,
      alignment: alignment ?? this.alignment,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LyricsPersonalizationNotifier
    extends StateNotifier<LyricsPersonalizationState> {
  LyricsPersonalizationNotifier() : super(const LyricsPersonalizationState()) {
    _load();
  }

  Future<void> _load() async {
    final colorMode = LyricsColorMode.fromStorageValue(
      await _storage.read(key: _colorModeKey),
    );
    final alignment = LyricsAlignmentMode.fromStorageValue(
      await _storage.read(key: _alignmentKey),
    );
    final fontFamily = LyricsFontFamily.fromStorageValue(
      await _storage.read(key: _fontFamilyKey),
    );
    final savedFontSize = double.tryParse(
      await _storage.read(key: _fontSizeKey) ?? '',
    );
    final fontSize =
        (savedFontSize ?? LyricsPersonalizationState.defaultFontSize)
            .clamp(
              LyricsPersonalizationState.minFontSize,
              LyricsPersonalizationState.maxFontSize,
            )
            .toDouble();

    state = LyricsPersonalizationState(
      colorMode: colorMode,
      alignment: alignment,
      fontFamily: fontFamily,
      fontSize: fontSize,
      isLoading: false,
    );
  }

  Future<void> setColorMode(LyricsColorMode mode) async {
    if (state.colorMode == mode && !state.isLoading) return;
    state = state.copyWith(colorMode: mode, isLoading: false);
    await _storage.write(key: _colorModeKey, value: mode.storageValue);
  }

  Future<void> setAlignment(LyricsAlignmentMode alignment) async {
    if (state.alignment == alignment && !state.isLoading) return;
    state = state.copyWith(alignment: alignment, isLoading: false);
    await _storage.write(key: _alignmentKey, value: alignment.storageValue);
  }

  Future<void> setFontFamily(LyricsFontFamily fontFamily) async {
    if (state.fontFamily == fontFamily && !state.isLoading) return;
    state = state.copyWith(fontFamily: fontFamily, isLoading: false);
    await _storage.write(key: _fontFamilyKey, value: fontFamily.storageValue);
  }

  Future<void> setFontSize(double value) async {
    final next = value
        .clamp(
          LyricsPersonalizationState.minFontSize,
          LyricsPersonalizationState.maxFontSize,
        )
        .toDouble();
    state = state.copyWith(fontSize: next, isLoading: false);
    await _storage.write(key: _fontSizeKey, value: next.toStringAsFixed(1));
  }

  Future<void> reset() async {
    state = const LyricsPersonalizationState(isLoading: false);
    await Future.wait([
      _storage.delete(key: _colorModeKey),
      _storage.delete(key: _alignmentKey),
      _storage.delete(key: _fontFamilyKey),
      _storage.delete(key: _fontSizeKey),
    ]);
  }
}

final lyricsPersonalizationProvider =
    StateNotifierProvider<
      LyricsPersonalizationNotifier,
      LyricsPersonalizationState
    >((ref) {
      return LyricsPersonalizationNotifier();
    });
