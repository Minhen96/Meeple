import 'package:meeple_hearth/features/events/data/event_repository.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_provider.g.dart';

/// Upcoming public events (default tab).
@riverpod
class EventsNotifier extends _$EventsNotifier {
  static const _pageSize = 20;

  @override
  Future<PaginatedResult<Event>> build() => ref
      .read(eventRepositoryProvider)
      .getEvents(params: PageParams(size: _pageSize));

  Future<void> refresh() async {
    state = const AsyncValue<PaginatedResult<Event>>.loading();
    state = await AsyncValue.guard<PaginatedResult<Event>>(
      () => ref
          .read(eventRepositoryProvider)
          .getEvents(params: PageParams(size: _pageSize)),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final next = await ref.read(eventRepositoryProvider).getEvents(
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
}

/// Events the current user is attending or has organised (My Events tab).
@riverpod
class MyEventsNotifier extends _$MyEventsNotifier {
  static const _pageSize = 20;

  @override
  Future<PaginatedResult<Event>> build() => ref
      .read(eventRepositoryProvider)
      .getEvents(params: PageParams(size: _pageSize), myEventsOnly: true);

  Future<void> refresh() async {
    state = const AsyncValue<PaginatedResult<Event>>.loading();
    state = await AsyncValue.guard<PaginatedResult<Event>>(
      () => ref.read(eventRepositoryProvider).getEvents(
            params: PageParams(size: _pageSize),
            myEventsOnly: true,
          ),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final next = await ref.read(eventRepositoryProvider).getEvents(
          params: PageParams(page: current.page + 1, size: _pageSize),
          myEventsOnly: true,
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

/// Single event detail.
@riverpod
Future<Event> eventDetail(EventDetailRef ref, String eventId) =>
    ref.read(eventRepositoryProvider).getEvent(eventId);
