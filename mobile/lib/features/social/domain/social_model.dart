import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'social_model.freezed.dart';
part 'social_model.g.dart';

/// `FriendRequestResponse`.
@freezed
class FriendRequest with _$FriendRequest {
  const factory FriendRequest({
    required String id,
    required UserSummary sender,
    required UserSummary receiver,
    @Default('PENDING') String status,
    DateTime? createdAt,
  }) = _FriendRequest;

  factory FriendRequest.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestFromJson(json);
}

/// `GET /users/{id}/friend-status` → `{status, requestId}`.
final class FriendStatus {
  const FriendStatus(this.status, {this.requestId});

  factory FriendStatus.fromJson(Map<String, dynamic> json) => FriendStatus(
        FriendshipStatus.parse(json['status']),
        requestId: json['requestId'] as String?,
      );

  final FriendshipStatus status;
  final String? requestId;
}

/// Report reasons offered in the report sheet (`POST /reports`).
enum ReportReason { spam, harassment, inappropriate, other }

/// `GET /users/{id}/stats` (GAP §6.1 [WP4]).
@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int gamesOwned,
    @Default(0) int sessions,
    @Default(0) int friends,
    MostPlayedGame? mostPlayedGame,
    String? favoriteCategory,
    MostPlayedWith? mostPlayedWith,
    @Default(0) int totalPlayMinutes,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}

@freezed
class MostPlayedGame with _$MostPlayedGame {
  const factory MostPlayedGame({
    required String gameId,
    @Default('') String title,
    @Default(0) int playCount,
  }) = _MostPlayedGame;

  factory MostPlayedGame.fromJson(Map<String, dynamic> json) =>
      _$MostPlayedGameFromJson(json);
}

@freezed
class MostPlayedWith with _$MostPlayedWith {
  const factory MostPlayedWith({
    required String userId,
    @Default('') String displayName,
    @Default(0) int sharedSessions,
  }) = _MostPlayedWith;

  factory MostPlayedWith.fromJson(Map<String, dynamic> json) =>
      _$MostPlayedWithFromJson(json);
}
