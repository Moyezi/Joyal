import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../services/app_cache_service.dart';
import '../services/cache_repository.dart';
import '../services/download_service.dart';
import '../services/subsonic_api.dart';
import 'player_provider.dart';

/// Immutable snapshot of the music library state.
class LibraryState {
  final List<Album> albums;
  final List<Song> songs;
  final List<Song> albumSongs;
  final List<Album> starredAlbums;
  final List<Song> starredSongs;
  final bool isLoading;
  final bool isLoadingSongs;
  final bool isLoadingStarred;
  final String? error;

  // ── Artist detail fields ──
  final Artist? artistDetail;
  final List<Album> artistAlbums;
  final List<Song> artistSongs;
  final bool isLoadingArtist;
  final String? artistError;

  const LibraryState({
    this.albums = const [],
    this.songs = const [],
    this.albumSongs = const [],
    this.starredAlbums = const [],
    this.starredSongs = const [],
    this.isLoading = false,
    this.isLoadingSongs = false,
    this.isLoadingStarred = false,
    this.error,
    this.artistDetail,
    this.artistAlbums = const [],
    this.artistSongs = const [],
    this.isLoadingArtist = false,
    this.artistError,
  });

  LibraryState copyWith({
    List<Album>? albums,
    List<Song>? songs,
    List<Song>? albumSongs,
    List<Album>? starredAlbums,
    List<Song>? starredSongs,
    bool? isLoading,
    bool? isLoadingSongs,
    bool? isLoadingStarred,
    String? error,
    bool clearError = false,
    bool clearSongs = false,
    Artist? artistDetail,
    bool clearArtistDetail = false,
    List<Album>? artistAlbums,
    List<Song>? artistSongs,
    bool? isLoadingArtist,
    String? artistError,
    bool clearArtistError = false,
  }) {
    return LibraryState(
      albums: albums ?? this.albums,
      songs: songs ?? this.songs,
      albumSongs: clearSongs ? [] : (albumSongs ?? this.albumSongs),
      starredAlbums: starredAlbums ?? this.starredAlbums,
      starredSongs: starredSongs ?? this.starredSongs,
      isLoading: isLoading ?? this.isLoading,
      isLoadingSongs: isLoadingSongs ?? this.isLoadingSongs,
      isLoadingStarred: isLoadingStarred ?? this.isLoadingStarred,
      error: clearError ? null : (error ?? this.error),
      artistDetail: clearArtistDetail
          ? null
          : (artistDetail ?? this.artistDetail),
      artistAlbums: artistAlbums ?? this.artistAlbums,
      artistSongs: artistSongs ?? this.artistSongs,
      isLoadingArtist: isLoadingArtist ?? this.isLoadingArtist,
      artistError: clearArtistError ? null : (artistError ?? this.artistError),
    );
  }
}

/// Manages fetching and caching of albums and songs from the Subsonic API.
class LibraryNotifier extends StateNotifier<LibraryState> {
  final SubsonicApi? _api;
  final Dio _dio;
  final AppCacheService _cache;
  final CacheRepository _cacheRepo;
  final Map<String, ({DateTime savedAt, Map<String, dynamic> value})>
  _searchCache = {};
  Future<void>? _initialization;

  LibraryNotifier(this._api, this._dio, this._cache, this._cacheRepo)
    : super(const LibraryState());

  String? get _cacheName => _api == null
      ? null
      : 'library_${_cache.serverScope(_api.baseUrl, _api.username)}';

