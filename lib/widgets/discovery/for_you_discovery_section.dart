import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/music_classification.dart';
import '../../models/song.dart';
import '../../providers/music_classification_provider.dart';
import 'discovery_card_models.dart';
import 'discovery_playlist_card.dart';
import 'discovery_section_header.dart';

class ForYouDiscoverySection extends ConsumerStatefulWidget {
  final List<Song> allSongs;
  final List<Song> starredSongs;
  final int refreshToken;

  const ForYouDiscoverySection({
    super.key,
    required this.allSongs,
    required this.starredSongs,
    required this.refreshToken,
  });

  @override
  ConsumerState<ForYouDiscoverySection> createState() =>
      _ForYouDiscoverySectionState();
}

class _ForYouDiscoverySectionState
    extends ConsumerState<ForYouDiscoverySection> {
  int? _cacheKey;
  List<Song>? _cachedAllSongs;
  List<Song>? _cachedStarredSongs;
  Map<String, SongClassification>? _cachedClassifications;
  int? _cachedRefreshToken;
  List<DiscoveryCardData> _cachedCards = const [];
  List<Song>? _tagIndexSongs;
  Map<String, SongClassification>? _tagIndexClassifications;
  Map<String, List<Song>> _tagIndex = const {};

  @override
  Widget build(BuildContext context) {
    if (widget.allSongs.isEmpty) return const SizedBox.shrink();
    final classifier = ref.watch(musicClassificationProvider);
    final cards = _cardsFor(classifier);

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DiscoverySectionHeader(title: '为你发现'),
        SizedBox(
          height: 176,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMD,
              4,
              AppTheme.spacingMD,
              8,
            ),
            itemCount: cards.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppTheme.spacingSM),
            itemBuilder: (context, index) {
              final card = cards[index];
              return DiscoveryPlaylistCard(data: card);
            },
          ),
        ),
      ],
    );
  }

  List<DiscoveryCardData> _cardsFor(MusicClassificationState classifier) {
    final seed = _todaySeed(31 + widget.refreshToken * 7919);
    final classifications = classifier.classifications;
    final canReuse =
        _cacheKey == seed &&
        _cachedRefreshToken == widget.refreshToken &&
        identical(_cachedAllSongs, widget.allSongs) &&
        identical(_cachedStarredSongs, widget.starredSongs) &&
        identical(_cachedClassifications, classifications);
    if (canReuse) return _cachedCards;

    final scenarios = DiscoveryScenario.presets;
    final cards = <DiscoveryCardData>[
      for (var i = 0; i < scenarios.length; i++)
        DiscoveryCardData(
          title: scenarios[i].title,
          subtitle: scenarios[i].subtitle,
          style: scenarios[i].style,
          songs: _songsForTags(
            scenarios[i].tags,
            seed + i * 101,
            classifications,
          ).take(24).toList(),
        ),
      DiscoveryCardData(
        title: '被遗忘的收藏',
        subtitle: '从收藏里重新听见熟悉的旋律',
        style: DiscoveryCardStyle.forgotten,
        songs: _stableShuffle(
          widget.starredSongs,
          seed + 809,
        ).take(24).toList(),
      ),
      DiscoveryCardData(
        title: '随机漫游',
        subtitle: '今天随机抽取的曲库片段',
        style: DiscoveryCardStyle.roam,
        songs: _stableShuffle(widget.allSongs, seed + 1201).take(24).toList(),
      ),
    ].where((card) => card.songs.isNotEmpty).toList();

    _cacheKey = seed;
    _cachedAllSongs = widget.allSongs;
    _cachedStarredSongs = widget.starredSongs;
    _cachedClassifications = classifications;
    _cachedRefreshToken = widget.refreshToken;
    _cachedCards = cards;
    return _cachedCards;
  }

  List<Song> _songsForTags(
    List<String> tags,
    int seed,
    Map<String, SongClassification> classifications,
  ) {
    final songsByTag = _songsByTag(classifications);
    final seen = <String>{};
    final songs = <Song>[];
    for (final tag in tags) {
      for (final song in songsByTag[tag] ?? const <Song>[]) {
        if (seen.add(song.id)) songs.add(song);
      }
    }
    return _stableShuffle(songs, seed);
  }

  Map<String, List<Song>> _songsByTag(
    Map<String, SongClassification> classifications,
  ) {
    if (identical(_tagIndexSongs, widget.allSongs) &&
        identical(_tagIndexClassifications, classifications)) {
      return _tagIndex;
    }

    final index = <String, List<Song>>{};
    for (final song in widget.allSongs) {
      final classification = classifications[song.id];
      if (classification == null) continue;
      final tags = <String>{
        ...classification.genres,
        ...classification.moods,
        ...classification.scenes,
        classification.language,
        decadeLabelForSong(song),
      };
      for (final tag in tags) {
        index.putIfAbsent(tag, () => <Song>[]).add(song);
      }
    }

    _tagIndexSongs = widget.allSongs;
    _tagIndexClassifications = classifications;
    _tagIndex = index;
    return _tagIndex;
  }

  static int _todaySeed(int offset) {
    final today = DateTime.now();
    return today.year * 10000 + today.month * 100 + today.day + offset;
  }

  static List<Song> _stableShuffle(List<Song> songs, int seed) {
    return [...songs]..shuffle(Random(seed));
  }
}
