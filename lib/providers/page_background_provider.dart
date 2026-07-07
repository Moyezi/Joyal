import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum PageBackgroundTarget {
  home('home', '首页'),
  library('library', '曲库'),
  favorites('favorites', '发现');

  const PageBackgroundTarget(this.storageName, this.label);

  final String storageName;
  final String label;
}

class PageBackgroundState {
  final String? imagePath;
  final double blurSigma;
  final bool isLoading;

  const PageBackgroundState({
    this.imagePath,
    this.blurSigma = 0,
    this.isLoading = true,
  });

  String? pathFor(PageBackgroundTarget target) => imagePath;

  PageBackgroundState copyWith({
    String? imagePath,
    double? blurSigma,
    bool? isLoading,
    bool clearImagePath = false,
  }) {
    return PageBackgroundState(
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      blurSigma: blurSigma ?? this.blurSigma,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PageBackgroundNotifier extends StateNotifier<PageBackgroundState> {
  PageBackgroundNotifier(this._storage) : super(const PageBackgroundState()) {
    _load();
  }

  static const _keyPath = 'page_background_path';
  static const _keyBlurSigma = 'page_background_blur_sigma';
  static const _keyPrefix = 'page_background_path_';

  final FlutterSecureStorage _storage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _load() async {
    String? imagePath = await _storage.read(key: _keyPath);
    if (imagePath == null ||
        imagePath.isEmpty ||
        !await File(imagePath).exists()) {
      await _storage.delete(key: _keyPath);
      imagePath = await _migrateLegacyPath();
    }

    final blurText = await _storage.read(key: _keyBlurSigma);
    final blurSigma = (double.tryParse(blurText ?? '') ?? 0)
        .clamp(0.0, 24.0)
        .toDouble();
    state = PageBackgroundState(
      imagePath: imagePath,
      blurSigma: blurSigma,
      isLoading: false,
    );
  }

  Future<bool> pickFor(PageBackgroundTarget target) async {
    return pick();
  }

  Future<bool> pick() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) return false;

    final oldPath = state.imagePath;
    final savedPath = await _copyToAppStorage(image);
    await _storage.write(key: _keyPath, value: savedPath);
    await _deleteFileIfExists(oldPath);

    state = state.copyWith(imagePath: savedPath, isLoading: false);
    return true;
  }

  Future<void> clear(PageBackgroundTarget target) async {
    await clearShared();
  }

  Future<void> clearShared() async {
    final oldPath = state.imagePath;
    await _storage.delete(key: _keyPath);
    await _deleteFileIfExists(oldPath);

    state = state.copyWith(clearImagePath: true, isLoading: false);
  }

  Future<void> setBlurSigma(double value) async {
    final next = value.clamp(0.0, 24.0).toDouble();
    await _storage.write(key: _keyBlurSigma, value: next.toStringAsFixed(1));
    state = state.copyWith(blurSigma: next, isLoading: false);
  }

  Future<String> _copyToAppStorage(XFile image) async {
    final directory = await getApplicationSupportDirectory();
    final backgroundsDir = Directory('${directory.path}/page_backgrounds');
    if (!await backgroundsDir.exists()) {
      await backgroundsDir.create(recursive: true);
    }

    final extension = _extensionFor(image.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destination = File(
      '${backgroundsDir.path}/shared_$timestamp$extension',
    );
    await image.saveTo(destination.path);
    return destination.path;
  }

  Future<String?> _migrateLegacyPath() async {
    for (final target in PageBackgroundTarget.values) {
      final key = _keyFor(target);
      final path = await _storage.read(key: key);
      if (path == null || path.isEmpty) continue;
      if (await File(path).exists()) {
        await _storage.write(key: _keyPath, value: path);
        return path;
      }
      await _storage.delete(key: key);
    }
    return null;
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _extensionFor(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) return '.jpg';
    final extension = path.substring(dotIndex).toLowerCase();
    if (extension.length > 6) return '.jpg';
    return extension;
  }

  static String _keyFor(PageBackgroundTarget target) =>
      '$_keyPrefix${target.storageName}';
}

final pageBackgroundProvider =
    StateNotifierProvider<PageBackgroundNotifier, PageBackgroundState>((ref) {
      return PageBackgroundNotifier(const FlutterSecureStorage());
    });
