import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/floating_name_ai_palette.dart';
import 'app_cache_service.dart';

class FloatingNameAiPaletteRepository {
  final AppCacheService _cache;

  const FloatingNameAiPaletteRepository(this._cache);

  String _cacheName(String serverScope, String songId) {
    final id = sha1.convert(utf8.encode('$serverScope|$songId'));
    return 'floating_name_palette_$id';
  }

  Future<FloatingNameAiPalette?> load(String serverScope, String songId) async {
    final json = await _cache.readJson(_cacheName(serverScope, songId));
    if (json == null) return null;
    try {
      return FloatingNameAiPalette.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    String serverScope,
    String songId,
    FloatingNameAiPalette palette,
  ) async {
    await _cache.writeJson(_cacheName(serverScope, songId), palette.toJson());
    await _cache.prune(
      prefix: 'floating_name_palette_',
      maxFiles: 400,
      maxAge: const Duration(days: 365),
    );
  }
}
