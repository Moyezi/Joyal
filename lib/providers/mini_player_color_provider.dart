import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _miniPlayerColorModeKey = 'mini_player_color_mode';

enum MiniPlayerColorMode {
  defaultColor('default_color', '默认颜色', '保持迷你播放栏原本的深色胶囊'),
  dynamicAlbum('dynamic_album', '动态取色', '根据当前专辑封面调整胶囊和悬浮封面外框');

  const MiniPlayerColorMode(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;
}

class MiniPlayerColorNotifier extends StateNotifier<MiniPlayerColorMode> {
  MiniPlayerColorNotifier() : super(MiniPlayerColorMode.defaultColor) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _miniPlayerColorModeKey);
    state = MiniPlayerColorMode.values.firstWhere(
      (mode) => mode.storageValue == saved,
      orElse: () => MiniPlayerColorMode.defaultColor,
    );
  }

  Future<void> setMode(MiniPlayerColorMode mode) async {
    if (state == mode) return;
    state = mode;
    await _storage.write(
      key: _miniPlayerColorModeKey,
      value: mode.storageValue,
    );
  }
}

final miniPlayerColorProvider =
    StateNotifierProvider<MiniPlayerColorNotifier, MiniPlayerColorMode>((ref) {
      return MiniPlayerColorNotifier();
    });
