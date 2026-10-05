import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_repository.g.dart';

@riverpod
PostRepository postRepository(PostRepositoryRef ref) =>
    PostRepository(ref.read(dioProvider));

final class PostRepository {
  const PostRepository(this._dio);

  final Dio _dio;

  /// `POST /posts` (`CreatePostRequest`).
  ///
  /// [imageKeys] must be keys returned by the upload endpoints for the
  /// current user (`uploads/<userId>/…`); anything else is rejected with
  /// 400 `INVALID_IMAGE_KEY`.
  Future<Post> createPost({
    String? caption,
    List<String>? imageKeys,
    String? gameId,
    String? eventId,
    String? location,
    DateTime? playedAt,
    List<String>? taggedUserIds,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.posts,
        data: {
          if (caption != null && caption.isNotEmpty) 'caption': caption,
          if (imageKeys != null && imageKeys.isNotEmpty) 'imageKeys': imageKeys,
          if (gameId != null) 'gameId': gameId,
          if (eventId != null) 'eventId': eventId,
          if (location != null && location.isNotEmpty) 'location': location,
          if (playedAt != null) 'playedAt': playedAt.toUtc().toIso8601String(),
          if (taggedUserIds != null && taggedUserIds.isNotEmpty)
            'taggedUserIds': taggedUserIds,
        },
      );
      return Post.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Throws [NotFoundException] for posts the caller may not see.
  Future<Post> getPost(String postId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiConstants.posts}/$postId',
      );
      return Post.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _dio.delete<void>('${ApiConstants.posts}/$postId');
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> likePost(String postId) async {
    try {
      await _dio.post<void>('${ApiConstants.posts}/$postId/like');
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> unlikePost(String postId) async {
    try {
      await _dio.delete<void>('${ApiConstants.posts}/$postId/like');
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<PaginatedResult<Comment>> getComments({
    required String postId,
    PageParams params = const PageParams(),
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiConstants.posts}/$postId/comments',
        queryParameters: params.toQueryParams(),
      );
      return PaginatedResult.fromJson(
        response.data!,
        (item) => Comment.fromJson(item as Map<String, dynamic>),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Comment> addComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiConstants.posts}/$postId/comments',
        data: {'body': content},
      );
      return Comment.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
