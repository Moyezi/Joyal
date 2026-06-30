import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_context.dart';
import '../providers/library_provider.dart';
import '../widgets/artist_content.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistId;
  final String artistName;

  const ArtistDetailScreen({
    super.key,
    required this.artistId,
    required this.artistName,
  });

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
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

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: ArtistContent(
              artist: state.artistDetail,
              albums: state.artistAlbums,
              songs: state.artistSongs,
              isLoading: state.isLoadingArtist,
              error: state.artistError,
              onRetry: _load,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: context.primaryColor,
                  tooltip: '返回',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
