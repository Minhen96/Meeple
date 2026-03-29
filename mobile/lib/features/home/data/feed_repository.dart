import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_repository.g.dart';

@riverpod
FeedRepository feedRepository(FeedRepositoryRef ref) =>
    FeedRepository(ref.read(dioProvider));

final class FeedRepository {
  const FeedRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResult<FeedItem>> getFeed(PageParams params) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.feed,
        queryParameters: params.toQueryParams(),
      );
      return PaginatedResult.fromJson(
        response.data!,
        (item) => FeedItem.fromJson(item as Map<String, dynamic>),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
