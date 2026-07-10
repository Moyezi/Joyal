import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/song.dart';
import 'subsonic_api.dart';

class DownloadProgress {
  final String songId;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final bool completed;
  final String? error;
  final String? filePath;
  final int? taskId;
  final String? systemStatus;
  final int? systemReason;

  const DownloadProgress({
    required this.songId,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.completed = false,
    this.error,
    this.filePath,
    this.taskId,
    this.systemStatus,
    this.systemReason,
  });
}

class DownloadFailure implements Exception {
  final String message;
  const DownloadFailure(this.message);

  @override
  String toString() => message;
}

class DownloadRecord {
  final Song song;
  final String uri;
  final String fileName;
  final int size;
  final DateTime downloadedAt;

  const DownloadRecord({
    required this.song,
    required this.uri,
    required this.fileName,
    required this.size,
    required this.downloadedAt,
  });

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
    song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
    uri: json['uri'] as String,
    fileName: json['fileName'] as String,
    size: (json['size'] as num?)?.toInt() ?? 0,
    downloadedAt:
        DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'uri': uri,
    'fileName': fileName,
    'size': size,
    'downloadedAt': downloadedAt.toUtc().toIso8601String(),
  };
}

/// Resumable downloads plus a persistent local-media catalogue.
class DownloadService {
  static const _progressUpdateInterval = Duration(milliseconds: 100);
  static const _mediaChannel = MethodChannel('joyal_music/media_store');
  static final Map<String, DownloadRecord> _records = {};
  static final _recordsController =
      StreamController<List<DownloadRecord>>.broadcast();
  static Future<void>? _catalogInitialization;
  static File? _catalogFile;

  final SubsonicApi? _api;
  final _controller = StreamController<DownloadProgress>.broadcast();
  final Map<String, CancelToken> _activeTokens = {};
  final Map<String, DateTime> _lastProgressEmissions = {};
  final Map<String, DownloadProgress> _pendingProgress = {};
  final Map<String, Timer> _progressTimers = {};

  DownloadService(this._api) {
    unawaited(initialize());
  }

  Stream<DownloadProgress> get progressStream => _controller.stream;
  Stream<List<DownloadRecord>> get recordsStream => _recordsController.stream;
  List<DownloadRecord> get records => _sortedRecords();
  bool isDownloaded(String songId) => _records.containsKey(songId);

  Future<void> initialize() => _catalogInitialization ??= _loadCatalog();

  static Future<void> _loadCatalog() async {
    final support = await getApplicationSupportDirectory();
    _catalogFile = File('${support.path}/downloads.json');
    if (!await _catalogFile!.exists()) return;
    try {
      final data = await compute(
        _decodeDownloadCatalog,
        await _catalogFile!.readAsString(),
      );
      var removedIncompleteFile = false;
      for (final item in data) {
        final record = DownloadRecord.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        final expectedSize = record.song.size;
        if (expectedSize != null &&
            expectedSize > 0 &&
            record.size < expectedSize) {
          removedIncompleteFile = true;
          if (Platform.isAndroid) {
            try {
              await _mediaChannel.invokeMethod<void>('deleteAudio', {
                'uri': record.uri,
              });
            } catch (_) {}
          }
          continue;
        }
        _records[record.song.id] = record;
      }
      if (removedIncompleteFile) {
        final encoded = await compute(
          _encodeDownloadCatalog,
          _sortedRecords().map((record) => record.toJson()).toList(),
        );
        await _catalogFile!.writeAsString(encoded, flush: true);
      }
    } catch (_) {
      // Ignore old/corrupt indexes. Existing media remains in the public folder.
    }
  }

  static List<DownloadRecord> _sortedRecords() {
    final result = _records.values.toList();
    result.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return result;
  }

