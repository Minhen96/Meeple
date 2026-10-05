import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/auth_interceptor.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_client.g.dart';

@Riverpod(keepAlive: true)
Dio dio(DioRef ref) {
  final session = ref.read(authSessionManagerProvider);

  final client = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(
        milliseconds: ApiConstants.connectTimeoutMs,
      ),
      receiveTimeout: const Duration(
        milliseconds: ApiConstants.receiveTimeoutMs,
      ),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  client.interceptors.addAll([
    AuthInterceptor(session: session, retryClient: client),
    ApiResponseUnwrapInterceptor(),
    _SafeLogInterceptor(),
  ]);
  return client;
}

/// Unwraps the backend's `{ "data": T }` success envelope so repositories read
/// `T` directly.
///
/// Paginated `{ "data": [...], "meta": {...} }` bodies are left intact for
/// `PaginatedResult.fromJson`, and error bodies (`{ "error", "code" }`) never
/// reach this interceptor's `onResponse`.
class ApiResponseUnwrapInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (data is Map && data.length == 1 && data.containsKey('data')) {
      response.data = data['data'];
    }
    handler.next(response);
  }
}

/// Logs method, path and status only — never query strings (they can contain
/// email addresses), headers (tokens, cookies) or bodies.
class _SafeLogInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    AppLogger.warning(
      '${o.method} ${o.uri.path} failed: '
      '${err.response?.statusCode ?? err.type.name}',
    );
    handler.next(err);
  }
}
