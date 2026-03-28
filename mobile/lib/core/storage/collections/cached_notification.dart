import 'package:isar/isar.dart';

// ignore: uri_has_not_been_generated
part 'cached_notification.g.dart';

/// Cached notifications for offline access. TTL: 30 minutes.
@collection
class CachedNotification {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String serverId;

  late String type;
  late String title;
  late String body;
  late bool isRead;
  late DateTime createdAt;
  late DateTime cachedAt;
}
