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

  Future<Post> createPost({
    required String content,
    List<String>? imageUrls,
    String? taggedGameId,
    String? linkedEventId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.posts,
        data: {
          'content': content,
          if (imageUrls != null && imageUrls.isNotEmpty) 'imageUrls': imageUrls,
          if (taggedGameId != null) 'taggedGameId': taggedGameId,
          if (linkedEventId != null) 'linkedEventId': linkedEventId,
        },
      );
      return Post.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

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
        data: {'content': content},
      );
      return Comment.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
