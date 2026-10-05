import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/storage/cache_entry.dart';
import 'package:meeple_hearth/core/storage/isar_service.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';

/// A JSON value read from the offline cache.
final class CachedValue {
  const CachedValue(this.data, this.cachedAt);

  final Object? data;
  final DateTime cachedAt;

  bool isOlderThan(Duration ttl, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(cachedAt) > ttl;
}

/// Result of a cache-backed read: [cachedAt] is set when the value came from
/// the cache because the network was unavailable (shown as a stale banner).
final class CachedResult<T> {
  const CachedResult(this.data, {this.cachedAt});

  final T data;
  final DateTime? cachedAt;

  bool get isFromCache => cachedAt != null;
}

/// Key/value store for offline reads (docs/MOBILE_FLUTTER.md §6).
abstract interface class CacheStore {
  Future<CachedValue?> read(String key);
  Future<void> write(String key, Object? json);
  Future<void> remove(String key);
  Future<void> clear();
}

/// Logical cache keys and their time-to-live (MOBILE_FLUTTER §6 table).
abstract final class CacheKeys {
  static const feed = 'feed:first';
  static const notifications = 'notifications:first';
  static const upcomingEvents = 'events:upcoming';
  static String collection(String filter) => 'collection:$filter';
  static String gameDetail(String gameId) => 'game:$gameId';
  static String userProfile(String userId) => 'user:$userId';
}

abstract final class CacheTtl {
  static const feed = Duration(hours: 1);
  static const collection = Duration(hours: 24);
  static const events = Duration(minutes: 30);
  static const notifications = Duration(minutes: 30);
  static const gameDetail = Duration(days: 7);
  static const userProfile = Duration(hours: 1);
}

final cacheStoreProvider = Provider<CacheStore>((ref) {
  final isar = IsarService.instance.isarOrNull;
  return isar == null ? MemoryCacheStore() : IsarCacheStore(isar);
});

/// Network-first read that falls back to the cache when offline.
///
/// On success the fresh value is written to the cache. On a connectivity
/// failure ([NetworkException] / [TimeoutException]) a cached value younger
/// than [maxAge] is returned with its `cachedAt`; otherwise the error is
/// rethrown.
Future<CachedResult<T>> readThrough<T>({
  required CacheStore cache,
  required String key,
  required Duration maxAge,
  required Future<T> Function() fetch,
  required Object? Function(T value) encode,
  required T Function(Object? json) decode,
}) async {
  try {
    final value = await fetch();
    try {
      await cache.write(key, encode(value));
    } catch (e) {
      AppLogger.warning('Cache write failed for $key', error: e);
    }
    return CachedResult(value);
  } on ApiException catch (e, st) {
    if (e is! NetworkException && e is! TimeoutException) rethrow;
    final cached = await cache.read(key);
    if (cached == null || cached.isOlderThan(maxAge)) rethrow;
    try {
      return CachedResult(decode(cached.data), cachedAt: cached.cachedAt);
    } catch (_) {
      // Unreadable cache entry: surface the original connectivity error.
      Error.throwWithStackTrace(e, st);
    }
  }
}

/// In-memory store used when Isar is unavailable (and in tests).
final class MemoryCacheStore implements CacheStore {
  MemoryCacheStore({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _entries = <String, CachedValue>{};

  @override
  Future<CachedValue?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, Object? json) async {
    // Round-trip through JSON so callers get the same shapes as from Isar.
    _entries[key] = CachedValue(jsonDecode(jsonEncode(json)), _clock());
  }

  @override
  Future<void> remove(String key) async => _entries.remove(key);

  @override
  Future<void> clear() async => _entries.clear();
}

/// Isar-backed store: one [CacheEntry] row per key.
final class IsarCacheStore implements CacheStore {
  IsarCacheStore(this._isar);

  final Isar _isar;

  @override
  Future<CachedValue?> read(String key) async {
    final entry = await _isar.cacheEntrys.filter().keyEqualTo(key).findFirst();
    if (entry == null) return null;
    try {
      return CachedValue(jsonDecode(entry.json), entry.cachedAt);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? json) => _isar.writeTxn(() async {
        final entry = CacheEntry()
          ..key = key
          ..json = jsonEncode(json)
          ..cachedAt = DateTime.now();
        await _isar.cacheEntrys.put(entry);
      });

  @override
  Future<void> remove(String key) => _isar.writeTxn(
        () => _isar.cacheEntrys.filter().keyEqualTo(key).deleteAll(),
      );

  @override
  Future<void> clear() => _isar.writeTxn(() => _isar.cacheEntrys.clear());
}
