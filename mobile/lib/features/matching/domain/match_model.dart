import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';

part 'match_model.freezed.dart';
part 'match_model.g.dart';

/// `MatchRequestResponse`.
@freezed
class MatchRequest with _$MatchRequest {
  const factory MatchRequest({
    required String id,
    required Game game,
    DateTime? availableFrom,
    DateTime? availableTo,
    @Default('ACTIVE') String status,
    DateTime? createdAt,
  }) = _MatchRequest;

  factory MatchRequest.fromJson(Map<String, dynamic> json) =>
      _$MatchRequestFromJson(json);
}

/// `MatchGroupResponse` — a match suggestion.
@freezed
class MatchGroup with _$MatchGroup {
  const factory MatchGroup({
    required String id,
    required Game game,
    DateTime? overlapStart,
    DateTime? overlapEnd,
    @Default('PENDING') String status,
    @Default(<UserSummary>[]) List<UserSummary> members,
    DateTime? createdAt,
  }) = _MatchGroup;

  factory MatchGroup.fromJson(Map<String, dynamic> json) =>
      _$MatchGroupFromJson(json);
}
