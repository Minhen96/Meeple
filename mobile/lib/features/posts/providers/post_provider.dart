import 'package:meeple_hearth/features/posts/data/post_repository.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_provider.g.dart';

/// Single post detail.
@riverpod
Future<Post> postDetail(PostDetailRef ref, String postId) =>
    ref.read(postRepositoryProvider).getPost(postId);

/// Paginated comments for a post.
@riverpod
class CommentsNotifier extends _$CommentsNotifier {
  static const _pageSize = 20;

  @override
  Future<PaginatedResult<Comment>> build(String postId) => ref
      .read(postRepositoryProvider)
      .getComments(postId: postId, params: PageParams(size: _pageSize));

  Future<void> refresh() async {
    state = const AsyncValue<PaginatedResult<Comment>>.loading();
    state = await AsyncValue.guard<PaginatedResult<Comment>>(
      () => ref.read(postRepositoryProvider).getComments(
            postId: postId,
            params: PageParams(size: _pageSize),
          ),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final next = await ref.read(postRepositoryProvider).getComments(
          postId: postId,
          params: PageParams(page: current.page + 1, size: _pageSize),
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

  Future<void> addComment(String content) async {
    final added = await ref.read(postRepositoryProvider).addComment(
          postId: postId,
          content: content,
        );
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      PaginatedResult(
        content: [added, ...current.content],
        page: current.page,
        size: current.size,
        totalElements: current.totalElements + 1,
        totalPages: current.totalPages,
        last: current.last,
      ),
    );
  }
}
