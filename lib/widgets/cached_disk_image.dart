import 'dart:collection';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

String stableImageCacheKey(String prefix, String url) {
  final normalized = _normalizedImageIdentity(url);
  final digest = sha1.convert(normalized.codeUnits).toString();
  return '${prefix}_$digest';
}

String _normalizedImageIdentity(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;
  return uri.removeFragment().replace(queryParameters: const {}).toString();
}

int physicalImageCacheWidth(
  BuildContext context,
  double logicalWidth, {
  int maxWidth = 4096,
}) {
  final physicalWidth = (logicalWidth * MediaQuery.devicePixelRatioOf(context))
      .ceil();
  return physicalWidth.clamp(1, maxWidth).toInt();
}

/// Prevents newly mounted images from starting decode work while a large UI
/// transition is in progress. Images that were already presented stay alive.
class ImageLoadingScope extends InheritedWidget {
  final bool enabled;

  const ImageLoadingScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  static bool enabledOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ImageLoadingScope>()
            ?.enabled ??
        true;
  }

  @override
  bool updateShouldNotify(ImageLoadingScope oldWidget) {
    return enabled != oldWidget.enabled;
  }
}

class CachedDiskImage extends StatefulWidget {
  final String imageUrl;
  final String cacheKey;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final double? decodeWidth;

  const CachedDiskImage({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    required this.placeholderBuilder,
    this.errorBuilder,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 120),
    this.fadeOutDuration = const Duration(milliseconds: 80),
    this.decodeWidth,
  });

  @override
  State<CachedDiskImage> createState() => _CachedDiskImageState();
}

class _CachedDiskImageState extends State<CachedDiskImage> {
  static const int _maxRememberedKeys = 256;
  static final BaseCacheManager _cacheManager = DefaultCacheManager();
  static final LinkedHashMap<String, File> _memoryFiles = LinkedHashMap();
  static final LinkedHashSet<String> _loadedKeys = LinkedHashSet();
  static final Map<String, Future<File?>> _pendingDiskLookups = {};

  File? _file;
  late String _cacheKey;
  String? _cacheLookupKey;
  bool _checkedDiskCache = false;
  bool _hasPresentedImage = false;
  bool _routeIsReady = true;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _cacheKey = widget.cacheKey;
    _file = _rememberedFile(_cacheKey);
    if (_file == null) {
      _loadCachedFile();
    } else {
      _checkedDiskCache = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAnimation = ModalRoute.of(context)?.animation;
    if (identical(nextAnimation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _routeAnimation = nextAnimation;
    _routeIsReady =
        nextAnimation == null ||
        nextAnimation.status == AnimationStatus.completed;
    nextAnimation?.addStatusListener(_handleRouteStatus);
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _routeIsReady || !mounted) {
      return;
    }
    setState(() => _routeIsReady = true);
  }

  @override
  void didUpdateWidget(covariant CachedDiskImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey == widget.cacheKey &&
        oldWidget.imageUrl == widget.imageUrl) {
      return;
    }
    _cacheKey = widget.cacheKey;
    _file = _rememberedFile(_cacheKey);
    _checkedDiskCache = _file != null;
    _hasPresentedImage = false;
    if (_file == null) {
      _loadCachedFile();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    super.dispose();
  }

  Future<void> _loadCachedFile() async {
    final key = widget.cacheKey;
    if (_cacheLookupKey == key) return;
    _cacheLookupKey = key;
    try {
      final file = await _cachedFileFor(key);
      if (!mounted || key != _cacheKey) return;
      if (file != null) {
        _rememberFile(key, file);
        _rememberLoadedKey(key);
      }
      setState(() {
        _file = file;
        _checkedDiskCache = true;
      });
    } catch (_) {
      // A cache miss should fall through to the network image.
      if (!mounted || key != _cacheKey) return;
      setState(() => _checkedDiskCache = true);
    } finally {
      if (_cacheLookupKey == key) {
        _cacheLookupKey = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeWidth = _effectiveDecodeWidth(constraints);
        return _buildImage(context, decodeWidth);
      },
    );
  }

  Widget _buildImage(BuildContext context, double? decodeWidth) {
    final canPresentImage =
        _hasPresentedImage ||
        (_routeIsReady && ImageLoadingScope.enabledOf(context));
    if (!canPresentImage) {
      return widget.placeholderBuilder(context);
    }

    final file = _file;
    if (file != null) {
      _hasPresentedImage = true;
      return Image.file(
        file,
        fit: widget.fit,
        cacheWidth: _decodeWidthFor(context, decodeWidth),
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          _memoryFiles.remove(widget.cacheKey);
          return _NetworkImage(
            widget: widget,
            decodeWidth: decodeWidth,
            showPlaceholder: true,
            onImageLoaded: _markImageLoaded,
          );
        },
      );
    }

    if (widget.imageUrl.isEmpty) {
      return widget.placeholderBuilder(context);
    }

    if (!_checkedDiskCache && !_loadedKeys.contains(widget.cacheKey)) {
      return const SizedBox.expand();
    }

    _hasPresentedImage = true;
    return _NetworkImage(
      widget: widget,
      decodeWidth: decodeWidth,
      showPlaceholder: !_loadedKeys.contains(widget.cacheKey),
      onImageLoaded: _markImageLoaded,
    );
  }

