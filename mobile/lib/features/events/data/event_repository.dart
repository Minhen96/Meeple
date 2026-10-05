import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'event_repository.g.dart';

@riverpod
EventRepository eventRepository(Ref ref) =>
    EventRepository(ref.read(dioProvider));

final class EventRepository {
  const EventRepository(this._dio);

  final Dio _dio;

  static const _events = ApiConstants.events;

  /// Max calendar range accepted by `GET /events/calendar` (62 days).
  static const maxCalendarRange = Duration(days: 62);

  Event _event(Response<Object?> res) =>
      Event.fromJson(res.data! as Map<String, dynamic>);

  static List<Event> _parseEvents(Object? data) => (data as List<dynamic>? ??
          const [])
      .whereType<Map<String, dynamic>>()
      .map(Event.fromJson)
      .toList();

  /// `GET /events?scope=upcoming|past|mine&limit=`.
  ///
  /// Backends without `scope` ignore it and return upcoming events; `mine`
  /// then falls back to `GET /events/me` and `past` is filtered client-side.
  Future<List<Event>> getEvents(EventScope scope, {int limit = 50}) =>
      guardApi(() async {
        final res = await _dio.get<Object?>(
          _events,
          queryParameters: {'scope': scope.wire, 'limit': limit},
        );
        var events = _parseEvents(res.data);
        if (scope == EventScope.past) {
          final now = DateTime.now();
          events = events.where((e) => e.scheduledAt.isBefore(now)).toList()
            ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
        }
        return events;
      });

  /// Events the user hosts or joined (`scope=mine`, legacy `/events/me`).
  Future<List<Event>> getMyEvents() => guardApiOr(
        () async {
          final res = await _dio.get<Object?>(
            _events,
            queryParameters: {'scope': EventScope.mine.wire, 'limit': 100},
          );
          final events = _parseEvents(res.data);
          // A scope-unaware backend answers with all upcoming events; only
          // keep the ones the user is part of.
          return events
              .where((e) => e.isHost || e.myRsvp == 'ACCEPTED' || e.isInvited)
              .toList();
        },
        () async => _parseEvents((await _dio.get<Object?>(ApiConstants.myEvents)).data),
      );

  /// `GET /events/calendar?from=&to=` (≤ 62 days). Falls back to the
  /// upcoming list filtered to the range while the endpoint is missing.
  Future<List<Event>> getCalendar(DateTime from, DateTime to) => guardApiOr(
        () async {
          final res = await _dio.get<Object?>(
            '$_events/calendar',
            queryParameters: {
              'from': from.toUtc().toIso8601String(),
              'to': to.toUtc().toIso8601String(),
            },
          );
          return _parseEvents(res.data);
        },
        () async {
          final res = await _dio.get<Object?>(
            _events,
            queryParameters: {'limit': 100},
          );
          return _parseEvents(res.data)
              .where(
                (e) =>
                    !e.scheduledAt.isBefore(from) && e.scheduledAt.isBefore(to),
              )
              .toList();
        },
      );

  /// `GET /events/community?gameId=` — public events, optionally for a game.
  Future<List<Event>> getCommunityEvents({String? gameId}) => guardApiOr(
        () async {
          final res = await _dio.get<Object?>(
            '$_events/community',
            queryParameters: {if (gameId != null) 'gameId': gameId},
          );
          final data = res.data;
          return _parseEvents(data is Map ? data['items'] : data);
        },
        () async => const <Event>[],
      );

  /// Throws [NotFoundException] for events the caller may not see.
  Future<Event> getEvent(String eventId) =>
      guardApi(() async => _event(await _dio.get<Object?>('$_events/$eventId')));

  /// `POST /events` incl. `invitedUserIds`.
  Future<Event> createEvent(EventDraft draft) => guardApi(
        () async =>
            _event(await _dio.post<Object?>(_events, data: draft.toRequest())),
      );

  /// `PUT /events/{id}` (host only). Invites go through [invite].
  Future<Event> updateEvent(String eventId, EventDraft draft) => guardApi(
        () async => _event(
          await _dio.put<Object?>(
            '$_events/$eventId',
            data: draft.toRequest(includeInvites: false),
          ),
        ),
      );

  /// `POST /events/{id}/cancel` (host only).
  Future<void> cancelEvent(String eventId) =>
      guardApi(() => _dio.post<void>('$_events/$eventId/cancel'));

  /// `POST /events/{id}/invites {userIds}`.
  Future<void> invite(String eventId, List<String> userIds) => guardApi(
        () => _dio.post<void>(
          '$_events/$eventId/invites',
          data: {'userIds': userIds},
        ),
      );

  /// `DELETE /events/{id}/participants/{userId}` — host kicks a participant.
  Future<void> kick(String eventId, String userId) => guardApi(
        () => _dio.delete<void>('$_events/$eventId/participants/$userId'),
      );

  /// `POST /events/{id}/rsvp` with `ACCEPTED` | `DECLINED`.
  Future<Event> rsvp(String eventId, String status) => guardApi(
        () async => _event(
          await _dio.post<Object?>(
            '$_events/$eventId/rsvp',
            queryParameters: {'status': status},
            data: {'status': status},
          ),
        ),
      );

  /// `DELETE /events/{id}/rsvp` — leave (status becomes `LEFT`).
  Future<void> leave(String eventId) =>
      guardApi(() => _dio.delete<void>('$_events/$eventId/rsvp'));
}
