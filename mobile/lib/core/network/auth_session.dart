import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';

/// Access + refresh token pair issued by the backend.
final class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Extracts the token pair from an auth response.
///
/// The backend issues tokens only as `access_token` / `refresh_token`
/// `Set-Cookie` headers (the JSON body carries non-sensitive user info), so a
/// native client reads them from the headers and keeps them in secure storage.
/// Returns null when the response does not carry both tokens.
AuthTokens? extractAuthTokens(Response<dynamic> response) {
  String? access;
  String? refresh;
  for (final header in response.headers['set-cookie'] ?? const <String>[]) {
    final pair = header.split(';').first;
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    final name = pair.substring(0, eq).trim();
    final value = pair.substring(eq + 1).trim();
    if (value.isEmpty) continue; // cleared cookie
    if (name == 'access_token') access = value;
    if (name == 'refresh_token') refresh = value;
  }
  if (access == null || refresh == null) return null;
  return AuthTokens(accessToken: access, refreshToken: refresh);
}

/// The `access_token` cookie set by [response] alone (e.g. the reissued
/// token of `POST /auth/sessions/revoke-others`), or null.
String? extractAccessToken(Response<dynamic> response) {
  for (final header in response.headers['set-cookie'] ?? const <String>[]) {
    final pair = header.split(';').first;
    final eq = pair.indexOf('=');
    if (eq <= 0 || pair.substring(0, eq).trim() != 'access_token') continue;
    final value = pair.substring(eq + 1).trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

/// Expiry of a JWT access token, or null if it cannot be decoded.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map || payload['exp'] is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (payload['exp'] as num).toInt() * 1000,
      isUtc: true,
    );
  } on FormatException {
    return null;
  }
}

/// Thrown when the refresh token was rejected; the session is gone.
final class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'SessionExpiredException';
}

final authSessionManagerProvider = Provider<AuthSessionManager>((ref) {
  final manager = AuthSessionManager(ref.read(secureStorageProvider));
  ref.onDispose(manager.dispose);
  return manager;
});

