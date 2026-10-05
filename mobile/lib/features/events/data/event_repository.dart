import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'event_repository.g.dart';

@riverpod
EventRepository eventRepository(EventRepositoryRef ref) =>
    EventRepository(ref.read(dioProvider));

final class EventRepository {
  const EventRepository(this._dio);

  final Dio _dio;

  /// Upcoming events visible to the caller (`GET /events?limit=`) or the
  /// caller's accepted events (`GET /events/me`). Neither endpoint is paged,
  /// so the result is a single complete page.
  Future<PaginatedResult<Event>> getEvents({
    int limit = 50,
    bool myEventsOnly = false,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        myEventsOnly ? ApiConstants.myEvents : ApiConstants.events,
        queryParameters: myEventsOnly ? null : {'limit': limit},
      );
      return PaginatedResult.single(
        response.data!
            .map((e) => Event.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Throws [NotFoundException] for events the caller may not see.
  Future<Event> getEvent(String eventId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiConstants.events}/$eventId',
      );
      return Event.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// `POST /events` (`CreateEventRequest`).
  ///
  /// [visibility] is `INVITE_ONLY` (default), `FRIENDS` or `PUBLIC`. The
  /// backend has a single location field, so [locationDetails] is appended
  /// to it.
  Future<Event> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required String location,
    String? locationDetails,
    int? maxAttendees,
    String? gameId,
    String visibility = 'INVITE_ONLY',
  }) async {
    final fullLocation = locationDetails == null || locationDetails.isEmpty
        ? location
        : '$location, $locationDetails';
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.events,
        data: {
          'title': title,
          if (description.isNotEmpty) 'description': description,
          'scheduledAt': startTime.toUtc().toIso8601String(),
          if (fullLocation.isNotEmpty) 'location': fullLocation,
          if (maxAttendees != null) 'maxParticipants': maxAttendees,
          if (gameId != null) 'gameId': gameId,
          'visibility': visibility,
        },
      );
      return Event.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// `POST /events/{id}/rsvp?status=ACCEPTED`.
  Future<Event> rsvp(String eventId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiConstants.events}/$eventId/rsvp',
        queryParameters: {'status': 'ACCEPTED'},
      );
      return Event.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// `DELETE /events/{id}/rsvp` — leave the event.
  Future<void> cancelRsvp(String eventId) async {
    try {
      await _dio.delete<void>('${ApiConstants.events}/$eventId/rsvp');
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
