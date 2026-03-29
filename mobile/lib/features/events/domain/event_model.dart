import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_model.freezed.dart';
part 'event_model.g.dart';

@freezed
class Event with _$Event {
  const factory Event({
    required String id,
    required String organizerId,
    required String organizerUsername,
    required String organizerDisplayName,
    String? organizerAvatarUrl,
    required String title,
    required String description,
    required DateTime startTime,
    DateTime? endTime,
    required String location,
    String? locationDetails,
    double? latitude,
    double? longitude,
    int? maxAttendees,
    @Default(0) int attendeeCount,
    @Default(false) bool isAttending,
    @Default([]) List<String> gameIds,
    @Default([]) List<String> gameNames,
    required DateTime createdAt,
  }) = _Event;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}
