import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/ai/domain/ai_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_repository.g.dart';

@riverpod
AiRepository aiRepository(Ref ref) => AiRepository(ref.read(dioProvider));

final class AiRepository {
  const AiRepository(this._dio);

  final Dio _dio;

  /// Max pairs sent as `conversationHistory` (backend `@Size(max = 3)`).
  static const maxHistory = 3;

  /// `POST /ai/rules {gameId, question, conversationHistory}`.
  ///
  /// Throws [RateLimitException] once the daily question limit is reached.
  Future<AiAnswer> askRules({
    required String gameId,
    required String question,
    List<ConversationTurn> history = const [],
  }) =>
      guardApi(() async {
        final recent = history.length > maxHistory
            ? history.sublist(history.length - maxHistory)
            : history;
        final res = await _dio.post<Map<String, dynamic>>(
          ApiConstants.aiRules,
          data: {
            'gameId': gameId,
            'question': question,
            'conversationHistory': recent.map((t) => t.toJson()).toList(),
          },
        );
        return AiAnswer.fromJson(res.data!);
      });
}
