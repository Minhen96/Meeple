import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';

/// Dio interceptor that:
/// 1. Attaches the Bearer token to every request.
/// 2. Transparently refreshes the access token on 401 and retries once.
/// 3. Forces logout (clears storage) if the refresh itself fails.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required SecureStorage storage, required Ref ref})
      : _storage = storage,
        _ref = ref;

  final SecureStorage _storage;
  final Ref _ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        await _refreshAndRetry(err, handler);
      } catch (_) {
        // Refresh failed — clear all credentials and let the router redirect.
        await _storage.clearAll();
        // Invalidating the provider notifies the RouterNotifier → GoRouter
        // redirect will send the user to /auth/login.
        _ref.invalidate(secureStorageProvider);
        handler.reject(err);
      }
      return;
    }
    handler.next(err);
  }

  Future<void> _refreshAndRetry(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token stored');

    // Use a fresh Dio instance to avoid recursive interceptor triggering.
    final refreshDio = Dio(
      BaseOptions(baseUrl: ApiConstants.baseUrl),
    );

    final response = await refreshDio.post<Map<String, dynamic>>(
      ApiConstants.refresh,
      data: {'refreshToken': refreshToken},
    );

    final data = response.data!;
    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    // Retry the original request with the new access token.
    final opts = err.requestOptions;
    opts.headers['Authorization'] = 'Bearer ${data['accessToken']}';
    final retryResponse = await refreshDio.fetch<dynamic>(opts);
    handler.resolve(retryResponse);
  }
}
