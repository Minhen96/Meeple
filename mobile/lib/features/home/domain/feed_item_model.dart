// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'feed_item_model.freezed.dart';
part 'feed_item_model.g.dart';

/// An item of `GET /feed` (GAP §6.1 [WP3]): a post or a friend activity,
/// discriminated by `kind`.
@Freezed(unionKey: 'kind', fallbackUnion: 'unknown')
class FeedItem with _$FeedItem {
  @FreezedUnionValue('post')
  const factory FeedItem.post({
    required DateTime createdAt,
    required Post post,
  }) = FeedPostItem;

  @FreezedUnionValue('activity')
  const factory FeedItem.activity({
    required DateTime createdAt,
    required FeedActivity activity,
  }) = FeedActivityItem;

  /// Kinds this client does not know yet; skipped when rendering.
  const factory FeedItem.unknown({DateTime? createdAt}) = FeedUnknownItem;

  factory FeedItem.fromJson(Map<String, dynamic> json) =>
      _$FeedItemFromJson(json);

  /// Wraps a bare `PostResponse` (legacy feed shape).
  factory FeedItem.fromPost(Post post) =>
      FeedItem.post(createdAt: post.createdAt, post: post);
}

/// `{id, type: collection_add|event_created|event_joined, user, data}`.
@freezed
class FeedActivity with _$FeedActivity {
  const factory FeedActivity({
    required String id,
    required String type,
    required UserSummary user,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
  }) = _FeedActivity;

  const FeedActivity._();

  factory FeedActivity.fromJson(Map<String, dynamic> json) =>
      _$FeedActivityFromJson(json);

  String? get gameId => data['gameId'] as String?;
  String? get gameName =>
      (data['gameName'] ?? data['gameTitle'] ?? data['title']) as String?;
  String? get eventId => data['eventId'] as String?;
  String? get eventTitle => (data['eventTitle'] ?? data['title']) as String?;
}
