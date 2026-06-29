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

class CachedDiskImage extends StatefulWidget {
  final String imageUrl;
  final String cacheKey;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  const CachedDiskImage({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    required this.placeholderBuilder,
    this.errorBuilder,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 120),
    this.fadeOutDuration = const Duration(milliseconds: 80),
  });

  @override
  State<CachedDiskImage> createState() => _CachedDiskImageState();
}

class _CachedDiskImageState extends State<CachedDiskImage> {
  static final Map<String, File> _memoryFiles = {};
  static final Set<String> _loadedKeys = {};

  File? _file;
  late String _cacheKey;
  String? _cacheLookupKey;
  bool _checkedDiskCache = false;

  @override
  void initState() {
    super.initState();
    _cacheKey = widget.cacheKey;
    _file = _memoryFiles[_cacheKey];
    if (_file == null) {
      _loadCachedFile();
    } else {
      _checkedDiskCache = true;
    }
  }

  @override
  void didUpdateWidget(covariant CachedDiskImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey == widget.cacheKey &&
        oldWidget.imageUrl == widget.imageUrl) {
      return;
    }
    _cacheKey = widget.cacheKey;
    _file = _memoryFiles[_cacheKey];
    _checkedDiskCache = _file != null;
    if (_file == null) {
      _loadCachedFile();
    }
  }

  Future<void> _loadCachedFile() async {
    final key = widget.cacheKey;
    if (_cacheLookupKey == key) return;
    _cacheLookupKey = key;
    try {
      final info = await DefaultCacheManager().getFileFromCache(key);
      final file = info?.file;
      if (!mounted || key != _cacheKey) return;
      if (file != null) {
        _memoryFiles[key] = file;
        _loadedKeys.add(key);
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
    final file = _file;
    if (file != null) {
      return Image.file(
        file,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          _memoryFiles.remove(widget.cacheKey);
          return _NetworkImage(
            widget: widget,
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

    return _NetworkImage(
      widget: widget,
      showPlaceholder: !_loadedKeys.contains(widget.cacheKey),
      onImageLoaded: _markImageLoaded,
    );
  }

  void _markImageLoaded() {
    _loadedKeys.add(widget.cacheKey);
    if (_memoryFiles.containsKey(widget.cacheKey)) return;
    _loadCachedFile();
  }
}

class _NetworkImage extends StatelessWidget {
  final CachedDiskImage widget;
  final bool showPlaceholder;
  final VoidCallback onImageLoaded;

  const _NetworkImage({
    required this.widget,
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
