import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';

part 'feed_item_model.freezed.dart';
part 'feed_item_model.g.dart';

/// A single item in the home feed — either a post or a friend activity.
@freezed
class FeedItem with _$FeedItem {
  const factory FeedItem.post({
    required String id,
    required Post post,
    required DateTime feedAt,
  }) = FeedItemPost;

  const factory FeedItem.activity({
    required String id,
    required String actorId,
    required String actorDisplayName,
    String? actorAvatarUrl,
    required String activityType,
    required String description,
    String? targetId,
    required DateTime feedAt,
  }) = FeedItemActivity;

  factory FeedItem.fromJson(Map<String, dynamic> json) =>
      _$FeedItemFromJson(json);
}
