import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_model.freezed.dart';
part 'ai_model.g.dart';

/// One question/answer pair of `AiQueryRequest.conversationHistory`
/// (`{question, answer}`, at most 3 sent — CLAUDE.md AI feature).
@freezed
class ConversationTurn with _$ConversationTurn {
  const factory ConversationTurn({
    required String question,
    required String answer,
  }) = _ConversationTurn;

  factory ConversationTurn.fromJson(Map<String, dynamic> json) =>
      _$ConversationTurnFromJson(json);
}

/// `AiAnswerResponse`.
@freezed
class AiAnswer with _$AiAnswer {
  const factory AiAnswer({
    required String answer,

    /// `rulebook` | `general`.
    String? sourceMode,
    String? disclaimer,
    @Default(false) bool cached,
  }) = _AiAnswer;

  factory AiAnswer.fromJson(Map<String, dynamic> json) =>
      _$AiAnswerFromJson(json);
}