  double? _effectiveDecodeWidth(BoxConstraints constraints) {
    final requestedWidth = widget.decodeWidth;
    if (requestedWidth != null &&
        requestedWidth.isFinite &&
        requestedWidth > 0) {
      return requestedWidth;
    }
    if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
      return constraints.maxWidth;
    }
    if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
      return constraints.maxHeight;
    }
    return null;
  }

  void _markImageLoaded() {
    _rememberLoadedKey(widget.cacheKey);
    if (_memoryFiles.containsKey(widget.cacheKey)) return;
    _loadCachedFile();
  }

  static File? _rememberedFile(String key) {
    final file = _memoryFiles.remove(key);
    if (file != null) _memoryFiles[key] = file;
    return file;
  }

  static void _rememberFile(String key, File file) {
    _memoryFiles.remove(key);
    _memoryFiles[key] = file;
    while (_memoryFiles.length > _maxRememberedKeys) {
      _memoryFiles.remove(_memoryFiles.keys.first);
    }
  }

  static void _rememberLoadedKey(String key) {
    _loadedKeys.remove(key);
    _loadedKeys.add(key);
    while (_loadedKeys.length > _maxRememberedKeys) {
      _loadedKeys.remove(_loadedKeys.first);
    }
  }

  static Future<File?> _cachedFileFor(String key) {
    final pending = _pendingDiskLookups[key];
    if (pending != null) return pending;

    late final Future<File?> lookup;
    final operation = _cacheManager
        .getFileFromCache(key)
        .then((info) => info?.file);
    lookup = operation.whenComplete(() {
      if (identical(_pendingDiskLookups[key], lookup)) {
        _pendingDiskLookups.remove(key);
      }
    });
    _pendingDiskLookups[key] = lookup;
    return lookup;
  }
}

class _NetworkImage extends StatelessWidget {
  final CachedDiskImage widget;
  final double? decodeWidth;
  final bool showPlaceholder;
  final VoidCallback onImageLoaded;

  const _NetworkImage({
    required this.widget,
    required this.decodeWidth,
    required this.showPlaceholder,
    required this.onImageLoaded,
  });

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return widget.placeholderBuilder(context);
    }
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      cacheKey: widget.cacheKey,
      fit: widget.fit,
      memCacheWidth: _decodeWidthFor(context, decodeWidth),
      imageBuilder: (context, imageProvider) {
        onImageLoaded();
        return Image(
          image: imageProvider,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
      placeholder: showPlaceholder
          ? (context, url) => widget.placeholderBuilder(context)
          : null,
      errorWidget: (context, url, error) =>
          widget.errorBuilder?.call(context, error) ??
          widget.placeholderBuilder(context),
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: widget.fadeOutDuration,
    );
  }
}

int? _decodeWidthFor(BuildContext context, double? logicalWidth) {
  if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
    return null;
  }
  return physicalImageCacheWidth(context, logicalWidth);
}
