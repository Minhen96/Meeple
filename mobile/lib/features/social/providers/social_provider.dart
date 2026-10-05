import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/features/social/data/social_repository.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'social_provider.g.dart';

/// Friendship with one user and the "Add Friend → Pending → Friends" actions
/// (CLAUDE.md social rules).
@riverpod
class FriendStatusNotifier extends _$FriendStatusNotifier {
  @override
  Future<FriendStatus> build(String userId) =>
      ref.read(socialRepositoryProvider).getFriendStatus(userId);

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  Future<void> sendRequest() async {
    ensureOnline(ref);
    final request = await _repo.sendFriendRequest(userId);
    state = AsyncValue.data(
      FriendStatus(FriendshipStatus.pendingSent, requestId: request.id),
    );
  }

  /// Withdraws the pending request. When it is already gone (accepted or
  /// declined meanwhile) the real status is fetched again instead of failing.
  Future<void> cancelRequest() async {
    ensureOnline(ref);
    try {
      await _repo.cancelFriendRequest(userId);
    } on NotFoundException {
      state = AsyncValue.data(await _repo.getFriendStatus(userId));
      ref.invalidate(sentRequestsProvider);
      return;
    }
    state = const AsyncValue.data(FriendStatus(FriendshipStatus.none));
    ref.invalidate(sentRequestsProvider);
  }

  Future<void> accept() async {
    final requestId = state.valueOrNull?.requestId;
    if (requestId == null) return;
    ensureOnline(ref);
    await _repo.acceptRequest(requestId);
    state = AsyncValue.data(
      FriendStatus(FriendshipStatus.friends, requestId: requestId),
    );
    _refreshLists();
  }

  Future<void> decline() async {
    final requestId = state.valueOrNull?.requestId;
    if (requestId == null) return;
    ensureOnline(ref);
    await _repo.declineRequest(requestId);
    state = const AsyncValue.data(FriendStatus(FriendshipStatus.none));
    _refreshLists();
  }

  Future<void> unfriend() async {
    ensureOnline(ref);
    await _repo.unfriend(userId);
    state = const AsyncValue.data(FriendStatus(FriendshipStatus.none));
    _refreshLists();
  }

  /// Block silently removes the friendship and hides the user's content.
  Future<void> block() async {
    ensureOnline(ref);
    await _repo.block(userId);
    state = const AsyncValue.data(FriendStatus(FriendshipStatus.blocked));
    _refreshLists();
  }

  Future<void> unblock() async {
    ensureOnline(ref);
    await _repo.unblock(userId);
    state = const AsyncValue.data(FriendStatus(FriendshipStatus.none));
    ref.invalidate(blockedUsersProvider);
  }

  void _refreshLists() {
    ref
      ..invalidate(friendsListProvider)
      ..invalidate(receivedRequestsProvider)
      ..invalidate(sentRequestsProvider);
  }
}

@riverpod
class FriendsList extends _$FriendsList {
  @override
  Future<PagedState<UserSummary>> build() async => PagedState.fromPage(
        await ref.read(socialRepositoryProvider).getFriends(),
      );

  Future<void> loadMore() => loadNextPage<UserSummary>(
        current: state.valueOrNull,
        read: () => state.valueOrNull,
        emit: (s) => state = AsyncValue.data(s),
        fetch: (cursor) =>
            ref.read(socialRepositoryProvider).getFriends(cursor: cursor),
      );

  Future<void> unfriend(String userId) async {
    ensureOnline(ref);
    await ref.read(socialRepositoryProvider).unfriend(userId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.removeWhere((u) => u.id == userId));
    }
  }
}

/// Requests other users sent to the viewer.
@riverpod
class ReceivedRequests extends _$ReceivedRequests {
  @override
  Future<List<FriendRequest>> build() async =>
      (await ref.read(socialRepositoryProvider).getReceivedRequests()).items;

  Future<void> accept(FriendRequest request) async {
    ensureOnline(ref);
    await ref.read(socialRepositoryProvider).acceptRequest(request.id);
    _drop(request.id);
    ref
      ..invalidate(friendsListProvider)
      ..invalidate(friendStatusNotifierProvider(request.sender.id));
  }

  Future<void> decline(FriendRequest request) async {
    ensureOnline(ref);
    await ref.read(socialRepositoryProvider).declineRequest(request.id);
    _drop(request.id);
    ref.invalidate(friendStatusNotifierProvider(request.sender.id));
  }

  void _drop(String id) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.where((r) => r.id != id).toList());
    }
  }
}

/// Requests the viewer sent (still pending).
@riverpod
class SentRequests extends _$SentRequests {
  @override
  Future<List<FriendRequest>> build() async =>
      (await ref.read(socialRepositoryProvider).getSentRequests()).items;

  Future<void> cancel(FriendRequest request) async {
    ensureOnline(ref);
    try {
      await ref
          .read(socialRepositoryProvider)
          .cancelFriendRequest(request.receiver.id);
    } on NotFoundException {
      // Already accepted or declined: drop it from the pending list anyway.
    }
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.where((r) => r.id != request.id).toList());
    }
    ref.invalidate(friendStatusNotifierProvider(request.receiver.id));
  }
}

@riverpod
Future<List<UserSummary>> blockedUsers(Ref ref) =>
    ref.read(socialRepositoryProvider).getBlocked();

@riverpod
Future<List<UserSummary>> userSearch(Ref ref, String query) =>
    query.trim().isEmpty
        ? ref.read(socialRepositoryProvider).getSuggestions()
        : ref.read(socialRepositoryProvider).searchUsers(query.trim());

/// Reporting users, posts and comments (`POST /reports`).
@riverpod
ReportActions reportActions(Ref ref) => ReportActions(ref);

final class ReportActions {
  ReportActions(this._ref);

  final Ref _ref;

  Future<void> report({
    required String targetType,
    required String targetId,
    required ReportReason reason,
  }) {
    ensureOnline(_ref);
    return _ref.read(socialRepositoryProvider).report(
          targetType: targetType,
          targetId: targetId,
          reason: reason.name,
        );
  }
}
