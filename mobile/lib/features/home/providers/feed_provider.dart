import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/home/data/feed_repository.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/shared/models/cursor_page.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_provider.g.dart';

/// Home feed: cursor pages of posts and friend activity, newest first.
///
/// The first page is cached (last 50 items, 1 h — MOBILE_FLUTTER §6) and
/// shown with a stale banner while offline.
@Riverpod(keepAlive: true)
class FeedNotifier extends _$FeedNotifier {
  static const _cachedItems = 50;

  @override
  Future<PagedState<FeedItem>> build() {
    // Another account signed in (or out): start over with its feed.
    ref.watch(authUserIdProvider);
    listenToPostChanges(ref, (change) {
      switch (change) {
        case PostUpdated(:final post):
          replacePost(post);
        case PostDeleted(:final postId):
          removePost(postId);
        case PostCreated(:final post):
          prependPost(post);
      }
    });
    return _firstPage();
  }

  Future<PagedState<FeedItem>> _firstPage() async {
    final result = await readThrough<CursorPage<FeedItem>>(
      cache: ref.read(cacheStoreProvider),
      key: CacheKeys.feed,
      maxAge: CacheTtl.feed,
      fetch: () => ref.read(feedRepositoryProvider).getFeed(),
      encode: (page) => CursorPage(
        items: page.items.take(_cachedItems).toList(),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ).toJson((i) => i.toJson()),
      decode: (json) =>
          CursorPage.fromJson(json, FeedRepository.parseFeedItem),
    );
    return PagedState.fromPage(result.data, cachedAt: result.cachedAt);
  }

  /// Pull-to-refresh: keeps the current list visible until the new page
  /// arrives.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_firstPage);
  }

  Future<void> loadMore() => loadNextPage<FeedItem>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) =>
            ref.read(feedRepositoryProvider).getFeed(cursor: cursor),
      );

  /// Applies an edited/liked/bookmarked post everywhere it appears.
  void replacePost(Post post) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.mapItems(
        (i) => i is FeedPostItem && i.post.id == post.id,
        (i) => FeedItem.post(createdAt: (i as FeedPostItem).createdAt, post: post),
      ),
    );
  }

  void removePost(String postId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.removeWhere((i) => i is FeedPostItem && i.post.id == postId),
    );
  }

  /// A newly created post goes to the top immediately.
  void prependPost(Post post) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(items: [FeedItem.fromPost(post), ...current.items]),
    );
  }
}
