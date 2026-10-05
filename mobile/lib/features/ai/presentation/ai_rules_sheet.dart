import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/features/ai/providers/ai_chat_provider.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// Opens the AI Rules Assistant bottom sheet (SCREENS §12): draggable, up to
/// 80% of the screen.
Future<void> showAiRulesSheet(BuildContext context, Game game) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.glassBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        builder: (_, controller) =>
            AiRulesPanel(game: game, scrollController: controller),
      ),
    );

/// The chat panel inside the sheet (also usable on its own in tests).
class AiRulesPanel extends ConsumerStatefulWidget {
  const AiRulesPanel({super.key, required this.game, this.scrollController});

  final Game game;
  final ScrollController? scrollController;

  @override
  ConsumerState<AiRulesPanel> createState() => _AiRulesPanelState();
}

class _AiRulesPanelState extends ConsumerState<AiRulesPanel> {
  final _input = TextEditingController();
  bool _askWithoutRulebook = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    _input.clear();
    await ref.read(aiChatProvider(widget.game.id).notifier).ask(q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final messages = ref.watch(aiChatProvider(widget.game.id));
    final busy = messages.any((m) => m.isPending);
    final noRulebook = !widget.game.hasRulebook && !_askWithoutRulebook;
    return Column(
      children: [
        AppSpacing.vGapSm,
        Container(
          width: 40,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.outlineVariant,
            borderRadius: AppSpacing.borderRadiusFull,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.xs,
            0,
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: AppColors.tertiary),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  l10n.aiSheetTitle(widget.game.name),
                  style: AppTypography.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            l10n.aiDisclaimer,
            style: AppTypography.bodySmall,
          ),
        ),
        Expanded(
          child: noRulebook
              ? _NoRulebook(
                  gameName: widget.game.name,
                  onAskAnyway: () => setState(() => _askWithoutRulebook = true),
                )
              : messages.isEmpty
                  ? _QuickPrompts(onPick: (q) {
                      _input.text = q;
                      _input.selection =
                          TextSelection.collapsed(offset: q.length);
                    })
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _Exchange(
                        message: messages[i],
                        onRetry: () => ref
                            .read(aiChatProvider(widget.game.id).notifier)
                            .retry(i),
                      ),
                    ),
        ),
        if (!noRulebook)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai-input'),
                      controller: _input,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: busy ? null : (_) => _send(),
                      decoration: InputDecoration(
                        hintText: l10n.aiInputHint,
                        counterText: '',
                      ),
                    ),
                  ),
                  AppSpacing.hGapSm,
                  IconButton.filled(
                    key: const Key('ai-send'),
                    tooltip: l10n.commonSend,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.tertiary,
                    ),
                    onPressed: busy ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NoRulebook extends StatelessWidget {
  const _NoRulebook({required this.gameName, required this.onAskAnyway});

  final String gameName;
  final VoidCallback onAskAnyway;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: AppColors.onSurfaceVariant,
            ),
            AppSpacing.vGapMd,
            Text(
              l10n.aiNoRulebook(gameName),
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium,
            ),
            AppSpacing.vGapSm,
            Text(
              l10n.aiNoRulebookBody,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            AppSpacing.vGapLg,
            FilledButton.tonal(
              key: const Key('ai-ask-anyway'),
              onPressed: onAskAnyway,
              child: Text(l10n.aiAskAnyway),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prompts = [l10n.aiPromptWin, l10n.aiPromptSetup, l10n.aiPromptTurn];
    return Center(
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.center,
        children: [
          for (final p in prompts)
            ActionChip(
              label: Text(p),
              side: BorderSide.none,
              shape: const StadiumBorder(),
              backgroundColor: AppColors.tertiaryContainer.withValues(alpha: 0.3),
              onPressed: () => onPick(p),
            ),
        ],
      ),
    );
  }
}

class _Exchange extends StatelessWidget {
  const _Exchange({required this.message, required this.onRetry});

  final AiMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = message.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bubble(
          text: message.question,
          mine: true,
        ),
        AppSpacing.vGapSm,
        if (message.isPending)
          const _Bubble(text: '…', mine: false)
        else if (error != null)
          _Bubble(
            text: error is RateLimitException
                ? l10n.aiRateLimit
                : l10n.aiError,
            mine: false,
            isError: true,
            onRetry: error is RateLimitException ? null : onRetry,
          )
        else
          _Bubble(text: message.answer!, mine: false),
        AppSpacing.vGapLg,
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    this.isError = false,
    this.onRetry,
  });

  final String text;
  final bool mine;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bg = mine
        ? AppColors.primary
        : isError
            ? AppColors.errorContainer
            : AppColors.surfaceContainerLow;
    final fg = mine
        ? AppColors.onPrimary
        : isError
            ? AppColors.onErrorContainer
            : AppColors.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppSpacing.borderRadiusXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                text,
                style: AppTypography.bodyMedium.copyWith(color: fg),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text(context.l10n.commonRetry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
