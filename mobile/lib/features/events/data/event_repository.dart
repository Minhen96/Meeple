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

  /// `GET /events?scope=upcoming|past|mine&limit=` (limit ≤ 100). `past`
  /// is newest first; `mine` is the events the viewer hosts or joined.
  Future<List<Event>> getEvents(EventScope scope, {int limit = 50}) =>
      guardApi(() async {
        final res = await _dio.get<Object?>(
          _events,
          queryParameters: {'scope': scope.wire, 'limit': limit},
        );
        return _parseEvents(res.data);
      });

  /// `GET /events/calendar?from=&to=` — events in the viewer's circle
  /// starting in `[from, to)`; the range is at most 62 days (400
  /// `INVALID_RANGE`).
  Future<List<Event>> getCalendar(DateTime from, DateTime to) =>
      guardApi(() async {
        final res = await _dio.get<Object?>(
          '$_events/calendar',
          queryParameters: {
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
          },
        );
        return _parseEvents(res.data);
      });

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

  /// `POST /events/{id}/rsvp?status=ACCEPTED|DECLINED` → the event. 409
  /// `EVENT_FULL` / `EVENT_CANCELLED` / `EVENT_COMPLETED`, 403 `NOT_INVITED` /
  /// `KICKED`.
  Future<Event> rsvp(String eventId, String status) => guardApi(
        () async => _event(
          await _dio.post<Object?>(
            '$_events/$eventId/rsvp',
            queryParameters: {'status': status},
          ),
        ),
      );

  /// `DELETE /events/{id}/rsvp` — leave (status becomes `LEFT`); 400
  /// `HOST_CANNOT_LEAVE` for the host.
  Future<void> leave(String eventId) =>
      guardApi(() => _dio.delete<void>('$_events/$eventId/rsvp'));
}
