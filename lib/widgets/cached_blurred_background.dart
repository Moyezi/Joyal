import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/blurred_background_cache.dart';

/// Uses the live blur while a matching reduced-raster PNG is being prepared,
/// then swaps to that static image until an input affecting the blur changes.
class CachedBlurredBackground extends StatefulWidget {
  final String cacheIdentity;
  final BlurredBackgroundSourceLoader loadSourceFile;
  final double blurSigma;
  final double rasterScale;
  final Widget liveFallback;
  final BoxFit fit;
  final Alignment alignment;
  final double contentScale;
  final Duration settleDelay;
  final bool cacheWritesEnabled;

  const CachedBlurredBackground({
    super.key,
    required this.cacheIdentity,
    required this.loadSourceFile,
    required this.blurSigma,
    required this.rasterScale,
    required this.liveFallback,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.contentScale = 1,
    this.settleDelay = const Duration(milliseconds: 260),
    this.cacheWritesEnabled = true,
  });

  @override
  State<CachedBlurredBackground> createState() =>
      _CachedBlurredBackgroundState();
}

class _CachedBlurredBackgroundState extends State<CachedBlurredBackground> {
  Timer? _settleTimer;
  String? _lastRequestedKey;
  String? _resolvedKey;
  File? _resolvedFile;
  int _generation = 0;

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!widget.cacheWritesEnabled ||
            !size.isFinite ||
            size.isEmpty ||
            widget.blurSigma <= 0.05) {
          _cancelPending();
          return widget.liveFallback;
        }
        final layout = BlurredBackgroundCacheLayout.fromLogicalSize(
          logicalSize: size,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          rasterScale: widget.rasterScale,
          logicalBlurSigma: widget.blurSigma,
        );
        final request = BlurredBackgroundCacheRequest(
          stableIdentity: widget.cacheIdentity,
          loadSourceFile: widget.loadSourceFile,
          layout: layout,
          fit: widget.fit,
          alignment: widget.alignment,
          contentScale: widget.contentScale,
        );
        _schedule(request);

        final file = _resolvedKey == request.presentationKey
            ? _resolvedFile
            : null;
        if (file == null) return widget.liveFallback;
        return Image.file(
          file,
          fit: BoxFit.fill,
          alignment: Alignment.center,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return widget.liveFallback;
          },
          errorBuilder: (context, error, stackTrace) => widget.liveFallback,
        );
      },
    );
  }

  void _schedule(BlurredBackgroundCacheRequest request) {
    final key = request.presentationKey;
    if (_lastRequestedKey == key) return;
    _lastRequestedKey = key;
    _settleTimer?.cancel();
    final generation = ++_generation;
    _settleTimer = Timer(widget.settleDelay, () async {
      final file = await BlurredBackgroundCache.instance.resolve(request);
      if (!mounted || generation != _generation || _lastRequestedKey != key) {
        return;
      }
      if (file == null) return;
      setState(() {
        _resolvedKey = key;
        _resolvedFile = file;
      });
    });
  }

  void _cancelPending() {
    if (_lastRequestedKey == null && _settleTimer == null) return;
    _settleTimer?.cancel();
    _settleTimer = null;
    _lastRequestedKey = null;
    _generation++;
  }
}
