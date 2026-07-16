import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

const _storage = FlutterSecureStorage();
const _colorModeKey = 'lyrics_color_mode';
const _alignmentKey = 'lyrics_alignment';
const _fontFamilyKey = 'lyrics_font_family';
const _fontSizeKey = 'lyrics_font_size';
const _flowingLightFontSizeKey = 'lyrics_flowing_light_font_size';
const _floatingNameFontSizeKey = 'lyrics_floating_name_font_size';
const _aiColorEnabledKey = 'lyrics_ai_color_enabled';
const _legacyFloatingNameAiColorEnabledKey =
    'lyrics_floating_name_ai_color_enabled';
const _wordByWordEnabledKey = 'lyrics_word_by_word_enabled';
const _stageModeKey = 'lyrics_stage_mode';
const _customFontPathKey = 'lyrics_custom_font_path';
const _customFontNameKey = 'lyrics_custom_font_name';
const _customFontFamilyKey = 'lyrics_custom_font_family';
final Set<String> _loadedFontFamilies = <String>{};

enum LyricsColorMode {
  system('system', '跟随系统', '浅色使用柔和炭灰，深色使用白色歌词'),
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
  left('left', '左对齐'),
  center('center', '居中对齐'),
  right('right', '右对齐');

  const LyricsAlignmentMode(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static LyricsAlignmentMode fromStorageValue(String? value) {
    // Older builds exposed `justify`; preserve the user's right-side reading
    // preference when migrating to the clearer left/center/right choices.
    if (value == 'justify') return LyricsAlignmentMode.right;
    return LyricsAlignmentMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => LyricsAlignmentMode.left,
    );
  }
}

enum LyricsFontFamily {
  system('system', '系统'),
  custom('custom', '自定义');

  const LyricsFontFamily(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static LyricsFontFamily fromStorageValue(String? value) {
    return LyricsFontFamily.values.firstWhere(
      (family) => family.storageValue == value,
      orElse: () => LyricsFontFamily.system,
    );
  }
}

enum LyricsStageMode {
  defaultScroll('default_scroll', '默认滚动'),
  flowingLight('flowing_light', '流光'),
  floatingName('floating_name', '浮名'),
  chorus('chorus', '群唱');

  const LyricsStageMode(this.storageValue, this.label);

  final String storageValue;
  final String label;

  bool get isAvailable =>
      this == LyricsStageMode.defaultScroll ||
      this == LyricsStageMode.flowingLight ||
      this == LyricsStageMode.floatingName;

  static LyricsStageMode fromStorageValue(String? value) {
    final mode = LyricsStageMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => LyricsStageMode.defaultScroll,
    );
    return mode.isAvailable ? mode : LyricsStageMode.defaultScroll;
  }
}

class LyricsPersonalizationState {
  static const double minFontSize = 20;
  static const double maxFontSize = 44;
  static const double defaultFontSize = 30;
  static const double minFlowingLightFontSize = 28;
  static const double maxFlowingLightFontSize = 56;
  static const double defaultFlowingLightFontSize = 36;
  static const double minFloatingNameFontSize = 24;
  static const double maxFloatingNameFontSize = 52;
  static const double defaultFloatingNameFontSize = 34;

  final LyricsColorMode colorMode;
  final LyricsAlignmentMode alignment;
  final LyricsFontFamily fontFamily;
  final double fontSize;
  final double flowingLightFontSize;
  final double floatingNameFontSize;
  final bool aiColorEnabled;
  final bool wordByWordEnabled;
  final LyricsStageMode stageMode;
  final String? customFontPath;
  final String? customFontName;
  final String? customFontFamily;
  final bool isLoading;

  const LyricsPersonalizationState({
    this.colorMode = LyricsColorMode.system,
    this.alignment = LyricsAlignmentMode.left,
    this.fontFamily = LyricsFontFamily.system,
    this.fontSize = defaultFontSize,
    this.flowingLightFontSize = defaultFlowingLightFontSize,
    this.floatingNameFontSize = defaultFloatingNameFontSize,
    this.aiColorEnabled = false,
    this.wordByWordEnabled = true,
    this.stageMode = LyricsStageMode.defaultScroll,
    this.customFontPath,
    this.customFontName,
    this.customFontFamily,
    this.isLoading = true,
  });

  bool get hasCustomFont =>
      customFontPath != null &&
      customFontPath!.isNotEmpty &&
      customFontFamily != null &&
      customFontFamily!.isNotEmpty;

  String? get effectiveFontFamily {
    if (fontFamily != LyricsFontFamily.custom || !hasCustomFont) return null;
    return customFontFamily;
  }

