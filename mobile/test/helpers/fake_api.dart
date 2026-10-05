import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';

/// A canned response.
final class FakeResponse {
  const FakeResponse(this.body, {this.status = 200, this.headers = const {}})
      : code = null,
        message = null;

  /// A sign-in response: the body plus `access_token` / `refresh_token`
  /// cookies, as the backend issues them.
  const FakeResponse.signedIn(this.body)
      : status = 200,
        code = null,
        message = null,
        headers = const {
          'set-cookie': [
            'access_token=a2; Path=/; HttpOnly',
            'refresh_token=r2; Path=/; HttpOnly',
          ],
        };

  const FakeResponse.noContent()
      : body = null,
        status = 204,
        code = null,
        message = null,
        headers = const {};

  const FakeResponse.error(this.status, this.code, [this.message = 'error'])
      : body = null,
        headers = const {};

  final Object? body;
  final int status;
  final String? code;
  final String? message;
  final Map<String, List<String>> headers;

  Object? get payload => code == null ? body : {'error': message, 'code': code};
}

typedef FakeHandler = FakeResponse Function(RequestOptions request);

/// Routes Dio requests to handlers keyed by `"METHOD /path"` (no query).
/// Unknown routes answer 404 `NOT_FOUND`. Every request is recorded.
final class FakeApi implements HttpClientAdapter {
  final _routes = <String, FakeHandler>{};
  final requests = <RequestOptions>[];

  /// Registers [response] (a [FakeResponse], a handler, or a JSON body that
  /// is wrapped in `{data: ...}` like `ResponseWrappingAdvice` does).
  void on(String method, String path, Object? response) {
    _routes['$method $path'] = switch (response) {
      final FakeHandler h => h,
      final FakeResponse r => (_) => r,
      _ => (_) => FakeResponse({'data': response}),
    };
  }

  void get(String path, Object? response) => on('GET', path, response);
  void post(String path, Object? response) => on('POST', path, response);
  void put(String path, Object? response) => on('PUT', path, response);
  void delete(String path, Object? response) => on('DELETE', path, response);

  bool called(String method, String path) =>
      requests.any((r) => r.method == method && r.uri.path == path);

  List<RequestOptions> calls(String method, String path) => requests
      .where((r) => r.method == method && r.uri.path == path)
      .toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = _routes['${options.method} ${options.uri.path}'];
    final response = handler?.call(options) ??
        const FakeResponse.error(404, 'NOT_FOUND', 'Not found');
    if (response.status == 204) {
      return ResponseBody.fromString('', 204);
    }
    return ResponseBody.fromString(
      jsonEncode(response.payload),
      response.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...response.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}

  /// A Dio wired like production (envelope unwrapping) minus auth.
  Dio dio() => Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = this
    ..interceptors.add(ApiResponseUnwrapInterceptor());
}
