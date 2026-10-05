import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_repository.g.dart';

@riverpod
FeedRepository feedRepository(Ref ref) =>
    FeedRepository(ref.read(dioProvider));

final class FeedRepository {
  const FeedRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;

  /// `GET /feed?cursor=&limit=20` → `{items: FeedItem[], nextCursor, hasMore}`
  /// where each item is `{kind: post|activity, createdAt, post?, activity?}`.
  ///
  /// Bare `PostResponse` items (the legacy `?page=` feed) are wrapped as post
  /// items.
  Future<CursorPage<FeedItem>> getFeed({String? cursor}) => guardApi(() async {
        final res = await _dio.get<Object?>(
          ApiConstants.feed,
          queryParameters: CursorPage.query(cursor, pageSize),
        );
        return CursorPage.fromJson(res.data, parseFeedItem);
      });

  static FeedItem parseFeedItem(Map<String, dynamic> json) =>
      json.containsKey('kind')
          ? FeedItem.fromJson(json)
          : FeedItem.fromPost(Post.fromJson(json));
}
