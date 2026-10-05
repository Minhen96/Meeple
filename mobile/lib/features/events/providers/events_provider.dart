import 'package:meeple_hearth/features/events/data/event_repository.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_provider.g.dart';

/// Upcoming events visible to the caller (default tab).
///
/// `GET /events` is not paginated: it returns up to [_limit] events, soonest
/// first, so [loadMore] is a no-op kept for the list widgets.
@riverpod
class EventsNotifier extends _$EventsNotifier {
  static const _limit = 50;

  @override
  Future<PaginatedResult<Event>> build() =>
      ref.read(eventRepositoryProvider).getEvents(limit: _limit);

  Future<void> refresh() async {
    state = const AsyncValue<PaginatedResult<Event>>.loading();
    state = await AsyncValue.guard<PaginatedResult<Event>>(
      () => ref.read(eventRepositoryProvider).getEvents(limit: _limit),
    );
  }

  Future<void> loadMore() async {}
}

/// Events the current user has accepted (My Events tab).
@riverpod
class MyEventsNotifier extends _$MyEventsNotifier {
  @override
  Future<PaginatedResult<Event>> build() =>
      ref.read(eventRepositoryProvider).getEvents(myEventsOnly: true);

  Future<void> refresh() async {
    state = const AsyncValue<PaginatedResult<Event>>.loading();
    state = await AsyncValue.guard<PaginatedResult<Event>>(
      () => ref.read(eventRepositoryProvider).getEvents(myEventsOnly: true),
    );
  }

  Future<void> loadMore() async {}
}

/// Single event detail. Events the caller may not see return 404.
@riverpod
Future<Event> eventDetail(EventDetailRef ref, String eventId) =>
    ref.read(eventRepositoryProvider).getEvent(eventId);
