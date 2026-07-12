import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../config/constants.dart';

/// Client for the Navidrome / Subsonic REST API.
///
/// Handles token-based authentication using MD5(password + salt)
/// as specified in the Subsonic API documentation.
class SubsonicApi {
  final String baseUrl;
  final String username;
  final String password;

  const SubsonicApi({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  // ━━━ Authentication ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Generates a random 6-character alphanumeric salt.
  String _generateSalt() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Builds a fully qualified Subsonic API URL with authentication params.
  ///
  /// [endpoint] – e.g. `ping.view`, `getAlbumList2.view`
  /// [extraParams] – optional query parameters (e.g. `{'id': albumId}`)
  String buildUrl(String endpoint, [Map<String, String>? extraParams]) {
    final salt = _generateSalt();
    final bytes = utf8.encode(password + salt);
    final token = md5.convert(bytes).toString();

    final uri = Uri.parse('$baseUrl/rest/$endpoint').replace(
      queryParameters: {
        'u': username,
        't': token,
        's': salt,
        'v': AppConstants.subsonicVersion,
        'c': AppConstants.clientName,
        'f': 'json',
        ...?extraParams,
      },
    );
    return uri.toString();
  }

  // ━━━ API Endpoints ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Test connectivity to the server.
  String get pingUrl => buildUrl('ping.view');

  /// Get album list by type (e.g. `newest`, `frequent`, `recent`, `alphabeticalByName`).
  String getAlbumListUrl(String type, {int size = 20, int offset = 0}) {
    return buildUrl('getAlbumList2.view', {
      'type': type,
      'size': size.toString(),
      'offset': offset.toString(),
    });
  }

  /// Get album details and tracklist.
  String getAlbumUrl(String albumId) {
    return buildUrl('getAlbum.view', {'id': albumId});
  }

  /// Get cover art image URL.
  ///
  /// [coverId] – the coverArt id from an album or song.
  /// [size] – requested width in pixels (defaults to [AppConstants.coverArtSize]).
  String getCoverArtUrl(String coverId, {int? size}) {
    return buildUrl('getCoverArt.view', {
      'id': coverId,
      'size': (size ?? AppConstants.coverArtSize).toString(),
    });
  }

  /// Get the audio stream URL for a song.
  String getStreamUrl(String songId) {
    // Explicitly request the original encoding. This avoids an implicit
    // transcoding response ending earlier than the source duration/size.
    return buildUrl('stream.view', {'id': songId, 'format': 'raw'});
  }

  /// Get the original file without server-side transcoding.
  String getDownloadUrl(String songId) {
    return buildUrl('download.view', {'id': songId});
  }

  /// Get OpenSubsonic structured lyrics for a song.
  String getLyricsBySongIdUrl(String songId, {bool enhanced = false}) {
    return buildUrl('getLyricsBySongId.view', {
      'id': songId,
      if (enhanced) 'enhanced': 'true',
    });
  }

  /// Legacy Subsonic lyrics endpoint used as a compatibility fallback.
  String getLyricsUrl({required String artist, required String title}) {
    return buildUrl('getLyrics.view', {'artist': artist, 'title': title});
  }

  /// Search for artists, albums, and songs.
  String searchUrl(String query, {int count = 20, int offset = 0}) {
    return buildUrl('search3.view', {
      'query': query,
      'artistCount': count.toString(),
      'artistOffset': offset.toString(),
      'albumCount': count.toString(),
      'albumOffset': offset.toString(),
      'songCount': count.toString(),
      'songOffset': offset.toString(),
    });
  }

  /// Browse every song. Subsonic defines a blank search query as "match all".
  String getSongsUrl({int size = 500, int offset = 0}) {
    return buildUrl('search3.view', {
      'query': '',
      'artistCount': '0',
      'albumCount': '0',
      'songCount': size.toString(),
      'songOffset': offset.toString(),
    });
  }

  /// Get starred / favorited items.
  String getStarredUrl() => buildUrl('getStarred2.view');

  /// Star (favorite) an item.
  String starUrl({String? id, String? albumId, String? artistId}) {
    final params = <String, String>{};
    if (id != null) params['id'] = id;
    if (albumId != null) params['albumId'] = albumId;
    if (artistId != null) params['artistId'] = artistId;
    return buildUrl('star.view', params);
  }

  /// Unstar (unfavorite) an item.
  String unstarUrl({String? id, String? albumId, String? artistId}) {
    final params = <String, String>{};
    if (id != null) params['id'] = id;
    if (albumId != null) params['albumId'] = albumId;
    if (artistId != null) params['artistId'] = artistId;
    return buildUrl('unstar.view', params);
  }

  /// Get artist details including album list.
  String getArtistUrl(String artistId) {
    return buildUrl('getArtist.view', {'id': artistId});
  }

  /// Get extended artist info (bio, avatar images, similar artists).
  String getArtistInfo2Url(String artistId) {
    return buildUrl('getArtistInfo2.view', {'id': artistId});
  }
}
