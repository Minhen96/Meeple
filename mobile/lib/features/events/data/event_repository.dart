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

  Future<PaginatedResult<Event>> getEvents({
    PageParams params = const PageParams(),
    bool myEventsOnly = false,
    bool pastOnly = false,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.events,
        queryParameters: {
          ...params.toQueryParams(),
          if (myEventsOnly) 'mine': true,
          if (pastOnly) 'past': true,
        },
      );
      return PaginatedResult.fromJson(
        response.data!,
        (item) => Event.fromJson(item as Map<String, dynamic>),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

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

  Future<Event> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    DateTime? endTime,
    required String location,
    String? locationDetails,
    int? maxAttendees,
    List<String>? gameIds,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.events,
        data: {
          'title': title,
          'description': description,
          'startTime': startTime.toIso8601String(),
          if (endTime != null) 'endTime': endTime.toIso8601String(),
          'location': location,
          if (locationDetails != null) 'locationDetails': locationDetails,
          if (maxAttendees != null) 'maxAttendees': maxAttendees,
          if (gameIds != null) 'gameIds': gameIds,
        },
      );
      return Event.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> rsvp(String eventId) async {
    try {
      await _dio.post<void>('${ApiConstants.events}/$eventId/attend');
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> cancelRsvp(String eventId) async {
    try {
      await _dio.delete<void>('${ApiConstants.events}/$eventId/attend');
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