/// Owns token refresh for every consumer (HTTP interceptor, WebSocket).
///
/// Refresh tokens are single-use: the backend rejects a second refresh with the
/// same token and may revoke every session on reuse. All refreshes therefore go
/// through [refresh], which runs at most one request at a time — concurrent
/// callers await the same in-flight future — and persists the rotated pair in a
/// single secure-storage write before anyone uses the new access token.
///
/// Every session change (sign-in, logout) bumps a generation counter. A refresh
/// that started under an older generation discards its result: it neither
/// persists tokens nor clears storage, so a refresh racing a logout cannot
/// resurrect the old session or wipe a newer one.
final class AuthSessionManager {
  AuthSessionManager(
    this._storage, {
    Dio? refreshDio,
    this.refreshRaceDelay = const Duration(milliseconds: 300),
  }) : _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(
                  milliseconds: ApiConstants.connectTimeoutMs,
                ),
                receiveTimeout: const Duration(
                  milliseconds: ApiConstants.receiveTimeoutMs,
                ),
                headers: {'Accept': 'application/json'},
              ),
            );

  /// How long to wait after a 409 `REFRESH_RACE` before re-reading the
  /// tokens the winning refresh stored.
  final Duration refreshRaceDelay;

  final SecureStorage _storage;
  final Dio _refreshDio;
  final _expiredController = StreamController<void>.broadcast();
  Future<String>? _inFlight;
  int _generation = 0;

  /// Emits when the session ended because the refresh token was rejected.
  Stream<void> get sessionExpired => _expiredController.stream;

  Future<String?> currentAccessToken() => _storage.getAccessToken();

  /// Persists a freshly issued token pair (login, verify-email, Google) and
  /// invalidates any refresh still running for the previous session.
  Future<void> saveTokens(AuthTokens tokens, {String? userId}) {
    _startNewGeneration();
    return _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      userId: userId,
    );
  }

  /// Returns an access token valid for at least [minValidity], refreshing
  /// first when needed. Returns null when logged out. Throws
  /// [SessionExpiredException] when the refresh token was rejected (or the
  /// session ended while refreshing), or the underlying [DioException] on
  /// network failures (session kept).
  Future<String?> freshAccessToken({
    Duration minValidity = const Duration(seconds: 60),
  }) async {
    final token = await _storage.getAccessToken();
    if (token == null) return null;
    final exp = jwtExpiry(token);
    if (exp != null && exp.isAfter(DateTime.now().toUtc().add(minValidity))) {
      return token;
    }
    return refresh(staleAccessToken: token);
  }

  /// Rotates the token pair once and returns the new access token.
  ///
  /// [staleAccessToken] is the token the caller found to be rejected/expired.
  /// If storage already holds a different token, another caller refreshed in
  /// the meantime and that token is returned without a new request.
  Future<String> refresh({String? staleAccessToken}) async {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final stored = await _storage.getAccessToken();
    if (stored != null &&
        staleAccessToken != null &&
        stored != staleAccessToken) {
      return stored;
    }

    // Re-check: another caller may have started a refresh while we awaited.
    final started = _inFlight;
    if (started != null) return started;

    final future = _doRefresh(_generation);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<String> _doRefresh(int generation) async {
    final session = await _storage.getSession();
    _ensureCurrent(generation);
    if (session == null) {
      _expire();
      throw const SessionExpiredException();
    }
    final Response<dynamic> response;
    try {
      response = await _refreshDio.post<dynamic>(
        ApiConstants.refresh,
        options: Options(
          headers: {'Cookie': 'refresh_token=${session.refreshToken}'},
        ),
      );
    } on DioException catch (e) {
      _ensureCurrent(generation);
      final status = e.response?.statusCode;
      if (status == 409 && _errorCode(e.response?.data) == 'REFRESH_RACE') {
        return _afterRefreshRace(generation, session.accessToken);
      }
      if (status == 401 || status == 403) {
        await _storage.clearSession();
        _expire();
        throw const SessionExpiredException();
      }
      rethrow;
    }

    // Logged out (or signed in again) while the request was in flight.
    _ensureCurrent(generation);
    final tokens = extractAuthTokens(response);
    if (tokens == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Refresh response carried no tokens',
      );
    }
    // Persist before anyone retries with the new access token.
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return tokens.accessToken;
  }

  /// 409 `REFRESH_RACE`: the token was rotated moments ago by a concurrent
  /// refresh (another isolate, or a refresh interrupted by an app restart).
  /// The server left the session untouched, so this is never fatal: give the
  /// winner time to persist its tokens, then hand back whatever access token
  /// is stored for the caller's single retry.
  Future<String> _afterRefreshRace(
      int generation, String sentAccessToken) async {
    await Future<void>.delayed(refreshRaceDelay);
    _ensureCurrent(generation);
    final stored = await _storage.getAccessToken();
    _ensureCurrent(generation);
    return stored ?? sentAccessToken;
  }

  /// Clears the local session (logout). Any refresh still in flight is
  /// discarded when it completes.
  Future<void> clear() {
    _startNewGeneration();
    return _storage.clearSession();
  }

  /// Refresh token for the logout call, so the backend can revoke it.
  Future<String?> refreshToken() => _storage.getRefreshToken();

  /// `Cookie` header identifying this device's session to endpoints that
  /// tell sessions apart by the refresh-token cookie (`/auth/sessions*`,
  /// logout). Empty when signed out.
  Future<Map<String, String>> sessionCookieHeader() async {
    final refresh = await _storage.getRefreshToken();
    return refresh == null ? const {} : {'Cookie': 'refresh_token=$refresh'};
  }

  /// Stores a reissued access token next to the current refresh token
  /// (`revoke-others` bumps the token version, invalidating the old one).
  /// Ignored when signed out.
  Future<void> replaceAccessToken(String accessToken) async {
    final session = await _storage.getSession();
    if (session == null) return;
    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: session.refreshToken,
    );
  }

  void _startNewGeneration() {
    _generation++;
    _inFlight = null;
  }

  /// Throws (without touching storage or signalling expiry) when the session
  /// changed since [generation] started.
  void _ensureCurrent(int generation) {
    if (generation != _generation) throw const SessionExpiredException();
  }

  static String? _errorCode(Object? body) =>
      body is Map && body['code'] is String ? body['code'] as String : null;

  void _expire() {
    if (!_expiredController.isClosed) _expiredController.add(null);
  }

  void dispose() => _expiredController.close();
}
