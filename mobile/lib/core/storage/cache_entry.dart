import 'package:isar/isar.dart';

part 'cache_entry.g.dart';

/// A cached API read (a JSON blob) keyed by a logical cache key such as
/// `feed:first`, `collection:all` or `notifications:first`.
///
/// Schema generated in isolation with isar_generator 3.1.0+1 (see
/// docs/MOBILE_FLUTTER.md §6) because isar_generator pins an analyzer that
/// conflicts with riverpod_generator/freezed.
@collection
class CacheEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  late String json;

  late DateTime cachedAt;
}
