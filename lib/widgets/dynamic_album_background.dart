import 'package:flutter/material.dart';

import 'album_visual_palette.dart';

/// A softly animated background derived from cached album artwork.
class DynamicAlbumBackground extends StatefulWidget {
  final String coverArtId;
  final String coverUrl;
  final Widget child;

  const DynamicAlbumBackground({
    super.key,
    required this.coverArtId,
    required this.coverUrl,
    required this.child,
  });

  @override
  State<DynamicAlbumBackground> createState() => _DynamicAlbumBackgroundState();
}

class _DynamicAlbumBackgroundState extends State<DynamicAlbumBackground> {
  late Color _top;
  late Color _bottom;
  bool _paletteLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_paletteLoaded) {
      final fallback = AlbumVisualPalette.fallbackFor(
        Theme.of(context).brightness,
      );
      _top = fallback.top;
      _bottom = fallback.bottom;
      _loadPalette();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicAlbumBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Authenticated cover URLs contain a fresh salt on every build. The cover
    // id is the stable identity and prevents repeated palette work per tick.
    if (widget.coverArtId != oldWidget.coverArtId) {
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    final brightness = Theme.of(context).brightness;
    final requestedId = widget.coverArtId;
    final palette = await AlbumVisualPalette.resolve(
      coverArtId: requestedId,
      coverUrl: widget.coverUrl,
      brightness: brightness,
    );
    if (!mounted || widget.coverArtId != requestedId) return;
    _paletteLoaded = true;
    setState(() {
      _top = palette.top;
      _bottom = palette.bottom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_top, _bottom, scaffoldBg],
          stops: const [0, 0.56, 1],
        ),
      ),
      child: widget.child,
    );
  }
}
