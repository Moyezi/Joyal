import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_context.dart';
import '../providers/library_provider.dart';
import 'artist_content.dart';

/// Shows the artist detail as a draggable bottom sheet.
Future<void> showArtistSheet(
  BuildContext context, {
  required String artistId,
  required String artistName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (sheetContext) => _ArtistSheetBody(
      artistId: artistId,
      artistName: artistName,
    ),
  );
}

class _ArtistSheetBody extends ConsumerStatefulWidget {
  final String artistId;
  final String artistName;

  const _ArtistSheetBody({
    required this.artistId,
    required this.artistName,
  });

  @override
  ConsumerState<_ArtistSheetBody> createState() => _ArtistSheetBodyState();
}

class _ArtistSheetBodyState extends ConsumerState<_ArtistSheetBody> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final notifier = ref.read(libraryProvider.notifier);
    await Future.wait([
      notifier.fetchArtistDetail(widget.artistId),
      notifier.fetchArtistSongs(widget.artistName),
    ]);
  }

  @override
  void dispose() {
    ref.read(libraryProvider.notifier).clearArtistDetail();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.secondaryColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Content
              Expanded(
                child: ArtistContent(
                  showBackButton: false,
                  artist: state.artistDetail,
                  albums: state.artistAlbums,
                  songs: state.artistSongs,
                  isLoading: state.isLoadingArtist,
                  error: state.artistError,
                  onRetry: _load,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
