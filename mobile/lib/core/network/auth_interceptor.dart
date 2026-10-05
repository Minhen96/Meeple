import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';

/// Attaches the access token and recovers from expired ones.
///
/// On a 401 every concurrent request queues behind ONE refresh owned by
/// [AuthSessionManager] (refresh tokens are single-use), then retries once with
/// the new token. Auth endpoints are never retried: their 401s mean bad
/// credentials, not an expired session.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthSessionManager session,
    required Dio retryClient,
  })  : _session = session,
        _retryClient = retryClient;

  static const _retriedKey = 'authRetried';

  final AuthSessionManager _session;
  final Dio _retryClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthEndpoint(options.path)) {
      final token = await _session.currentAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sentToken = _bearer(options.headers['Authorization']);
    if (err.response?.statusCode != 401 ||
        _isAuthEndpoint(options.path) ||
        options.extra[_retriedKey] == true ||
        sentToken == null) {
      handler.next(err);
      return;
    }

    final String freshToken;
    try {
      freshToken = await _session.refresh(staleAccessToken: sentToken);
    } on SessionExpiredException {
      // Session is gone; listeners of sessionExpired route to login.
      handler.next(err);
      return;
    } on DioException {
      // Refresh failed for a transient reason; keep the session.
      handler.next(err);
      return;
    }

    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer $freshToken';
      final response = await _retryClient.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static String? _bearer(Object? header) {
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring(7);
  }

  static bool _isAuthEndpoint(String path) =>
      path.contains('${ApiConstants.v1}/auth/');
}
