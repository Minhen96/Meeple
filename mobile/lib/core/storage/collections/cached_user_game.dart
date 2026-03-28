import 'package:isar/isar.dart';

// ignore: uri_has_not_been_generated
part 'cached_user_game.g.dart';

/// Cached user-game relationship for offline access to collection status.
@collection
class CachedUserGame {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String gameId;

  late bool isOwned;
  late bool isWishlisted;
  late bool isFavorited;
  int playCount = 0;
  int? personalRating;
  late DateTime updatedAt;
}
