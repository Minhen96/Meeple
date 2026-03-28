import 'package:isar/isar.dart';

// ignore: uri_has_not_been_generated
part 'cached_feed_item.g.dart';

/// Last 50 feed items cached for offline reading.
/// TTL: 1 hour — stale banner shown if serving from cache offline.
@collection
class CachedFeedItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String serverId;

  /// 'post' | 'activity'
  late String type;

  /// Full API response JSON serialised as a string.
  late String jsonData;

  late DateTime createdAt;
  late DateTime cachedAt;
}
