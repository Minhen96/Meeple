import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';

/// Answers every refresh with a rotated pair after a short delay.
class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter({this.status = 200});

  final int status;
  final presentedCookies = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    presentedCookies.add(options.headers['Cookie'] as String?);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final n = presentedCookies.length;
    return ResponseBody.fromString(
      status == 200 ? '{"data":{}}' : '{"error":"x","code":"UNAUTHORIZED"}',
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (status == 200)
          'set-cookie': [
            'access_token=access$n; Path=/; HttpOnly',
            'refresh_token=refresh$n; Path=/; HttpOnly',
          ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorage storage;

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
    final adapter = _RefreshAdapter();
    final manager = AuthSessionManager(
      storage,
      refreshDio: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter,
    );

    final results = await Future.wait([
      manager.refresh(staleAccessToken: 'access0'),
      manager.refresh(staleAccessToken: 'access0'),
      manager.refresh(staleAccessToken: 'access0'),
    ]);

    expect(adapter.presentedCookies, ['refresh_token=refresh0']);
    expect(results.toSet(), {'access1'});
    final session = (await storage.getSession())!;
    expect(session.accessToken, 'access1');
    expect(session.refreshToken, 'refresh1');
    expect(session.userId, 'u1');

    // A late caller holding the old token reuses the stored one.
    expect(await manager.refresh(staleAccessToken: 'access0'), 'access1');
    expect(adapter.presentedCookies, hasLength(1));
  });

  test('a rejected refresh clears the session and signals expiry', () async {
    final manager = AuthSessionManager(
      storage,
      refreshDio: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _RefreshAdapter(status: 401),
    );
    final expired = expectLater(manager.sessionExpired, emits(null));

    await expectLater(
      manager.refresh(staleAccessToken: 'access0'),
      throwsA(isA<SessionExpiredException>()),
    );
    await expired;
    expect(await storage.getSession(), isNull);
  });
}
