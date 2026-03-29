import 'package:meeple_hearth/features/home/data/feed_repository.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_provider.g.dart';

@riverpod
class FeedNotifier extends _$FeedNotifier {
  static const _pageSize = 20;

  @override
  Future<PaginatedResult<FeedItem>> build() =>
      ref.read(feedRepositoryProvider).getFeed(PageParams(size: _pageSize));

  Future<void> refresh() async {
    state = const AsyncValue<PaginatedResult<FeedItem>>.loading();
    state = await AsyncValue.guard<PaginatedResult<FeedItem>>(
      () => ref
          .read(feedRepositoryProvider)
          .getFeed(PageParams(size: _pageSize)),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final next = await ref.read(feedRepositoryProvider).getFeed(
          PageParams(page: current.page + 1, size: _pageSize),
        );

    state = AsyncValue.data(
      PaginatedResult(
        content: [...current.content, ...next.content],
        page: next.page,
        size: next.size,
        totalElements: next.totalElements,
        totalPages: next.totalPages,
        last: next.last,
      ),
    );
  }
}
