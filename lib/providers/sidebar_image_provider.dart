import 'dart:io';
import 'dart:ui';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class SidebarImageState {
  final String? imagePath;
  final double alignmentX;
  final double alignmentY;
  final bool isLoading;

  const SidebarImageState({
    this.imagePath,
    this.alignmentX = 0,
    this.alignmentY = 0,
    this.isLoading = true,
  });

  SidebarImageState copyWith({
    String? imagePath,
    double? alignmentX,
    double? alignmentY,
    bool? isLoading,
    bool clearImagePath = false,
  }) {
    return SidebarImageState(
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      alignmentX: alignmentX ?? this.alignmentX,
      alignmentY: alignmentY ?? this.alignmentY,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SidebarImageNotifier extends StateNotifier<SidebarImageState> {
  SidebarImageNotifier(this._storage) : super(const SidebarImageState()) {
    _load();
  }

  static const _keyPath = 'home_sidebar_image_path';
  static const _keyAlignmentX = 'home_sidebar_image_alignment_x';
  static const _keyAlignmentY = 'home_sidebar_image_alignment_y';

  final FlutterSecureStorage _storage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _load() async {
    String? imagePath = await _storage.read(key: _keyPath);
    if (imagePath == null ||
        imagePath.isEmpty ||
        !await File(imagePath).exists()) {
      await _storage.delete(key: _keyPath);
      imagePath = null;
    }

    final alignmentX = _parseAlignment(
      await _storage.read(key: _keyAlignmentX),
    );
    final alignmentY = _parseAlignment(
      await _storage.read(key: _keyAlignmentY),
    );

    state = SidebarImageState(
      imagePath: imagePath,
      alignmentX: alignmentX,
      alignmentY: alignmentY,
      isLoading: false,
    );
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
    await _storage.write(key: _keyAlignmentX, value: '0.000');
    await _storage.write(key: _keyAlignmentY, value: '0.000');
    await _deleteFileIfExists(oldPath);

    state = state.copyWith(
      imagePath: savedPath,
      alignmentX: 0,
      alignmentY: 0,
      isLoading: false,
    );
    return true;
  }

  Future<void> clear() async {
    final oldPath = state.imagePath;
    await _storage.delete(key: _keyPath);
    await _storage.delete(key: _keyAlignmentX);
    await _storage.delete(key: _keyAlignmentY);
    await _deleteFileIfExists(oldPath);

    state = state.copyWith(clearImagePath: true, isLoading: false);
  }

  Future<void> updateAlignmentFromDrag(Offset delta, Size size) async {
    if (size.width <= 0 || size.height <= 0) return;

    final nextX = (state.alignmentX - delta.dx / size.width * 2.0)
        .clamp(-1.0, 1.0)
        .toDouble();
    final nextY = (state.alignmentY - delta.dy / size.height * 2.0)
        .clamp(-1.0, 1.0)
        .toDouble();

    if ((nextX - state.alignmentX).abs() < 0.001 &&
        (nextY - state.alignmentY).abs() < 0.001) {
      return;
    }

    state = state.copyWith(alignmentX: nextX, alignmentY: nextY);
    await _storage.write(key: _keyAlignmentX, value: nextX.toStringAsFixed(3));
    await _storage.write(key: _keyAlignmentY, value: nextY.toStringAsFixed(3));
  }

  Future<String> _copyToAppStorage(XFile image) async {
    final directory = await getApplicationSupportDirectory();
    final imagesDir = Directory('${directory.path}/home_sidebar_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final extension = _extensionFor(image.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destination = File('${imagesDir.path}/sidebar_$timestamp$extension');
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

  double _parseAlignment(String? value) {
    return (double.tryParse(value ?? '') ?? 0).clamp(-1.0, 1.0).toDouble();
  }
}

final sidebarImageProvider =
    StateNotifierProvider<SidebarImageNotifier, SidebarImageState>((ref) {
      return SidebarImageNotifier(const FlutterSecureStorage());
    });
