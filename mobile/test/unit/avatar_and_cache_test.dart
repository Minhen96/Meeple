import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';

final class _FailingWrites implements CacheStore {
  @override
  Future<CachedValue?> read(String key) async => null;
  @override
  Future<void> write(String key, Object? json) async =>
      throw StateError('disk full');
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('avatar: initials, online indicator, border, network image',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            AppAvatar(displayName: 'Mia Meeple', showOnlineIndicator: true,
                isOnline: true),
            AppAvatar(displayName: 'solo', borderColor: Colors.red),
            AppAvatar(),
            AppAvatar(imageUrl: 'https://cdn/x.jpg', displayName: 'Img',
                showOnlineIndicator: true),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('MM'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  group('readThrough', () {
    Future<CachedResult<int>> read(
      CacheStore cache,
      Future<int> Function() fetch, {
      int Function(Object?)? decode,
    }) =>
        readThrough<int>(
          cache: cache,
          key: 'k',
          maxAge: const Duration(hours: 1),
          fetch: fetch,
          encode: (v) => v,
          decode: decode ?? (json) => json! as int,
        );

    test('a failing cache write still returns the fresh value', () async {
      final result = await read(_FailingWrites(), () async => 7);
      expect(result.data, 7);
      expect(result.cachedAt, isNull);
    });

    test('offline: cached value, unreadable cache and other errors', () async {
      final cache = MemoryCacheStore();
      await read(cache, () async => 3);
      final offline = await read(
        cache,
        () async => throw const NetworkException(),
      );
      expect(offline.data, 3);
      expect(offline.cachedAt, isNotNull);

      await expectLater(
        read(cache, () async => throw const NetworkException(),
            decode: (_) => throw const FormatException()),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        read(cache, () async => throw const ServerException()),
        throwsA(isA<ServerException>()),
      );
      await cache.remove('k');
      await expectLater(
        read(cache, () async => throw const NetworkException()),
        throwsA(isA<NetworkException>()),
      );
      await cache.clear();
    });
  });
}
