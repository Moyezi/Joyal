import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum PageBackgroundTarget {
  home('home', '首页'),
  library('library', '曲库'),
  favorites('favorites', '收藏');

  const PageBackgroundTarget(this.storageName, this.label);

  final String storageName;
  final String label;
}

class PageBackgroundState {
  final Map<PageBackgroundTarget, String> imagePaths;
  final bool isLoading;

  const PageBackgroundState({
    this.imagePaths = const {},
    this.isLoading = true,
  });

  String? pathFor(PageBackgroundTarget target) => imagePaths[target];

  PageBackgroundState copyWith({
    Map<PageBackgroundTarget, String>? imagePaths,
    bool? isLoading,
  }) {
    return PageBackgroundState(
      imagePaths: imagePaths ?? this.imagePaths,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PageBackgroundNotifier extends StateNotifier<PageBackgroundState> {
  PageBackgroundNotifier(this._storage) : super(const PageBackgroundState()) {
    _load();
  }

  static const _keyPrefix = 'page_background_path_';

  final FlutterSecureStorage _storage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _load() async {
    final paths = <PageBackgroundTarget, String>{};
    for (final target in PageBackgroundTarget.values) {
      final path = await _storage.read(key: _keyFor(target));
      if (path == null || path.isEmpty) continue;
      if (await File(path).exists()) {
        paths[target] = path;
      } else {
        await _storage.delete(key: _keyFor(target));
      }
    }
    state = PageBackgroundState(imagePaths: paths, isLoading: false);
  }

  Future<bool> pickFor(PageBackgroundTarget target) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) return false;

    final oldPath = state.pathFor(target);
    final savedPath = await _copyToAppStorage(image, target);
    await _storage.write(key: _keyFor(target), value: savedPath);
    await _deleteFileIfExists(oldPath);

    final next = Map<PageBackgroundTarget, String>.from(state.imagePaths)
      ..[target] = savedPath;
    state = state.copyWith(imagePaths: next, isLoading: false);
    return true;
  }

  Future<void> clear(PageBackgroundTarget target) async {
    final oldPath = state.pathFor(target);
    await _storage.delete(key: _keyFor(target));
    await _deleteFileIfExists(oldPath);

    final next = Map<PageBackgroundTarget, String>.from(state.imagePaths)
      ..remove(target);
    state = state.copyWith(imagePaths: next, isLoading: false);
  }

  Future<String> _copyToAppStorage(
    XFile image,
    PageBackgroundTarget target,
  ) async {
    final directory = await getApplicationSupportDirectory();
    final backgroundsDir = Directory('${directory.path}/page_backgrounds');
    if (!await backgroundsDir.exists()) {
      await backgroundsDir.create(recursive: true);
    }

    final extension = _extensionFor(image.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destination = File(
      '${backgroundsDir.path}/${target.storageName}_$timestamp$extension',
    );
    await image.saveTo(destination.path);
    return destination.path;
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
