import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/features/events/data/event_repository.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_provider.g.dart';

/// Events of a list tab. Upcoming events are cached for 30 min.
@riverpod
Future<CachedResult<List<Event>>> eventsList(Ref ref, EventScope scope) {
  final repo = ref.read(eventRepositoryProvider);
  Future<List<Event>> fetch() =>
      scope == EventScope.mine ? repo.getMyEvents() : repo.getEvents(scope);
  if (scope != EventScope.upcoming) {
    return fetch().then(CachedResult.new);
  }
  return readThrough<List<Event>>(
    cache: ref.read(cacheStoreProvider),
    key: CacheKeys.upcomingEvents,
    maxAge: CacheTtl.events,
    fetch: fetch,
    encode: (events) => events.map((e) => e.toJson()).toList(),
    decode: (json) => (json as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Event.fromJson)
        .toList(),
  );
}

/// Events of one calendar month (first day of [month] → first day of the
/// next month, within the 62-day API limit).
@riverpod
Future<List<Event>> calendarEvents(Ref ref, DateTime month) {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1);
  return ref.read(eventRepositoryProvider).getCalendar(from, to);
}

/// Refreshes every event list after a change.
void _invalidateLists(Ref ref) {
  ref
    ..invalidate(eventsListProvider)
    ..invalidate(calendarEventsProvider);
}

/// Event detail with RSVP and host actions.
@riverpod
class EventDetail extends _$EventDetail {
  @override
  Future<Event> build(String eventId) =>
      ref.read(eventRepositoryProvider).getEvent(eventId);

  EventRepository get _repo => ref.read(eventRepositoryProvider);

  Future<void> _reload() async {
    state = AsyncValue.data(await _repo.getEvent(eventId));
    _invalidateLists(ref);
  }

  /// `ACCEPTED` (join / accept invite) or `DECLINED`.
  Future<void> rsvp(String status) async {
    ensureOnline(ref);
    final event = await _repo.rsvp(eventId, status);
    state = AsyncValue.data(event);
    _invalidateLists(ref);
  }

  Future<void> leave() async {
    ensureOnline(ref);
    await _repo.leave(eventId);
    await _reload();
  }

  Future<void> cancel() async {
    ensureOnline(ref);
    await _repo.cancelEvent(eventId);
    await _reload();
  }

  Future<void> kick(String userId) async {
    ensureOnline(ref);
    await _repo.kick(eventId, userId);
    await _reload();
  }

  Future<void> invite(List<String> userIds) async {
    if (userIds.isEmpty) return;
    ensureOnline(ref);
    await _repo.invite(eventId, userIds);
    await _reload();
  }

  Future<void> save(EventDraft draft) async {
    ensureOnline(ref);
    state = AsyncValue.data(await _repo.updateEvent(eventId, draft));
    if (draft.invitedUserIds.isNotEmpty) {
      await _repo.invite(eventId, draft.invitedUserIds);
      state = AsyncValue.data(await _repo.getEvent(eventId));
    }
    _invalidateLists(ref);
  }
}

/// Creating events (with invites in the same request).
@riverpod
EventActions eventActions(Ref ref) => EventActions(ref);

final class EventActions {
  EventActions(this._ref);

  final Ref _ref;

  Future<Event> create(EventDraft draft) async {
    ensureOnline(_ref);
    final event = await _ref.read(eventRepositoryProvider).createEvent(draft);
    _invalidateLists(_ref);
    return event;
  }
}
