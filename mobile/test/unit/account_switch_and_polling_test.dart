// Regression tests: per-account data isolation (keepAlive providers, offline
// cache, recent searches, session expiry) and resilient BGG-import /
// How-to-Play polling.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/home/providers/feed_provider.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/search/providers/search_provider.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

/// Holds the next request to a path until released.
final class _Gate extends Interceptor {
  final _held = <String, Completer<void>>{};

  Completer<void> holdNext(String path) => _held[path] = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final hold = _held.remove(options.path);
    if (hold != null) await hold.future;
    handler.next(options);
  }
}

/// Lets queued fake-API responses arrive (Dio needs the clock to move).
Future<void> idle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  group('account switch', () {
    late FakeApi api;
    late ProviderContainer container;
    late FakeGoogle google;
    late MemoryCacheStore rawCache;

    setUp(() {
      signIn(); // user "me"
      api = FakeApi();
      stubDefaults(api);
      api
        ..post('/api/v1/auth/logout', const FakeResponse.noContent())
        ..post(
          '/api/v1/auth/login',
          (RequestOptions _) => FakeResponse.signedIn(
            {'data': userJson(id: 'u2', username: 'bob')},
          ),
        );
      google = FakeGoogle();
      rawCache = MemoryCacheStore();
      container = ProviderContainer(
        overrides: [
          ...baseOverrides(api, google: google),
          cacheStoreProvider.overrideWith(
            (ref) => UserScopedCacheStore(
              rawCache,
              userId: ref.read(secureStorageProvider).getUserId,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    void keep(ProviderListenable<Object?> provider) =>
        container.listen(provider, (_, __) {}, fireImmediately: true);

    Future<void> loginAsBob() =>
        container.read(authNotifierProvider.notifier).login(
              emailOrUsername: 'bob',
              password: 'secret',
            );

    test('feed, collection and recent searches reset for the next account',
        () async {
      keep(authNotifierProvider);
      expect((await container.read(authNotifierProvider.future))!.id, 'me');
      expect(container.read(authUserIdProvider), 'me');
      keep(feedNotifierProvider);
      keep(collectionNotifierProvider);
      keep(recentSearchesProvider);
      expect(
        (await container.read(feedNotifierProvider.future)).items,
        hasLength(2),
      );
      expect(
        (await container.read(collectionNotifierProvider.future)).items,
        hasLength(3),
      );
      await container.read(recentSearchesProvider.future);
      await container.read(recentSearchesProvider.notifier).add('catan');

      await container.read(authNotifierProvider.notifier).logout();
      expect(container.read(authUserIdProvider), isNull);
      expect(await container.read(recentSearchesProvider.future), isEmpty);

      // Bob's account has nothing yet.
      api
        ..get('/api/v1/feed', cursor([]))
        ..get('/api/v1/users/me/games', <Object>[]);
      await loginAsBob();
      expect(container.read(authUserIdProvider), 'u2');

      expect((await container.read(feedNotifierProvider.future)).items,
          isEmpty);
      expect(
        (await container.read(collectionNotifierProvider.future)).items,
        isEmpty,
      );
      expect(await container.read(recentSearchesProvider.future), isEmpty);
      await container.read(recentSearchesProvider.notifier).add('azul');

      // Profile edits keep the id: no reload.
      final feedCalls = api.calls('GET', '/api/v1/feed').length;
      container.read(authNotifierProvider.notifier).updateUser(
            container.read(authNotifierProvider).value!.copyWith(bio: 'new'),
          );
      await pumpEventQueue();
      expect(api.calls('GET', '/api/v1/feed'), hasLength(feedCalls));

      // Searches are stored per account.
      final storage = container.read(secureStorageProvider);
      expect(
        await storage.readPref(RecentSearches.prefKeyFor('me')),
        '["catan"]',
      );
      expect(
        await storage.readPref(RecentSearches.prefKeyFor('u2')),
        '["azul"]',
      );
    });

    test('a rejected refresh clears local data like a logout', () async {
      keep(authNotifierProvider);
      await container.read(authNotifierProvider.future);
      final cache = container.read(cacheStoreProvider);
      await cache.write(CacheKeys.feed, {'items': <Object>[]});
      expect(await rawCache.read('u:me|${CacheKeys.feed}'), isNotNull);

      // The refresh token is gone: the session manager signals expiry.
      await container.read(secureStorageProvider).clearSession();
      await expectLater(
        container.read(authSessionManagerProvider).refresh(),
        throwsA(isA<SessionExpiredException>()),
      );
      await pumpEventQueue();

      expect(container.read(authNotifierProvider).value, isNull);
      expect(await rawCache.read('u:me|${CacheKeys.feed}'), isNull);
      expect(google.signOuts, 1);
    });

    test('the legacy shared recent-searches key is removed', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_session':
            '{"accessToken":"a","refreshToken":"r","userId":"me"}',
        'pref_recent_searches': '["someone else"]',
      });
      keep(authNotifierProvider);
      await container.read(authNotifierProvider.future);
      keep(recentSearchesProvider);
      expect(await container.read(recentSearchesProvider.future), isEmpty);
      expect(
        await container.read(secureStorageProvider).readPref('recent_searches'),
        isNull,
      );
    });
  });

  group('UserScopedCacheStore', () {
    test('one account never reads another account\'s entries', () async {
      String? user = 'a';
      final raw = MemoryCacheStore();
      final cache = UserScopedCacheStore(raw, userId: () async => user);

      await cache.write('feed:first', {'v': 'A'});
      expect((await cache.read('feed:first'))!.data, {'v': 'A'});

      user = 'b';
      expect(await cache.read('feed:first'), isNull);
      await cache.write('feed:first', {'v': 'B'});

      user = null; // signed out: reads miss, writes are dropped
      expect(await cache.read('feed:first'), isNull);
      await cache.write('x', 1);
      await cache.remove('feed:first');
      await (await cache.forCurrentUser()).clear();
      expect(await raw.read('u:b|feed:first'), isNotNull);

      user = 'a';
      expect((await cache.read('feed:first'))!.data, {'v': 'A'});
      await cache.remove('feed:first');
      expect(await cache.read('feed:first'), isNull);

      await cache.clear(); // logout wipes every account
      expect(await raw.read('u:b|feed:first'), isNull);
    });

    test('readThrough files a response under the account that asked for it',
        () async {
      String? user = 'a';
      final raw = MemoryCacheStore();
      final cache = UserScopedCacheStore(raw, userId: () async => user);
      final response = Completer<String>();

      final read = readThrough<String>(
        cache: cache,
        key: 'k',
        maxAge: const Duration(hours: 1),
        fetch: () => response.future,
        encode: (v) => v,
        decode: (j) => j! as String,
      );
      await pumpEventQueue();
      user = 'b'; // account switched while the request was in flight
      response.complete('A data');
      await read;

      expect((await raw.read('u:a|k'))!.data, 'A data');
      expect(await raw.read('u:b|k'), isNull);
    });
  });

  group('polling', () {
    late FakeApi api;
    late _Gate gate;

    ProviderContainer containerFor(WidgetTester tester) {
      signIn();
      api = FakeApi();
      stubDefaults(api);
      gate = _Gate();
      final container = ProviderContainer(
        overrides: [
          ...baseOverrides(api),
          dioProvider.overrideWithValue(api.dio()..interceptors.add(gate)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    const status = '/api/v1/users/me/bgg-import/status';

    testWidgets('BGG import keeps polling through transient errors',
        (tester) async {
      final c = containerFor(tester);
      var calls = 0;
      final replies = <FakeResponse>[
        const FakeResponse({
          'data': {'status': 'running'},
        }),
        const FakeResponse.error(503, 'BGG_API_UNAVAILABLE'),
        const FakeResponse.error(500, 'INTERNAL'),
        const FakeResponse({
          'data': {'status': 'running', 'imported': 3},
        }),
        const FakeResponse({
          'data': {'status': 'done', 'imported': 5},
        }),
      ];
      api.get(status, (RequestOptions _) => replies[calls++]);
      c.listen(bggImportProvider, (_, __) {}, fireImmediately: true);
      await idle(tester);
      expect(c.read(bggImportProvider).value!.isRunning, isTrue);

      // 2 s → 503 (kept running), 4 s backoff → 500, 8 s → running, 2 s → done.
      await tester.pump(BggImport.pollInterval);
      await idle(tester);
      expect(calls, 2);
      expect(c.read(bggImportProvider).value!.isRunning, isTrue);
      await tester.pump(const Duration(seconds: 4));
      await idle(tester);
      expect(calls, 3);
      expect(c.read(bggImportProvider).hasError, isFalse);
      await tester.pump(const Duration(seconds: 8));
      await idle(tester);
      expect(calls, 4);
      await tester.pump(BggImport.pollInterval);
      await idle(tester);
      expect(calls, 5);
      expect(c.read(bggImportProvider).value!.isDone, isTrue);

      // Terminal state: no more polls.
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 5);
    });

    testWidgets('BGG import stops polling on 401/403/404', (tester) async {
      final c = containerFor(tester);
      var calls = 0;
      api.get(
        status,
        (RequestOptions _) => calls++ == 0
            ? const FakeResponse({
                'data': {'status': 'running'},
              })
            : const FakeResponse.error(404, 'NOT_FOUND'),
      );
      c.listen(bggImportProvider, (_, __) {}, fireImmediately: true);
      await idle(tester);
      await tester.pump(BggImport.pollInterval);
      await idle(tester);
      expect(c.read(bggImportProvider).error, isA<NotFoundException>());
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 2);
    });

    testWidgets('a poll answered after a rebuild does not overwrite the state',
        (tester) async {
      final c = containerFor(tester);
      api.get(status, {'status': 'running'});
      c.listen(bggImportProvider, (_, __) {}, fireImmediately: true);
      await idle(tester);

      final held = gate.holdNext(status);
      await tester.pump(BggImport.pollInterval); // poll starts and waits
      api.get(status, {'status': 'done'});
      c.invalidate(bggImportProvider); // rebuild reads "done"
      await idle(tester);
      expect(c.read(bggImportProvider).value!.isDone, isTrue);

      // The stale "running" answer is dropped; nothing polls any more.
      api.get(status, {'status': 'running'});
      final before = api.calls('GET', status).length;
      held.complete(); // the held poll now reaches the server
      await idle(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(c.read(bggImportProvider).value!.isDone, isTrue);
      expect(api.calls('GET', status), hasLength(before + 1));
    });

    testWidgets('a start answered after dispose does not schedule polls',
        (tester) async {
      final c = containerFor(tester);
      api
        ..get(status, {'status': 'idle'})
        ..post('/api/v1/users/me/bgg-import', {'status': 'running'});
      final sub =
          c.listen(bggImportProvider, (_, __) {}, fireImmediately: true);
      await idle(tester);
      final held = gate.holdNext('/api/v1/users/me/bgg-import');
      final notifier = c.read(bggImportProvider.notifier);
      final starting = notifier.start('alice');
      await idle(tester);
      sub.close(); // screen left: the auto-dispose provider goes away
      await idle(tester);
      final before = api.calls('GET', status).length;
      held.complete();
      await idle(tester);
      await starting;
      await tester.pump(const Duration(seconds: 10));
      expect(api.calls('GET', status), hasLength(before));
    });

    testWidgets('How-to-Play keeps the guide through transient poll errors',
        (tester) async {
      final c = containerFor(tester);
      const path = '/api/v1/games/g1/how-to-play';
      var calls = 0;
      api.get(
        path,
        (RequestOptions _) => switch (calls++) {
          0 => const FakeResponse({
              'data': {'status': 'generating'},
            }),
          1 => const FakeResponse.error(502, 'BAD_GATEWAY'),
          2 => const FakeResponse({
              'data': {'status': 'generating'},
            }),
          3 => const FakeResponse.error(403, 'FORBIDDEN'),
          _ => const FakeResponse({
              'data': {'status': 'ready'},
            }),
        },
      );
      final provider = howToPlayNotifierProvider('g1');
      c.listen(provider, (_, __) {}, fireImmediately: true);
      await idle(tester);
      expect(c.read(provider).value!.status, 'generating');

      await tester.pump(HowToPlayNotifier.pollInterval);
      await idle(tester);
      expect(calls, 2);
      expect(c.read(provider).value!.status, 'generating');
      expect(c.read(provider).hasError, isFalse);

      await tester.pump(const Duration(seconds: 6)); // backoff
      await idle(tester);
      expect(calls, 3);
      await tester.pump(HowToPlayNotifier.pollInterval);
      await idle(tester);
      expect(calls, 4);
      expect(c.read(provider).error, isA<ForbiddenException>());
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 4);
    });

    test('backoff doubles per failure and is capped', () {
      const base = Duration(seconds: 2);
      expect(backoff(base, 0), base);
      expect(backoff(base, 1), const Duration(seconds: 4));
      expect(backoff(base, 3), const Duration(seconds: 16));
      expect(backoff(base, 20), const Duration(seconds: 30));
      expect(isTerminalPollError(const UnauthorizedException()), isTrue);
      expect(isTerminalPollError(Exception('x')), isFalse);
    });
  });
}
