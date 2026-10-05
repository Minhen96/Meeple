import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/features/posts/data/post_repository.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_provider.g.dart';

/// A change to a post, broadcast so every list showing it stays in sync.
sealed class PostChange {
  const PostChange();
}

final class PostUpdated extends PostChange {
  const PostUpdated(this.post);
  final Post post;
}

final class PostDeleted extends PostChange {
  const PostDeleted(this.postId);
  final String postId;
}

final class PostCreated extends PostChange {
  const PostCreated(this.post);
  final Post post;
}

@Riverpod(keepAlive: true)
Raw<StreamController<PostChange>> postChanges(Ref ref) {
  final controller = StreamController<PostChange>.broadcast();
  ref.onDispose(controller.close);
  return controller;
}

/// Subscribes a list notifier to [postChanges] for its lifetime.
void listenToPostChanges(Ref ref, void Function(PostChange change) onChange) {
  final sub = ref.read(postChangesProvider).stream.listen(onChange);
  ref.onDispose(sub.cancel);
}

/// Applies a [PostChange] to a paged list of posts.
PagedState<Post> applyPostChange(PagedState<Post> state, PostChange change) =>
    switch (change) {
      PostUpdated(:final post) =>
        state.mapItems((p) => p.id == post.id, (_) => post),
      PostDeleted(:final postId) => state.removeWhere((p) => p.id == postId),
      PostCreated() => state,
    };

/// Likes, bookmarks, edits and deletes with optimistic updates
/// (MOBILE_FLUTTER §4) and the offline write guard (§11).
@riverpod
PostActions postActions(Ref ref) => PostActions(ref);

final class PostActions {
  PostActions(this._ref);

  final Ref _ref;

  PostRepository get _repo => _ref.read(postRepositoryProvider);

  void _emit(PostChange change) {
    // Owned (and closed) by postChangesProvider.
    // ignore: close_sinks
    final controller = _ref.read(postChangesProvider);
    if (!controller.isClosed) controller.add(change);
  }

  Future<void> toggleLike(Post post) async {
    ensureOnline(_ref);
    final liked = !post.likedByMe;
    _emit(
      PostUpdated(
        post.copyWith(
          likedByMe: liked,
          likeCount: (post.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31),
        ),
      ),
    );
    try {
      liked ? await _repo.likePost(post.id) : await _repo.unlikePost(post.id);
    } catch (_) {
      _emit(PostUpdated(post));
      rethrow;
    }
  }

  Future<void> toggleBookmark(Post post) async {
    ensureOnline(_ref);
    final saved = !post.isBookmarked;
    _emit(PostUpdated(post.copyWith(isBookmarked: saved)));
    try {
      saved
          ? await _repo.bookmarkPost(post.id)
          : await _repo.unbookmarkPost(post.id);
    } catch (_) {
      _emit(PostUpdated(post));
      rethrow;
    }
  }

  Future<Post> create(PostDraft draft) async {
    ensureOnline(_ref);
    final post = await _repo.createPost(draft);
    _emit(PostCreated(post));
    return post;
  }

  Future<Post> update(String postId, PostDraft draft) async {
    ensureOnline(_ref);
    final post = await _repo.updatePost(postId, draft);
    _emit(PostUpdated(post));
    return post;
  }

  Future<void> delete(String postId) async {
    ensureOnline(_ref);
    await _repo.deletePost(postId);
    _emit(PostDeleted(postId));
  }
}

/// A single post; follows [postChanges].
@riverpod
class PostDetail extends _$PostDetail {
  @override
  Future<Post> build(String postId) {
    listenToPostChanges(ref, (change) {
      if (change is PostUpdated && change.post.id == postId) {
        state = AsyncValue.data(change.post);
      }
    });
    return ref.read(postRepositoryProvider).getPost(postId);
  }

  /// Keeps the comment counter in step with local comment changes.
  void adjustCommentCount(int delta) {
    final post = state.valueOrNull;
    if (post == null) return;
    state = AsyncValue.data(
      post.copyWith(commentCount: (post.commentCount + delta).clamp(0, 1 << 31)),
    );
  }
}