  /// Shows a disk snapshot immediately, then refreshes it in the background.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _loadSnapshot();
    try {
      await refreshLibrary();
    } catch (_) {
      // Keep the cached library usable while the server is temporarily down.
    }
  }

  Future<void> _loadSnapshot() async {
    final name = _cacheName;
    if (name == null) return;
    final json = await _cache.readJson(name);
    if (json == null || !mounted) return;
    try {
      state = state.copyWith(
        albums: (json['albums'] as List<dynamic>? ?? [])
            .map(
              (item) => Album.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        songs: (json['songs'] as List<dynamic>? ?? [])
            .map(
              (item) => Song.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        starredAlbums: (json['starredAlbums'] as List<dynamic>? ?? [])
            .map(
              (item) => Album.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        starredSongs: (json['starredSongs'] as List<dynamic>? ?? [])
            .map(
              (item) => Song.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
    } catch (_) {
      // Ignore snapshots from an old or incomplete schema.
    }
  }

  Future<void> _saveSnapshot() async {
    final name = _cacheName;
    if (name == null || !mounted) return;
    final snapshot = state;
    await _cache.writeJson(name, {
      'version': 1,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'albums': snapshot.albums.map((item) => item.toJson()).toList(),
      'songs': snapshot.songs.map((item) => item.toJson()).toList(),
      'starredAlbums': snapshot.starredAlbums
          .map((item) => item.toJson())
          .toList(),
      'starredSongs': snapshot.starredSongs
          .map((item) => item.toJson())
          .toList(),
    }, encodeInBackground: true);
  }

  /// Fetches the album list from the server.
  Future<void> fetchAlbums({String type = 'alphabeticalByName'}) async {
    if (_api == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      const pageSize = 500;
      var offset = 0;
      final albums = <Album>[];
      while (true) {
        final response = await _dio.get(
          _api.getAlbumListUrl(type, size: pageSize, offset: offset),
        );
        final data = response.data['subsonic-response'];
        if (data['status'] != 'ok') {
          throw Exception(data['error']?['message'] ?? 'Unknown API error');
        }
        final page = data['albumList2']?['album'] as List<dynamic>? ?? [];
        albums.addAll(
          page.map((json) => Album.fromJson(json as Map<String, dynamic>)),
        );
        if (page.length < pageSize) break;
        offset += pageSize;
      }

      state = state.copyWith(albums: albums, isLoading: false);
      unawaited(_saveSnapshot());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Fetches the complete song library in pages instead of silently stopping
  /// at the server's first (usually 20 or 30 item) response.
  Future<void> fetchSongs() async {
    if (_api == null) return;
    state = state.copyWith(isLoadingSongs: true, clearError: true);
    try {
      const pageSize = 500;
      var offset = 0;
      final songs = <Song>[];
      while (true) {
        final response = await _dio.get(
          _api.getSongsUrl(size: pageSize, offset: offset),
        );
        final data = response.data['subsonic-response'];
        if (data['status'] != 'ok') {
          throw Exception(data['error']?['message'] ?? 'Unknown API error');
        }
        final result = data['searchResult3'] ?? data['searchResult2'] ?? {};
        final page = result['song'] as List<dynamic>? ?? [];
        songs.addAll(
          page.map((json) => Song.fromJson(json as Map<String, dynamic>)),
        );
        if (page.length < pageSize) break;
        offset += pageSize;
      }
      state = state.copyWith(songs: songs, isLoadingSongs: false);
      unawaited(_saveSnapshot());
    } catch (e) {
      state = state.copyWith(isLoadingSongs: false, error: e.toString());
    }
  }

  Future<void> refreshLibrary() async {
    await Future.wait([fetchAlbums(), fetchSongs(), fetchStarred()]);
    await _saveSnapshot();
  }

  /// Fetches the tracklist for a specific album — cache-first.
  Future<void> fetchAlbumSongs(String albumId) async {
    if (_api == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Try disk cache first.
    final cachedSongs = await _cacheRepo.loadAlbumSongs(albumId);
    if (cachedSongs != null && mounted) {
      state = state.copyWith(albumSongs: cachedSongs, isLoading: false);
      // 2. Background refresh.
      unawaited(_fetchAlbumSongsFromNetwork(albumId));
      return;
    }

    // No cache — fetch from network directly.
    await _fetchAlbumSongsFromNetwork(albumId);
  }

  Future<void> _fetchAlbumSongsFromNetwork(String albumId) async {
    if (_api == null) return;
    try {
      final url = _api.getAlbumUrl(albumId);
      final response = await _dio.get(url);
      final data = response.data['subsonic-response'];
      if (data['status'] != 'ok') {
        throw Exception(data['error']?['message'] ?? 'Unknown API error');
      }
      final songList = data['album']?['song'] as List<dynamic>? ?? [];
      final songs = songList
          .map((json) => Song.fromJson(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        state = state.copyWith(albumSongs: songs, isLoading: false);
        unawaited(_cacheRepo.saveAlbumSongs(albumId, songs));
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: state.albumSongs.isEmpty ? e.toString() : null,
        );
      }
    }
  }

  /// Searches the server for artists, albums, and songs.
  Future<Map<String, dynamic>> search(String query) async {
    if (_api == null) {
      return {'artists': [], 'albums': [], 'songs': []};
    }

    final normalized = query.trim().toLowerCase();
    final cached = _searchCache[normalized];
    if (cached != null &&
        DateTime.now().difference(cached.savedAt) <
            const Duration(minutes: 10)) {
      return cached.value;
    }

    try {
      final url = _api.searchUrl(query);
      final response = await _dio.get(url);
      final data = response.data['subsonic-response'];

      if (data['status'] != 'ok') {
        return {'artists': [], 'albums': [], 'songs': []};
      }

      final searchResult = data['searchResult3'] ?? data['searchResult2'] ?? {};

      final artistList =
          (searchResult['artist'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final albumList =
          (searchResult['album'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final songList =
          (searchResult['song'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      final result = <String, dynamic>{
        'artists': artistList,
        'albums': albumList.map((j) => Album.fromJson(j)).toList(),
        'songs': songList.map((j) => Song.fromJson(j)).toList(),
      };
      _searchCache[normalized] = (savedAt: DateTime.now(), value: result);
      if (_searchCache.length > 30) {
        _searchCache.remove(_searchCache.keys.first);
      }
      return result;
    } catch (e) {
      return {'artists': [], 'albums': [], 'songs': []};
    }
  }

  Future<void> fetchStarred() async {
    if (_api == null) return;
    state = state.copyWith(isLoadingStarred: true, clearError: true);
    try {
      final response = await _dio.get(_api.getStarredUrl());
      final data = response.data['subsonic-response'];
      if (data['status'] != 'ok') {
        throw Exception(data['error']?['message'] ?? 'Unknown API error');
      }
      final starred = data['starred2'] ?? data['starred'] ?? {};
      final albums = (starred['album'] as List<dynamic>? ?? [])
          .map((json) => Album.fromJson(json as Map<String, dynamic>))
          .toList();
      final songs = (starred['song'] as List<dynamic>? ?? [])
          .map((json) => Song.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        starredAlbums: albums,
        starredSongs: songs,
        isLoadingStarred: false,
      );
      unawaited(_saveSnapshot());
    } catch (error) {
      state = state.copyWith(isLoadingStarred: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> setSongStarred(Song song, {required bool starred}) async {
    if (_api == null) return;
    final previous = state.starredSongs;
    final updated = [...previous];
    updated.removeWhere((item) => item.id == song.id);
    if (starred) updated.insert(0, song);
    state = state.copyWith(starredSongs: updated);
    unawaited(_saveSnapshot());

    final url = starred
        ? _api.starUrl(id: song.id)
        : _api.unstarUrl(id: song.id);
    try {
      final response = await _dio.get(url);
      final data = response.data['subsonic-response'];
      if (data['status'] != 'ok') {
        throw Exception(data['error']?['message'] ?? '收藏操作失败');
      }
    } catch (_) {
      state = state.copyWith(starredSongs: previous);
      unawaited(_saveSnapshot());
      rethrow;
    }
  }

  /// Fetches artist info (including avatar) and their album list — cache-first.
  Future<void> fetchArtistDetail(String artistId) async {
    if (_api == null) return;

    // Try disk cache first.
    final cached = await _cacheRepo.loadArtistDetail(artistId);
    if (cached != null && mounted) {
      _applyArtistDetailCache(cached);
      unawaited(_fetchArtistDetailFromNetwork(artistId));
      return;
    }

    await _fetchArtistDetailFromNetwork(artistId);
  }

  void _applyArtistDetailCache(Map<String, dynamic> json) {
    try {
      final artist = Artist.fromJson(
        Map<String, dynamic>.from(json['artist'] as Map),
      );
      final albumList = (json['albums'] as List<dynamic>? ?? [])
          .map((j) => Album.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      state = state.copyWith(
        artistDetail: artist,
        artistAlbums: albumList,
        isLoadingArtist: false,
      );
    } catch (_) {}
  }

  Future<void> _fetchArtistDetailFromNetwork(String artistId) async {
    state = state.copyWith(isLoadingArtist: true, clearArtistError: true);
    try {
      final artistResp = await _dio.get(_api!.getArtistUrl(artistId));
      final artistData =
          artistResp.data['subsonic-response']['artist']
              as Map<String, dynamic>? ??
          {};
      final artist = Artist.fromJson(artistData);
      final albumList = (artistData['album'] as List<dynamic>? ?? [])
          .map((json) => Album.fromJson(json as Map<String, dynamic>))
          .toList();

      String? avatarUrl;
      try {
        final infoResp = await _dio.get(_api.getArtistInfo2Url(artistId));
        final infoData =
            infoResp.data['subsonic-response']['artistInfo2']
                as Map<String, dynamic>? ??
            {};
        avatarUrl =
            infoData['largeImageUrl'] as String? ??
            infoData['mediumImageUrl'] as String? ??
            infoData['smallImageUrl'] as String?;
      } catch (_) {}

      final artistWithAvatar = Artist(
        id: artist.id,
        name: artist.name,
        albumCount: artist.albumCount,
        avatarUrl: avatarUrl ?? artist.avatarUrl,
      );

      if (mounted) {
        state = state.copyWith(
          artistDetail: artistWithAvatar,
          artistAlbums: albumList,
          isLoadingArtist: false,
        );
        unawaited(
          _cacheRepo.saveArtistDetail(artistId, {
            'artist': artistWithAvatar.toJson(),
            'albums': albumList.map((a) => a.toJson()).toList(),
          }),
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoadingArtist: false,
          artistError: state.artistDetail == null ? e.toString() : null,
        );
      }
    }
  }

  /// Fetches all songs by an artist via search3 — cache-first.
  Future<void> fetchArtistSongs(String artistName) async {
    if (_api == null) return;

    final cached = await _cacheRepo.loadArtistSongs(artistName);
    if (cached != null && mounted) {
      state = state.copyWith(artistSongs: cached, isLoadingArtist: false);
      unawaited(_fetchArtistSongsFromNetwork(artistName));
      return;
    }

    await _fetchArtistSongsFromNetwork(artistName);
  }

  Future<void> _fetchArtistSongsFromNetwork(String artistName) async {
    state = state.copyWith(isLoadingArtist: true, clearArtistError: true);
    try {
      const pageSize = 500;
      var offset = 0;
      final songs = <Song>[];
      while (true) {
        final response = await _dio.get(
          _api!.searchUrl(artistName, count: pageSize, offset: offset),
        );
        final data = response.data['subsonic-response'];
        if (data['status'] != 'ok') {
          throw Exception(data['error']?['message'] ?? 'Unknown API error');
        }
        final result = data['searchResult3'] ?? data['searchResult2'] ?? {};
        final page = result['song'] as List<dynamic>? ?? [];
        songs.addAll(
          page
              .map((json) => Song.fromJson(json as Map<String, dynamic>))
              .where(
                (song) => song.artist.toLowerCase() == artistName.toLowerCase(),
              ),
        );
        if (page.length < pageSize) break;
        offset += pageSize;
      }

      if (mounted) {
        state = state.copyWith(artistSongs: songs, isLoadingArtist: false);
        unawaited(_cacheRepo.saveArtistSongs(artistName, songs));
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoadingArtist: false,
          artistError: state.artistSongs.isEmpty ? e.toString() : null,
        );
      }
    }
  }

  /// Clears artist detail cache.
  void clearArtistDetail() {
    state = state.copyWith(
      clearArtistDetail: true,
      artistAlbums: [],
      artistSongs: [],
      clearArtistError: true,
    );
  }
}

// ━━━ Providers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final dioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  ),
);

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((
  ref,
) {
  final api = ref.watch(subsonicApiProvider);
  final dio = ref.watch(dioProvider);
  final cacheRepo = ref.watch(cacheRepositoryProvider);
  return LibraryNotifier(api, dio, AppCacheService.instance, cacheRepo);
});

final downloadServiceProvider = Provider<DownloadService?>((ref) {
  final api = ref.watch(subsonicApiProvider);
  final service = DownloadService(api);
  ref.onDispose(service.dispose);
  return service;
});

final downloadRecordsProvider = StreamProvider<List<DownloadRecord>>((
  ref,
) async* {
  final service = ref.watch(downloadServiceProvider);
  if (service == null) {
    yield const [];
    return;
  }
  await service.initialize();
  yield service.records;
  yield* service.recordsStream;
});