  static Future<void> _saveCatalog() async {
    await (_catalogInitialization ??= _loadCatalog());
    final file = _catalogFile!;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final encoded = await compute(
      _encodeDownloadCatalog,
      _sortedRecords().map((record) => record.toJson()).toList(),
    );
    await temporary.writeAsString(encoded, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    _recordsController.add(_sortedRecords());
  }

  static Future<String?> localUriForSong(String songId) async {
    await (_catalogInitialization ??= _loadCatalog());
    final record = _records[songId];
    if (record == null) return null;
    final expectedSize = record.song.size;
    if (expectedSize != null &&
        expectedSize > 0 &&
        record.size < expectedSize) {
      await _discardRecord(record);
      return null;
    }
    try {
      final exists = Platform.isAndroid
          ? await _mediaChannel.invokeMethod<bool>('audioExists', {
                  'uri': record.uri,
                }) ??
                false
          : await File.fromUri(Uri.parse(record.uri)).exists();
      if (exists) return record.uri;
    } catch (_) {}
    _records.remove(songId);
    unawaited(_saveCatalog());
    return null;
  }

  static Future<void> _discardRecord(DownloadRecord record) async {
    try {
      if (Platform.isAndroid) {
        await _mediaChannel.invokeMethod<void>('deleteAudio', {
          'uri': record.uri,
        });
      } else {
        final file = File.fromUri(Uri.parse(record.uri));
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    _records.remove(record.song.id);
    await _saveCatalog();
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _mediaChannel.invokeMethod<int>('getSdkInt') ?? 29;
    if (sdk >= 29) return true;
    return (await Permission.storage.request()).isGranted;
  }

  Future<bool> openSettings() => openAppSettings();

  String _fileName(Song song) {
    final safeArtist = _sanitize(song.artist);
    final safeTitle = _sanitize(song.title);
    final safeSuffix = _sanitize(song.suffix).replaceAll('.', '');
    final artist = safeArtist.isEmpty ? '未知艺术家' : safeArtist;
    final title = safeTitle.isEmpty ? '未知歌曲' : safeTitle;
    return '$artist - $title.${safeSuffix.isEmpty ? 'mp3' : safeSuffix}';
  }

  String _sanitize(String raw) => raw
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();

  Future<String> download(Song song) async {
    await initialize();
    final existingRecord = _records[song.id];
    if (existingRecord != null && await localUriForSong(song.id) != null) {
      _emitProgress(
        DownloadProgress(
          songId: song.id,
          progress: 1,
          receivedBytes: existingRecord.size,
          totalBytes: existingRecord.size,
          completed: true,
          filePath: existingRecord.uri,
        ),
      );
      return existingRecord.uri;
    }
    final adopted = await _adoptExistingPublicFile(song);
    if (adopted != null) {
      _emitProgress(
        DownloadProgress(
          songId: song.id,
          progress: 1,
          receivedBytes: adopted.size,
          totalBytes: adopted.size,
          completed: true,
          filePath: adopted.uri,
        ),
      );
      return adopted.uri;
    }
    if (_api == null) throw StateError('请先连接 Navidrome 服务器');
    if (_activeTokens.containsKey(song.id)) {
      throw StateError('${song.title} 正在下载中');
    }

    final token = CancelToken();
    _activeTokens[song.id] = token;

    const systemDownloadLimit = 32 * 1024 * 1024;
    final expectedSize = song.size;
    if (Platform.isAndroid &&
        (expectedSize == null || expectedSize <= systemDownloadLimit)) {
      try {
        final result = await _downloadWithSystemManager(song, token);
        return await _registerDownload(
          song,
          uri: result.uri,
          size: result.size,
        );
      } catch (error) {
        if (error is DioException && CancelToken.isCancel(error)) rethrow;
        final message = _friendlyError(error);
        _emitProgress(DownloadProgress(songId: song.id, error: message));
        throw DownloadFailure(message);
      } finally {
        _activeTokens.remove(song.id);
      }
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/joyal_${_sanitize(song.id)}.part');
    try {
      if (Platform.isAndroid) {
        await _downloadInVerifiedChunks(song, tempFile, token);
      } else {
        await _downloadWithResume(song, tempFile, token);
      }
      final actualSize = await tempFile.length();
      if (actualSize <= 0) {
        throw FileSystemException('服务器返回了空文件', tempFile.path);
      }
      if (expectedSize != null &&
          expectedSize > 0 &&
          actualSize < expectedSize) {
        throw DownloadFailure(
          '文件不完整：收到 ${_formatBytes(actualSize)}，应为 ${_formatBytes(expectedSize)}',
        );
      }

      final destination = await _publish(song, tempFile, _fileName(song));
      return await _registerDownload(song, uri: destination, size: actualSize);
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      final message = _friendlyError(error);
      _emitProgress(DownloadProgress(songId: song.id, error: message));
      throw DownloadFailure(message);
    } finally {
      _activeTokens.remove(song.id);
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  Future<String> _registerDownload(
    Song song, {
    required String uri,
    required int size,
  }) async {
    final expectedSize = song.size;
    if (size <= 0 ||
        (expectedSize != null && expectedSize > 0 && size < expectedSize)) {
      if (Platform.isAndroid) {
        try {
          await _mediaChannel.invokeMethod<void>('deleteAudio', {'uri': uri});
        } catch (_) {}
      }
      throw DownloadFailure(
        '文件不完整：收到 ${_formatBytes(size)}，应为 ${_formatBytes(expectedSize ?? 0)}',
      );
    }
    _records[song.id] = DownloadRecord(
      song: song,
      uri: uri,
      fileName: _fileName(song),
      size: size,
      downloadedAt: DateTime.now(),
    );
    await _saveCatalog();
    _emitProgress(
      DownloadProgress(
        songId: song.id,
        progress: 1,
        receivedBytes: size,
        totalBytes: size,
        completed: true,
        filePath: uri,
      ),
    );
    return uri;
  }

  Future<({String uri, int size})> _downloadWithSystemManager(
    Song song,
    CancelToken token,
  ) async {
    final id = await _mediaChannel.invokeMethod<int>('enqueueDownload', {
      'url': _api!.getDownloadUrl(song.id),
      'displayName': _fileName(song),
      'mimeType': song.contentType.isEmpty ? 'audio/flac' : song.contentType,
      'title': song.title,
    });
    if (id == null) throw const DownloadFailure('系统下载任务创建失败');
    var lastReceived = -1;
    var lastStatus = '';
    var lastReason = -1;
    var lastProgressAt = DateTime.now();
    const runningStallTimeout = Duration(minutes: 3);
    const systemRetryTimeout = Duration(minutes: 20);
    try {
      while (true) {
        if (token.isCancelled) {
          await _mediaChannel.invokeMethod<void>('cancelDownload', {'id': id});
          _throwIfCancelled(song, token);
        }
        final status = await _mediaChannel.invokeMapMethod<String, dynamic>(
          'queryDownload',
          {'id': id},
        );
        if (status == null || status['status'] == 'missing') {
          throw const DownloadFailure('系统下载任务已丢失');
        }
        final received = (status['downloaded'] as num?)?.toInt() ?? 0;
        final systemTotal = (status['total'] as num?)?.toInt() ?? 0;
        final total = systemTotal > 0 ? systemTotal : (song.size ?? 0);
        final ratio = total > 0 ? received / total : 0.0;
        final systemStatus = status['status'] as String? ?? 'unknown';
        final reason = (status['reason'] as num?)?.toInt() ?? 0;
        if (received > lastReceived) lastProgressAt = DateTime.now();
        if (received != lastReceived ||
            systemStatus != lastStatus ||
            reason != lastReason) {
          debugPrint(
            '[JoyalDownload] id=$id status=$systemStatus reason=$reason '
            'downloaded=$received total=$total songId=${song.id}',
          );
          lastReceived = received;
          lastStatus = systemStatus;
          lastReason = reason;
        }
        _emitProgress(
          DownloadProgress(
            songId: song.id,
            progress: ratio.clamp(0.0, 0.99).toDouble(),
            receivedBytes: received,
            totalBytes: total,
            taskId: id,
            systemStatus: systemStatus,
            systemReason: reason,
          ),
        );
        switch (systemStatus) {
          case 'successful':
            final uri = status['uri'] as String?;
            if (uri == null) throw const DownloadFailure('系统未返回下载文件位置');
            return (uri: uri, size: received);
          case 'failed':
            final failureReason = reason == 0 ? 1000 : reason;
            throw DownloadFailure(
              '${_systemDownloadFailure(failureReason)}；任务 ID $id，'
              '已下载 ${_formatBytes(received)} / ${_formatBytes(total)}，'
              '状态码 $failureReason',
            );
          default:
            final stalledFor = DateTime.now().difference(lastProgressAt);
            // PAUSED_WAITING_TO_RETRY means DownloadManager has scheduled its
            // own retry with backoff. Do not cancel it after three minutes or
            // the app prevents that recovery from ever happening.
            final isWaitingForSystemRetry =
                systemStatus == 'paused' && reason == 1;
            final stallTimeout = isWaitingForSystemRetry
                ? systemRetryTimeout
                : runningStallTimeout;
            if (received > 0 && stalledFor >= stallTimeout) {
              await _mediaChannel.invokeMethod<void>('cancelDownload', {
                'id': id,
              });
              throw DownloadFailure(
                '下载已连续 ${stalledFor.inMinutes} 分钟没有收到新数据；'
                '任务 ID $id，系统状态 $systemStatus，原因码 $reason，'
                '停在 ${_formatBytes(received)} / ${_formatBytes(total)}。'
                '请检查 Navidrome 和反向代理日志中对应时段的连接关闭原因',
              );
            }
            await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (_) {
      rethrow;
    }
  }

  String _systemDownloadFailure(int reason) => switch (reason) {
    1001 => '系统无法写入下载文件',
    1002 => '系统不支持服务器返回的 HTTP 响应',
    1004 => '服务器返回的数据不完整',
    1005 => '服务器重定向次数过多',
    1006 => '设备存储空间不足',
    1007 => '外部存储不可用',
    1008 => '系统无法继续当前下载',
    1009 => '目标文件已存在',
    _ when reason >= 400 && reason < 600 => '服务器返回 HTTP $reason',
    _ => '系统下载失败（错误码 $reason）',
  };

  Future<DownloadRecord?> _adoptExistingPublicFile(Song song) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _mediaChannel.invokeMapMethod<String, dynamic>(
        'findAudio',
        {'displayName': _fileName(song)},
      );
      if (result == null) return null;
      final record = DownloadRecord(
        song: song,
        uri: result['uri'] as String,
        fileName: _fileName(song),
        size: (result['size'] as num?)?.toInt() ?? 0,
        downloadedAt: DateTime.now(),
      );
      final expectedSize = song.size;
      if (expectedSize != null &&
          expectedSize > 0 &&
          record.size < expectedSize) {
        await _mediaChannel.invokeMethod<void>('deleteAudio', {
          'uri': record.uri,
        });
        return null;
      }
      _records[song.id] = record;
      await _saveCatalog();
      return record;
    } catch (_) {
      return null;
    }
  }

  /// Downloads large files as short, verified HTTP Range requests.
  ///
  /// A fresh connection for every 4 MiB avoids relying on one long-lived
  /// response. Each response must be 206 and its Content-Range must begin at
  /// the requested offset, so an ignored Range can never corrupt the file.
  Future<void> _downloadInVerifiedChunks(
    Song song,
    File file,
    CancelToken token,
  ) async {
    final total = song.size;
    if (total == null || total <= 0) {
      throw const DownloadFailure('服务器没有提供文件大小，无法安全分段下载');
    }
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    const chunkSize = 4 * 1024 * 1024;
    var offset = 0;
    while (offset < total) {
      final proposedEnd = offset + chunkSize - 1;
      final chunkEnd = proposedEnd < total ? proposedEnd : total - 1;
      var failures = 0;

      while (offset <= chunkEnd) {
        _throwIfCancelled(song, token);
        final requestStart = offset;
        HttpClient? client;
        IOSink? sink;
        try {
          client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 20)
            ..idleTimeout = const Duration(seconds: 45)
            ..autoUncompress = false;
          final request = await client.getUrl(
            Uri.parse(_api!.getDownloadUrl(song.id)),
          );
          request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
          request.headers.set(HttpHeaders.connectionHeader, 'close');
          request.headers.set(
            HttpHeaders.rangeHeader,
            'bytes=$requestStart-$chunkEnd',
          );
          final response = await request.close();
          if (response.statusCode != HttpStatus.partialContent) {
            await response.drain<void>();
            throw DownloadFailure(
              response.statusCode == HttpStatus.ok
                  ? 'Navidrome 未接受 Range 分段请求（返回 HTTP 200）'
                  : '分段请求返回 HTTP ${response.statusCode}',
            );
          }

          final contentRange = response.headers.value(
            HttpHeaders.contentRangeHeader,
          );
          final match = contentRange == null
              ? null
              : RegExp(
                  r'^bytes (\d+)-(\d+)/(\d+|\*)$',
                ).firstMatch(contentRange);
          final responseStart = match == null
              ? null
              : int.tryParse(match.group(1)!);
          final responseEnd = match == null
              ? null
              : int.tryParse(match.group(2)!);
          final responseTotal = match == null
              ? null
              : int.tryParse(match.group(3)!);
          if (responseStart != requestStart ||
              responseEnd == null ||
              responseEnd > chunkEnd ||
              (responseTotal != null && responseTotal != total)) {
            await response.drain<void>();
            throw DownloadFailure(
              '服务器返回了无效的 Content-Range：${contentRange ?? '缺失'}',
            );
          }

          sink = file.openWrite(mode: FileMode.append);
          var received = 0;
          await for (final bytes in response) {
            _throwIfCancelled(song, token);
            received += bytes.length;
            if (requestStart + received > responseEnd + 1) {
              throw const DownloadFailure('服务器返回的分段数据超过声明范围');
            }
            sink.add(bytes);
            final current = requestStart + received;
            _emitProgress(
              DownloadProgress(
                songId: song.id,
                progress: (current / total).clamp(0.0, 0.99).toDouble(),
                receivedBytes: current,
                totalBytes: total,
                systemStatus: 'segmented',
              ),
            );
          }
          await sink.flush();
          await sink.close();
          sink = null;

          offset = await file.length();
          if (offset <= requestStart) {
            throw DownloadFailure('服务器提前结束分段传输，停在 ${_formatBytes(offset)}');
          }
          if (offset > responseEnd + 1 || offset > total) {
            throw const DownloadFailure('分段文件长度校验失败');
          }
          failures = 0;
        } catch (error) {
          try {
            await sink?.flush();
            await sink?.close();
          } catch (_) {}
          offset = await file.exists() ? await file.length() : 0;
          failures++;
          if (error is DownloadFailure &&
              (error.message.contains('未接受 Range') ||
                  error.message.contains('Content-Range'))) {
            rethrow;
          }
          if (failures >= 4) {
            throw DownloadFailure(
              '分段下载在 ${_formatBytes(offset)} 连续中断：${_friendlyError(error)}',
            );
          }
          await Future<void>.delayed(Duration(seconds: failures * 2));
        } finally {
          client?.close(force: true);
        }
      }
    }

    final actualSize = await file.length();
    if (actualSize != total) {
      throw DownloadFailure(
        '分段文件不完整：收到 ${_formatBytes(actualSize)}，应为 ${_formatBytes(total)}',
      );
    }
  }

  Future<void> _downloadWithResume(
    Song song,
    File file,
    CancelToken token,
  ) async {
    Object? lastError;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5)
      ..autoUncompress = false;
    try {
      for (var attempt = 0; attempt < 7; attempt++) {
        _throwIfCancelled(song, token);
        var offset = await file.exists() ? await file.length() : 0;
        IOSink? sink;
        try {
          final request = await client.getUrl(
            Uri.parse(_api!.getDownloadUrl(song.id)),
          );
          request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
          if (offset > 0) {
            request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
          }
          final response = await request.close();

          if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
              song.size != null &&
              offset >= song.size!) {
            return;
          }
          if (response.statusCode != HttpStatus.ok &&
              response.statusCode != HttpStatus.partialContent) {
            await response.drain<void>();
            throw HttpException(
              '服务器返回 HTTP ${response.statusCode}',
              uri: request.uri,
            );
          }

          final canAppend =
              offset > 0 && response.statusCode == HttpStatus.partialContent;
          if (!canAppend) {
            // The server ignored Range. Restart from byte zero using this full
            // response instead of appending it to a partial file.
            offset = 0;
          }
          sink = file.openWrite(
            mode: canAppend ? FileMode.append : FileMode.write,
          );
          var receivedThisRequest = 0;
          final responseLength = response.contentLength;
          await for (final chunk in response) {
            _throwIfCancelled(song, token);
            sink.add(chunk);
            receivedThisRequest += chunk.length;
            final current = offset + receivedThisRequest;
            final total = (song.size != null && song.size! > 0)
                ? song.size!
                : (responseLength > 0 ? offset + responseLength : 0);
            final ratio = total > 0 ? current / total : 0.0;
            _emitProgress(
              DownloadProgress(
                songId: song.id,
                progress: ratio.clamp(0.0, 0.99).toDouble(),
                receivedBytes: current,
                totalBytes: total,
              ),
            );
          }
          await sink.flush();
          await sink.close();
          sink = null;

          final currentSize = await file.length();
          final expectedSize = song.size;
          if (expectedSize != null &&
              expectedSize > 0 &&
              currentSize < expectedSize) {
            lastError = DownloadFailure(
              '服务器提前结束传输（${_formatBytes(currentSize)} / ${_formatBytes(expectedSize)}）',
            );
            if (attempt < 6) {
              await Future<void>.delayed(
                Duration(seconds: 1 << attempt.clamp(0, 4)),
              );
            }
            continue;
          }
          return;
        } catch (error) {
          try {
            await sink?.flush();
            await sink?.close();
          } catch (_) {}
          if (error is DioException && CancelToken.isCancel(error)) rethrow;
          lastError = error;
          if (attempt < 6) {
            await Future<void>.delayed(
              Duration(seconds: 1 << attempt.clamp(0, 4)),
            );
          }
        }
      }
    } finally {
      client.close(force: true);
    }
    throw lastError ?? StateError('下载中断');
  }

  void _throwIfCancelled(Song song, CancelToken token) {
    if (!token.isCancelled) return;
    throw DioException.requestCancelled(
      requestOptions: RequestOptions(path: _api!.getDownloadUrl(song.id)),
      reason: '用户已取消下载',
    );
  }

  String _friendlyError(Object error) {
    if (error is DownloadFailure) return error.message;
    if (error is SocketException) {
      return '网络连接中断：${error.message}';
    }
    if (error is HttpException) return error.message;
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) return '服务器返回 HTTP $status';
      return switch (error.type) {
        DioExceptionType.cancel => '下载已取消',
        DioExceptionType.connectionTimeout => '连接服务器超时',
        DioExceptionType.connectionError => '网络连接中断，续传失败',
        DioExceptionType.receiveTimeout => '接收数据超时',
        _ => error.message ?? '网络下载失败',
      };
    }
    return error.toString().replaceFirst(
      RegExp(r'^(Exception|Bad state): '),
      '',
    );
  }

  static String _formatBytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<String> _publish(Song song, File source, String displayName) async {
    if (Platform.isAndroid) {
      return await _mediaChannel.invokeMethod<String>('publishAudio', {
            'sourcePath': source.path,
            'displayName': displayName,
            'mimeType': song.contentType.isEmpty
                ? 'audio/mpeg'
                : song.contentType,
            'title': song.title,
            'artist': song.artist,
            'album': song.album,
          }) ??
          'Music/Joyal DL/$displayName';
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/Joyal DL');
    await directory.create(recursive: true);
    final destination = File('${directory.path}/$displayName');
    if (await destination.exists()) await destination.delete();
    await source.copy(destination.path);
    return destination.uri.toString();
  }

  Future<void> delete(DownloadRecord record) async {
    if (Platform.isAndroid) {
      await _mediaChannel.invokeMethod<void>('deleteAudio', {
        'uri': record.uri,
      });
    } else {
      final file = File.fromUri(Uri.parse(record.uri));
      if (await file.exists()) await file.delete();
    }
    _records.remove(record.song.id);
    await _saveCatalog();
  }

  void cancel(String songId) {
    _activeTokens[songId]?.cancel();
    _progressTimers.remove(songId)?.cancel();
    _pendingProgress.remove(songId);
    _lastProgressEmissions.remove(songId);
  }

  void _emitProgress(DownloadProgress progress) {
    if (_controller.isClosed) return;
    final songId = progress.songId;
    final isTerminal = progress.completed || progress.error != null;
    if (isTerminal) {
      _progressTimers.remove(songId)?.cancel();
      _pendingProgress.remove(songId);
      _lastProgressEmissions.remove(songId);
      _controller.add(progress);
      return;
    }

    final now = DateTime.now();
    final lastEmission = _lastProgressEmissions[songId];
    final elapsed = lastEmission == null
        ? _progressUpdateInterval
        : now.difference(lastEmission);
    if (elapsed >= _progressUpdateInterval) {
      _progressTimers.remove(songId)?.cancel();
      _pendingProgress.remove(songId);
      _lastProgressEmissions[songId] = now;
      _controller.add(progress);
      return;
    }

    _pendingProgress[songId] = progress;
    if (_progressTimers.containsKey(songId)) return;
    _progressTimers[songId] = Timer(_progressUpdateInterval - elapsed, () {
      _progressTimers.remove(songId);
      final pending = _pendingProgress.remove(songId);
      if (pending == null || _controller.isClosed) return;
      _lastProgressEmissions[songId] = DateTime.now();
      _controller.add(pending);
    });
  }

  void dispose() {
    for (final token in _activeTokens.values) {
      token.cancel();
    }
    _activeTokens.clear();
    for (final timer in _progressTimers.values) {
      timer.cancel();
    }
    _progressTimers.clear();
    _pendingProgress.clear();
    _lastProgressEmissions.clear();
    _controller.close();
  }
}

List<dynamic> _decodeDownloadCatalog(String contents) {
  return jsonDecode(contents) as List<dynamic>;
}

String _encodeDownloadCatalog(List<Map<String, dynamic>> records) {
  return jsonEncode(records);
}
