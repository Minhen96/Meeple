import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/features/ai/data/ai_repository.dart';
import 'package:meeple_hearth/features/ai/domain/ai_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_chat_provider.g.dart';

/// One exchange in the chat transcript.
final class AiMessage {
  const AiMessage({
    required this.question,
    this.answer,
    this.disclaimer,
    this.error,
  });

  final String question;
  final String? answer;
  final String? disclaimer;

  /// Set when this question failed (rate limit, AI error).
  final Object? error;

  bool get isPending => answer == null && error == null;
}

/// AI Rules Assistant conversation for one game (SCREENS §12).
///
/// Conversation mode (CLAUDE.md): the client keeps the transcript and sends
/// the last 3 answered Q&A pairs with every question.
@riverpod
class AiChat extends _$AiChat {
  @override
  List<AiMessage> build(String gameId) => const [];

  bool get isBusy => state.any((m) => m.isPending);

  /// The last [AiRepository.maxHistory] answered pairs.
  List<ConversationTurn> get history {
    final answered = [
      for (final m in state)
        if (m.answer != null)
          ConversationTurn(question: m.question, answer: m.answer!),
    ];
    return answered.length > AiRepository.maxHistory
        ? answered.sublist(answered.length - AiRepository.maxHistory)
        : answered;
  }

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || isBusy) return;
    final turns = history;
    final index = state.length;
    state = [...state, AiMessage(question: q)];
    try {
      ensureOnline(ref);
      final answer = await ref
          .read(aiRepositoryProvider)
          .askRules(gameId: gameId, question: q, history: turns);
      _replace(
        index,
        AiMessage(
          question: q,
          answer: answer.answer,
          disclaimer: answer.disclaimer,
        ),
      );
    } on ApiException catch (e) {
      _replace(index, AiMessage(question: q, error: e));
    }
  }

  /// Retries a failed question.
  Future<void> retry(int index) async {
    if (index < 0 || index >= state.length) return;
    final question = state[index].question;
    state = [...state]..removeAt(index);
    await ask(question);
  }

  void clear() => state = const [];

  void _replace(int index, AiMessage message) {
    if (index >= state.length) return;
    state = [...state]..[index] = message;
  }
}