/// Comments of a post (paged).
@riverpod
class CommentsNotifier extends _$CommentsNotifier {
  @override
  Future<PagedState<Comment>> build(String postId) async =>
      PagedState.fromPage(
        await ref.read(postRepositoryProvider).getComments(postId),
      );

  Future<void> loadMore() => loadNextPage<Comment>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) =>
            ref.read(postRepositoryProvider).getComments(postId, cursor: cursor),
      );

  Future<void> add(String body) async {
    ensureOnline(ref);
    final comment = await ref.read(postRepositoryProvider).addComment(postId, body);
    final current = state.valueOrNull ?? const PagedState<Comment>();
    state = AsyncValue.data(current.copyWith(items: [...current.items, comment]));
    ref.read(postDetailProvider(postId).notifier).adjustCommentCount(1);
  }

  Future<void> edit(String commentId, String body) async {
    ensureOnline(ref);
    final updated = await ref
        .read(postRepositoryProvider)
        .updateComment(postId, commentId, body);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.mapItems((c) => c.id == commentId, (_) => updated),
    );
  }

  Future<void> delete(String commentId) async {
    ensureOnline(ref);
    await ref.read(postRepositoryProvider).deleteComment(postId, commentId);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.removeWhere((c) => c.id == commentId));
    ref.read(postDetailProvider(postId).notifier).adjustCommentCount(-1);
  }
}

/// Paged posts of a user (profile Posts tab).
@riverpod
class UserPosts extends _$UserPosts {
  @override
  Future<PagedState<Post>> build(String userId) async {
    listenToPostChanges(ref, (change) {
      final current = state.valueOrNull;
      if (current == null) return;
      if (change is PostCreated && change.post.author.id == userId) {
        state = AsyncValue.data(
          current.copyWith(items: [change.post, ...current.items]),
        );
      } else {
        state = AsyncValue.data(applyPostChange(current, change));
      }
    });
    return PagedState.fromPage(
      await ref.read(postRepositoryProvider).getUserPosts(userId),
    );
  }

  Future<void> loadMore() => loadNextPage<Post>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) => ref
            .read(postRepositoryProvider)
            .getUserPosts(userId, cursor: cursor),
      );
}

/// Paged posts a user is tagged in (profile Tagged tab).
@riverpod
class TaggedPosts extends _$TaggedPosts {
  @override
  Future<PagedState<Post>> build(String userId) async {
    listenToPostChanges(ref, (change) {
      final current = state.valueOrNull;
      if (current != null) state = AsyncValue.data(applyPostChange(current, change));
    });
    return PagedState.fromPage(
      await ref.read(postRepositoryProvider).getTaggedPosts(userId),
    );
  }

  Future<void> loadMore() => loadNextPage<Post>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) => ref
            .read(postRepositoryProvider)
            .getTaggedPosts(userId, cursor: cursor),
      );
}

/// The viewer's saved posts.
@riverpod
class Bookmarks extends _$Bookmarks {
  @override
  Future<PagedState<Post>> build() async {
    listenToPostChanges(ref, (change) {
      final current = state.valueOrNull;
      if (current == null) return;
      if (change is PostUpdated && !change.post.isBookmarked) {
        state = AsyncValue.data(
          current.removeWhere((p) => p.id == change.post.id),
        );
      } else {
        state = AsyncValue.data(applyPostChange(current, change));
      }
    });
    return PagedState.fromPage(
      await ref.read(postRepositoryProvider).getBookmarks(),
    );
  }

  Future<void> loadMore() => loadNextPage<Post>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) =>
            ref.read(postRepositoryProvider).getBookmarks(cursor: cursor),
      );
}

/// Posts tagged to an event ("View Memories").
@riverpod
Future<List<Post>> eventPosts(Ref ref, String eventId) async =>
    (await ref.read(postRepositoryProvider).getEventPosts(eventId)).items;
