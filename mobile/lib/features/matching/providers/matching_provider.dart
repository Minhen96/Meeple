import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/features/matching/data/match_repository.dart';
import 'package:meeple_hearth/features/matching/domain/match_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matching_provider.g.dart';

/// Pending match suggestions (home card + matching screen).
@riverpod
class MatchSuggestions extends _$MatchSuggestions {
  @override
  Future<List<MatchGroup>> build() =>
      ref.read(matchRepositoryProvider).getSuggestions();

  /// Accepting creates an event from the group.
  Future<Event> accept(String groupId) async {
    ensureOnline(ref);
    final event = await ref.read(matchRepositoryProvider).accept(groupId);
    _drop(groupId);
    ref.invalidate(eventsListProvider);
    return event;
  }

  Future<void> dismiss(String groupId) async {
    ensureOnline(ref);
    final before = state.valueOrNull;
    _drop(groupId);
    try {
      await ref.read(matchRepositoryProvider).dismiss(groupId);
    } catch (_) {
      if (before != null) state = AsyncValue.data(before);
      rethrow;
    }
  }

  void _drop(String groupId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.where((g) => g.id != groupId).toList());
  }
}

/// The viewer's active match requests.
@riverpod
class MyMatchRequests extends _$MyMatchRequests {
  @override
  Future<List<MatchRequest>> build() =>
      ref.read(matchRepositoryProvider).getMyRequests();

  Future<void> create({
    required String gameId,
    DateTime? availableFrom,
    DateTime? availableTo,
  }) async {
    ensureOnline(ref);
    final request = await ref.read(matchRepositoryProvider).createRequest(
          gameId: gameId,
          availableFrom: availableFrom,
          availableTo: availableTo,
        );
    state = AsyncValue.data([request, ...?state.valueOrNull]);
  }

  Future<void> cancel(String requestId) async {
    ensureOnline(ref);
    await ref.read(matchRepositoryProvider).cancelRequest(requestId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.where((r) => r.id != requestId).toList());
    }
  }
}