  LyricsPersonalizationState copyWith({
    LyricsColorMode? colorMode,
    LyricsAlignmentMode? alignment,
    LyricsFontFamily? fontFamily,
    double? fontSize,
    double? flowingLightFontSize,
    double? floatingNameFontSize,
    bool? aiColorEnabled,
    bool? wordByWordEnabled,
    LyricsStageMode? stageMode,
    String? customFontPath,
    String? customFontName,
    String? customFontFamily,
    bool? isLoading,
    bool clearCustomFont = false,
  }) {
    return LyricsPersonalizationState(
      colorMode: colorMode ?? this.colorMode,
      alignment: alignment ?? this.alignment,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      flowingLightFontSize: flowingLightFontSize ?? this.flowingLightFontSize,
      floatingNameFontSize: floatingNameFontSize ?? this.floatingNameFontSize,
      aiColorEnabled: aiColorEnabled ?? this.aiColorEnabled,
      wordByWordEnabled: wordByWordEnabled ?? this.wordByWordEnabled,
      stageMode: stageMode ?? this.stageMode,
      customFontPath: clearCustomFont
          ? null
          : customFontPath ?? this.customFontPath,
      customFontName: clearCustomFont
          ? null
          : customFontName ?? this.customFontName,
      customFontFamily: clearCustomFont
          ? null
          : customFontFamily ?? this.customFontFamily,
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
    final savedFlowingLightFontSize = double.tryParse(
      await _storage.read(key: _flowingLightFontSizeKey) ?? '',
    );
    final savedFloatingNameFontSize = double.tryParse(
      await _storage.read(key: _floatingNameFontSizeKey) ?? '',
    );
    final savedAiColorEnabled =
        await _storage.read(key: _aiColorEnabledKey) ??
        await _storage.read(key: _legacyFloatingNameAiColorEnabledKey);
    final aiColorEnabled = savedAiColorEnabled == 'true';
    final wordByWordEnabled =
        await _storage.read(key: _wordByWordEnabledKey) != 'false';
    final stageMode = LyricsStageMode.fromStorageValue(
      await _storage.read(key: _stageModeKey),
    );
    var customFontPath = await _storage.read(key: _customFontPathKey);
    var customFontName = await _storage.read(key: _customFontNameKey);
    var customFontFamily = await _storage.read(key: _customFontFamilyKey);
    final fontSize =
        (savedFontSize ?? LyricsPersonalizationState.defaultFontSize)
            .clamp(
              LyricsPersonalizationState.minFontSize,
              LyricsPersonalizationState.maxFontSize,
            )
            .toDouble();
    final flowingLightFontSize =
        (savedFlowingLightFontSize ??
                LyricsPersonalizationState.defaultFlowingLightFontSize)
            .clamp(
              LyricsPersonalizationState.minFlowingLightFontSize,
              LyricsPersonalizationState.maxFlowingLightFontSize,
            )
            .toDouble();
    final floatingNameFontSize =
        (savedFloatingNameFontSize ??
                LyricsPersonalizationState.defaultFloatingNameFontSize)
            .clamp(
              LyricsPersonalizationState.minFloatingNameFontSize,
              LyricsPersonalizationState.maxFloatingNameFontSize,
            )
            .toDouble();
    var resolvedFontFamily = fontFamily;

    if (customFontPath == null ||
        customFontPath.isEmpty ||
        !await File(customFontPath).exists()) {
      customFontPath = null;
      customFontName = null;
      customFontFamily = null;
      if (resolvedFontFamily == LyricsFontFamily.custom) {
        resolvedFontFamily = LyricsFontFamily.system;
      }
      await Future.wait([
        _storage.delete(key: _customFontPathKey),
        _storage.delete(key: _customFontNameKey),
        _storage.delete(key: _customFontFamilyKey),
      ]);
    } else if (customFontFamily == null || customFontFamily.isEmpty) {
      customFontFamily = _newCustomFontFamilyName();
      await _storage.write(key: _customFontFamilyKey, value: customFontFamily);
    }

    if (customFontPath != null && customFontFamily != null) {
      final loaded = await _loadCustomFont(customFontPath, customFontFamily);
      if (!loaded) {
        await _deleteFileIfExists(customFontPath);
        await Future.wait([
          _storage.delete(key: _customFontPathKey),
          _storage.delete(key: _customFontNameKey),
          _storage.delete(key: _customFontFamilyKey),
        ]);
        customFontPath = null;
        customFontName = null;
        customFontFamily = null;
        if (resolvedFontFamily == LyricsFontFamily.custom) {
          resolvedFontFamily = LyricsFontFamily.system;
        }
      }
    }

    state = LyricsPersonalizationState(
      colorMode: colorMode,
      alignment: alignment,
      fontFamily: resolvedFontFamily,
      fontSize: fontSize,
      flowingLightFontSize: flowingLightFontSize,
      floatingNameFontSize: floatingNameFontSize,
      aiColorEnabled: aiColorEnabled,
      wordByWordEnabled: wordByWordEnabled,
      stageMode: stageMode,
      customFontPath: customFontPath,
      customFontName: customFontName,
      customFontFamily: customFontFamily,
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
    if (fontFamily == LyricsFontFamily.custom && !state.hasCustomFont) return;
    if (state.fontFamily == fontFamily && !state.isLoading) return;
    state = state.copyWith(fontFamily: fontFamily, isLoading: false);
    await _storage.write(key: _fontFamilyKey, value: fontFamily.storageValue);
  }

  Future<bool?> pickCustomFont() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    if (!_isTtfFile(picked)) return false;

    final oldPath = state.customFontPath;
    final family = _newCustomFontFamilyName();

    try {
      final savedPath = await _copyToAppStorage(picked);
      final loaded = await _loadCustomFont(savedPath, family);
      if (!loaded) {
        await _deleteFileIfExists(savedPath);
        return false;
      }

      await Future.wait([
        _storage.write(
          key: _fontFamilyKey,
          value: LyricsFontFamily.custom.storageValue,
        ),
        _storage.write(key: _customFontPathKey, value: savedPath),
        _storage.write(key: _customFontNameKey, value: picked.name),
        _storage.write(key: _customFontFamilyKey, value: family),
      ]);
      await _deleteFileIfExists(oldPath);

      state = state.copyWith(
        fontFamily: LyricsFontFamily.custom,
        customFontPath: savedPath,
        customFontName: picked.name,
        customFontFamily: family,
        isLoading: false,
      );
      return true;
    } catch (_) {
      return false;
    }
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

  Future<void> setFlowingLightFontSize(double value) async {
    final next = value
        .clamp(
          LyricsPersonalizationState.minFlowingLightFontSize,
          LyricsPersonalizationState.maxFlowingLightFontSize,
        )
        .toDouble();
    state = state.copyWith(flowingLightFontSize: next, isLoading: false);
    await _storage.write(
      key: _flowingLightFontSizeKey,
      value: next.toStringAsFixed(1),
    );
  }

  Future<void> setFloatingNameFontSize(double value) async {
    final next = value
        .clamp(
          LyricsPersonalizationState.minFloatingNameFontSize,
          LyricsPersonalizationState.maxFloatingNameFontSize,
        )
        .toDouble();
    state = state.copyWith(floatingNameFontSize: next, isLoading: false);
    await _storage.write(
      key: _floatingNameFontSizeKey,
      value: next.toStringAsFixed(1),
    );
  }

  Future<void> setAiColorEnabled(bool enabled) async {
    if (state.aiColorEnabled == enabled && !state.isLoading) {
      return;
    }
    state = state.copyWith(aiColorEnabled: enabled, isLoading: false);
    await _storage.write(key: _aiColorEnabledKey, value: enabled.toString());
    await _storage.delete(key: _legacyFloatingNameAiColorEnabledKey);
  }

  Future<void> setWordByWordEnabled(bool enabled) async {
    if (state.wordByWordEnabled == enabled && !state.isLoading) return;
    state = state.copyWith(wordByWordEnabled: enabled, isLoading: false);
    await _storage.write(key: _wordByWordEnabledKey, value: enabled.toString());
  }

  Future<void> setStageMode(LyricsStageMode mode) async {
    if (!mode.isAvailable) return;
    if (state.stageMode == mode && !state.isLoading) return;
    state = state.copyWith(stageMode: mode, isLoading: false);
    await _storage.write(key: _stageModeKey, value: mode.storageValue);
  }

  Future<void> reset() async {
    final oldPath = state.customFontPath;
    state = const LyricsPersonalizationState(isLoading: false);
    await Future.wait([
      _storage.delete(key: _colorModeKey),
      _storage.delete(key: _alignmentKey),
      _storage.delete(key: _fontFamilyKey),
      _storage.delete(key: _fontSizeKey),
      _storage.delete(key: _flowingLightFontSizeKey),
      _storage.delete(key: _floatingNameFontSizeKey),
      _storage.delete(key: _aiColorEnabledKey),
      _storage.delete(key: _legacyFloatingNameAiColorEnabledKey),
      _storage.delete(key: _wordByWordEnabledKey),
      _storage.delete(key: _stageModeKey),
      _storage.delete(key: _customFontPathKey),
      _storage.delete(key: _customFontNameKey),
      _storage.delete(key: _customFontFamilyKey),
    ]);
    await _deleteFileIfExists(oldPath);
  }

  Future<String> _copyToAppStorage(PlatformFile font) async {
    final directory = await getApplicationSupportDirectory();
    final fontsDir = Directory('${directory.path}/lyrics_fonts');
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destination = File('${fontsDir.path}/lyrics_$timestamp.ttf');
    if (font.path != null && font.path!.isNotEmpty) {
      await File(font.path!).copy(destination.path);
    } else if (font.bytes != null) {
      await destination.writeAsBytes(font.bytes!, flush: true);
    } else {
      throw const FileSystemException('No font data available');
    }
    return destination.path;
  }

  Future<bool> _loadCustomFont(String path, String family) async {
    if (_loadedFontFamilies.contains(family)) return true;

    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return false;

      final loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFontFamilies.add(family);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isTtfFile(PlatformFile file) {
    final name = file.name.toLowerCase();
    final path = file.path?.toLowerCase() ?? '';
    return name.endsWith('.ttf') || path.endsWith('.ttf');
  }

  String _newCustomFontFamilyName() {
    return 'JoyalLyricsCustomFont${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final lyricsPersonalizationProvider =
    StateNotifierProvider<
      LyricsPersonalizationNotifier,
      LyricsPersonalizationState
    >((ref) {
      return LyricsPersonalizationNotifier();
    });
