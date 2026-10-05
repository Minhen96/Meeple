import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_repository.g.dart';

@riverpod
PostRepository postRepository(Ref ref) =>
    PostRepository(ref.read(dioProvider));

/// Fields of `CreatePostRequest` / the `PUT /posts/{id}` body.
final class PostDraft {
  const PostDraft({
    this.caption,
    this.location,
    this.playedAt,
    this.gameId,
    this.eventId,
    this.taggedUserIds = const [],
    this.imageKeys = const [],
  });

  final String? caption;
  final String? location;
  final DateTime? playedAt;
  final String? gameId;
  final String? eventId;
  final List<String> taggedUserIds;
  final List<String> imageKeys;

  Map<String, dynamic> toJson({bool forUpdate = false}) => {
        if (caption != null && (forUpdate || caption!.isNotEmpty))
          'caption': caption,
        if (location != null && (forUpdate || location!.isNotEmpty))
          'location': location,
        if (playedAt != null) 'playedAt': playedAt!.toUtc().toIso8601String(),
        if (gameId != null) 'gameId': gameId,
        if (!forUpdate && eventId != null) 'eventId': eventId,
        if (forUpdate || taggedUserIds.isNotEmpty)
          'taggedUserIds': taggedUserIds,
        if (!forUpdate && imageKeys.isNotEmpty) 'imageKeys': imageKeys,
      };
}

final class PostRepository {
  const PostRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;
  static const _posts = ApiConstants.posts;

  Post _post(Response<Object?> res) =>
      Post.fromJson(res.data! as Map<String, dynamic>);

  /// `POST /posts`. [PostDraft.imageKeys] must be keys returned by the upload
  /// endpoints for the current user; others get 400 `INVALID_IMAGE_KEY`.
  Future<Post> createPost(PostDraft draft) => guardApi(
        () async => _post(await _dio.post<Object?>(_posts, data: draft.toJson())),
      );

  /// `PUT /posts/{id}` — allowed for 48 h (`EDIT_WINDOW_EXPIRED` after).
  Future<Post> updatePost(String postId, PostDraft draft) => guardApi(
        () async => _post(
          await _dio.put<Object?>(
            '$_posts/$postId',
            data: draft.toJson(forUpdate: true),
          ),
        ),
      );

  /// Throws [NotFoundException] for posts the caller may not see.
  Future<Post> getPost(String postId) => guardApi(
        () async => _post(await _dio.get<Object?>('$_posts/$postId')),
      );

  Future<void> deletePost(String postId) =>
      guardApi(() => _dio.delete<void>('$_posts/$postId'));

  Future<void> likePost(String postId) =>
      guardApi(() => _dio.post<void>('$_posts/$postId/like'));

  Future<void> unlikePost(String postId) =>
      guardApi(() => _dio.delete<void>('$_posts/$postId/like'));

  Future<void> bookmarkPost(String postId) =>
      guardApi(() => _dio.post<void>('$_posts/$postId/bookmark'));

  Future<void> unbookmarkPost(String postId) =>
      guardApi(() => _dio.delete<void>('$_posts/$postId/bookmark'));

  /// `GET /users/me/bookmarks?cursor=`.
  Future<CursorPage<Post>> getBookmarks({String? cursor}) =>
      _page('${ApiConstants.me}/bookmarks', cursor);

  /// `GET /users/{id}/posts`.
  Future<CursorPage<Post>> getUserPosts(String userId, {String? cursor}) =>
      _page('${ApiConstants.users}/$userId/posts', cursor);

  /// `GET /posts?eventId=&cursor=` — memories of an event.
  Future<CursorPage<Post>> getEventPosts(String eventId, {String? cursor}) =>
      _page(_posts, cursor, extra: {'eventId': eventId});

  /// `GET /games/{id}/sessions?cursor=` — posts tagged with a game.
  Future<CursorPage<Post>> getGameSessions(String gameId, {String? cursor}) =>
      _page('${ApiConstants.games}/$gameId/sessions', cursor);

  Future<CursorPage<Post>> _page(
    String path,
    String? cursor, {
    Map<String, dynamic> extra = const {},
  }) =>
      guardApi(() async {
        final res = await _dio.get<Object?>(
          path,
          queryParameters: {...CursorPage.query(cursor, pageSize), ...extra},
        );
        return CursorPage.fromJson(res.data, Post.fromJson);
      });

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<CursorPage<Comment>> getComments(String postId, {String? cursor}) =>
      guardApi(() async {
        final res = await _dio.get<Object?>(
          '$_posts/$postId/comments',
          queryParameters: CursorPage.query(cursor, pageSize),
        );
        return CursorPage.fromJson(res.data, Comment.fromJson);
      });

  Future<Comment> addComment(String postId, String body) => guardApi(() async {
        final res = await _dio.post<Object?>(
          '$_posts/$postId/comments',
          data: {'body': body},
        );
        return Comment.fromJson(res.data! as Map<String, dynamic>);
      });

  /// `PUT /posts/{id}/comments/{cid}` — allowed for 24 h.
  Future<Comment> updateComment(String postId, String commentId, String body) =>
      guardApi(() async {
        final res = await _dio.put<Object?>(
          '$_posts/$postId/comments/$commentId',
          data: {'body': body},
        );
        return Comment.fromJson(res.data! as Map<String, dynamic>);
      });

  Future<void> deleteComment(String postId, String commentId) => guardApi(
        () => _dio.delete<void>('$_posts/$postId/comments/$commentId'),
      );
}
