import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/app.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';

import '../helpers/fake_api.dart';
import '../helpers/harness.dart';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
  });

  testWidgets('offline: banner, write guard, cached feed with stale banner',
      (tester) async {
    final cache = MemoryCacheStore();
    // First run online fills the cache.
    final c = await pumpApp(
      tester,
      api: api,
      overrides: [cacheStoreProvider.overrideWithValue(cache)],
    );
    expect(await cache.read(CacheKeys.feed), isNotNull);
    c.dispose();

    // Network down: requests fail, the feed comes from the cache.
    final offline = FakeApi();
    stubDefaults(offline);
    offline.on(
      'GET',
      '/api/v1/feed',
      (RequestOptions r) => throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      ),
    );
    await pumpApp(
      tester,
      api: offline,
      online: false,
      overrides: [cacheStoreProvider.overrideWithValue(cache)],
    );
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Great game night'), findsOneWidget);
    expect(find.textContaining('Showing cached data'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('like-p1')));
    await settle(tester);
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(offline.called('POST', '/api/v1/posts/p1/like'), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('biometric lock covers the app until unlocked', (tester) async {
    await pumpApp(tester, api: api);
    // Enable the lock for the next launch.
    FlutterSecureStorage.setMockInitialValues({
      ...await const FlutterSecureStorage().readAll(),
      'pref_biometric_enabled': 'true',
    });
    final container = ProviderContainer(overrides: baseOverrides(api));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MeepleApp()),
    );
    await settle(tester);

    expect(find.text('Meeple is locked'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-lock-unlock')));
    await settle(tester);
    expect(find.text('Meeple is locked'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('push pre-prompt screen without Firebase just closes',
      (tester) async {
    final c = await pumpApp(tester, api: api);
    await push(tester, c, '/push-permission');
    expect(find.text('Stay in the loop about your game nights'), findsOneWidget);
    await tester.tap(find.byKey(const Key('push-not-now')));
    await settle(tester);
    expect(find.text('Stay in the loop about your game nights'), findsNothing);

    await push(tester, c, '/push-permission');
    await tester.tap(find.byKey(const Key('push-allow')));
    await settle(tester);
    expect(find.text('Stay in the loop about your game nights'), findsNothing);
  });
}



