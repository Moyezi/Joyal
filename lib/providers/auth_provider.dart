import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';
import '../services/subsonic_api.dart';

/// Immutable snapshot of authentication / connection state.
class AuthState {
  final String? baseUrl;
  final String? username;
  final String? password;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.baseUrl,
    this.username,
    this.password,
    this.isConnected = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    String? baseUrl,
    String? username,
    String? password,
    bool? isConnected,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearCredentials = false,
  }) {
    return AuthState(
      baseUrl: clearCredentials ? null : (baseUrl ?? this.baseUrl),
      username: clearCredentials ? null : (username ?? this.username),
      password: clearCredentials ? null : (password ?? this.password),
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasCredentials =>
      baseUrl != null &&
      baseUrl!.isNotEmpty &&
      username != null &&
      username!.isNotEmpty &&
      password != null &&
      password!.isNotEmpty;
}

/// Manages server connection credentials and authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  AuthNotifier(this._storage, this._dio)
    : super(const AuthState(isLoading: true));

  /// Attempt to load previously saved credentials from secure storage.
  Future<void> loadSavedCredentials() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final baseUrl = await _storage.read(key: AppConstants.keyBaseUrl);
      final username = await _storage.read(key: AppConstants.keyUsername);
      final password = await _storage.read(key: AppConstants.keyPassword);

      if (baseUrl != null && username != null && password != null) {
        state = AuthState(
          baseUrl: baseUrl,
          username: username,
          password: password,
          isConnected: true,
        );
      } else {
        state = const AuthState();
      }
    } catch (e) {
      state = AuthState(error: 'Failed to load saved credentials: $e');
    }
  }

  /// Connect to a Subsonic server with the given credentials.
  Future<void> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Normalise the base URL (strip trailing slash)
      final normalisedUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final api = SubsonicApi(
        baseUrl: normalisedUrl,
        username: username,
        password: password,
      );
      final response = await _dio.get(api.pingUrl);
      final payload = response.data is Map
          ? response.data['subsonic-response']
          : null;
      if (payload == null || payload['status'] != 'ok') {
        throw Exception(payload?['error']?['message'] ?? '服务器验证失败');
      }

      // Persist credentials only after the server accepts them.
      await _storage.write(key: AppConstants.keyBaseUrl, value: normalisedUrl);
      await _storage.write(key: AppConstants.keyUsername, value: username);
      await _storage.write(key: AppConstants.keyPassword, value: password);

      state = AuthState(
        baseUrl: normalisedUrl,
        username: username,
        password: password,
        isConnected: true,
      );
    } catch (e) {
      state = AuthState(error: '连接失败：${_friendlyError(e)}');
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      return error.response?.statusMessage ?? error.message ?? '网络请求失败';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// Disconnect and clear all stored credentials.
  Future<void> disconnect() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Swallow storage errors during disconnect
    }
    state = const AuthState();
  }
}

// ━━━ Providers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = ref.watch(authDioProvider);
  return AuthNotifier(storage, dio)..loadSavedCredentials();
});
