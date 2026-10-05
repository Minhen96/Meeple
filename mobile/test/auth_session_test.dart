import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/auth_interceptor.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';

ResponseBody _json(String body, int status, {List<String>? cookies}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (cookies != null) 'set-cookie': cookies,
      },
    );

ResponseBody _rotated(int n) => _json(
      '{"data":{}}',
      200,
      cookies: [
        'access_token=access$n; Path=/; HttpOnly',
        'refresh_token=refresh$n; Path=/; HttpOnly',
      ],
    );

ResponseBody _refreshRace() => _json(
      '{"error":"Refresh token was rotated by a concurrent request",'
      '"code":"REFRESH_RACE"}',
      409,
    );

/// Routes every request through [handler] and records what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, int call) handler;
  final requests = <RequestOptions>[];

  List<String?> get refreshCookies => requests
      .where((r) => r.path == ApiConstants.refresh)
      .map((r) => r.headers['Cookie'] as String?)
      .toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorage storage;

  AuthSessionManager manager(_Adapter adapter) => AuthSessionManager(
        storage,
        refreshDio: Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = adapter,
        refreshRaceDelay: const Duration(milliseconds: 10),
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorage();
    await storage.saveTokens(
      accessToken: 'access0',
      refreshToken: 'refresh0',
      userId: 'u1',
    );
  });

  test('concurrent refreshes share one request and persist the new pair',
      () async {
    final adapter = _Adapter((_, n) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _rotated(n);
    });
    final session = manager(adapter);

    final results = await Future.wait([
      session.refresh(staleAccessToken: 'access0'),
      session.refresh(staleAccessToken: 'access0'),
      session.refresh(staleAccessToken: 'access0'),
    ]);

    expect(adapter.refreshCookies, ['refresh_token=refresh0']);
    expect(results.toSet(), {'access1'});
    final stored = (await storage.getSession())!;
    expect(stored.accessToken, 'access1');
    expect(stored.refreshToken, 'refresh1');
    expect(stored.userId, 'u1');

    // A late caller holding the old token reuses the stored one.
    expect(await session.refresh(staleAccessToken: 'access0'), 'access1');
    expect(adapter.refreshCookies, hasLength(1));
  });

  test('a rejected refresh clears the session and signals expiry', () async {
    final session = manager(
      _Adapter((_, __) async => _json('{"code":"UNAUTHORIZED"}', 401)),
    );
    final expired = expectLater(session.sessionExpired, emits(null));

    await expectLater(
      session.refresh(staleAccessToken: 'access0'),
      throwsA(isA<SessionExpiredException>()),
    );
    await expired;
    expect(await storage.getSession(), isNull);
  });

  group('logout while a refresh is in flight', () {
    test('the rotated tokens are discarded, not persisted', () async {
      final gate = Completer<void>();
      final adapter = _Adapter((_, n) async {
        await gate.future;
        return _rotated(n);
      });
      final session = manager(adapter);

      final refreshing = session.refresh(staleAccessToken: 'access0');
      await pumpEventQueue();
      expect(adapter.refreshCookies, hasLength(1));

      await session.clear(); // logout
      gate.complete();

      await expectLater(refreshing, throwsA(isA<SessionExpiredException>()));
      expect(await storage.getSession(), isNull);
    });

    test('a late 401 does not wipe the session of a new sign-in', () async {
      final gate = Completer<void>();
      final session = manager(_Adapter((_, __) async {
        await gate.future;
        return _json('{"code":"UNAUTHORIZED"}', 401);
      }));
      var expiredEvents = 0;
      final sub = session.sessionExpired.listen((_) => expiredEvents++);

      final refreshing = session.refresh(staleAccessToken: 'access0');
      await pumpEventQueue();
      await session.clear();
      await session.saveTokens(
        const AuthTokens(accessToken: 'accessB', refreshToken: 'refreshB'),
        userId: 'u2',
      );
      gate.complete();

      await expectLater(refreshing, throwsA(isA<SessionExpiredException>()));
      await pumpEventQueue();
      final stored = (await storage.getSession())!;
      expect(stored.accessToken, 'accessB');
      expect(stored.refreshToken, 'refreshB');
      expect(stored.userId, 'u2');
      expect(expiredEvents, 0);
      await sub.cancel();
    });
  });

  group('409 REFRESH_RACE', () {
    test('is not fatal: returns the tokens the winning refresh stored',
        () async {
      final session = manager(_Adapter((_, __) async {
        // Another isolate won the race and persists its rotated pair.
        await storage.saveTokens(
          accessToken: 'accessW',
          refreshToken: 'refreshW',
        );
        return _refreshRace();
      }));
      var expiredEvents = 0;
      final sub = session.sessionExpired.listen((_) => expiredEvents++);

      expect(await session.refresh(staleAccessToken: 'access0'), 'accessW');
      await pumpEventQueue();
      final stored = (await storage.getSession())!;
      expect(stored.refreshToken, 'refreshW');
      expect(stored.userId, 'u1');
      expect(expiredEvents, 0);
      await sub.cancel();
    });

    test('the original request is retried once and the user stays signed in',
        () async {
      var refreshCalls = 0;
      final adapter = _Adapter((options, _) async {
        if (options.path == ApiConstants.refresh) {
          refreshCalls++;
          // The rotation winner lands while we back off.
          await storage.saveTokens(
            accessToken: 'accessW',
            refreshToken: 'refreshW',
          );
          return _refreshRace();
        }
        final auth = options.headers['Authorization'];
        return auth == 'Bearer accessW'
            ? _json('{"data":{"ok":true}}', 200)
            : _json('{"code":"UNAUTHORIZED"}', 401);
      });
      final session = manager(adapter);
      final api = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      api.interceptors.add(AuthInterceptor(session: session, retryClient: api));

      final res = await api.get<Map<String, dynamic>>('/api/v1/users/me');

      expect(res.statusCode, 200);
      expect(refreshCalls, 1);
      final apiCalls =
          adapter.requests.where((r) => r.path == '/api/v1/users/me');
      expect(apiCalls, hasLength(2)); // original + exactly one retry
      expect((await storage.getSession())!.accessToken, 'accessW');
    });

    test('a retry that still fails surfaces the error without logging out',
        () async {
      final adapter = _Adapter((options, _) async {
        if (options.path == ApiConstants.refresh) return _refreshRace();
        return _json('{"code":"UNAUTHORIZED"}', 401);
      });
      final session = manager(adapter);
      final api = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      api.interceptors.add(AuthInterceptor(session: session, retryClient: api));

      await expectLater(
        api.get<dynamic>('/api/v1/users/me'),
        throwsA(isA<DioException>()),
      );
      expect(
        adapter.requests.where((r) => r.path == '/api/v1/users/me'),
        hasLength(2),
      );
      expect(await storage.getSession(), isNotNull);
    });
  });
}
