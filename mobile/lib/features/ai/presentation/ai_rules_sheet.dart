import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/features/ai/providers/ai_chat_provider.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// Opens the AI Rules Assistant (web `AiAssistantDrawer`, full screen on
/// phones) as a tall draggable bottom sheet.
Future<void> showAiRulesSheet(BuildContext context, Game game) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 1,
        maxChildSize: 1,
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
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

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
        _Header(
          gameName: widget.game.name,
          canClear: messages.isNotEmpty,
          onClear: () =>
              ref.read(aiChatProvider(widget.game.id).notifier).clear(),
        ),
        Expanded(
          child: ColoredBox(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.3),
            child: noRulebook
                ? _NoRulebook(
                    gameName: widget.game.name,
                    onAskAnyway: () =>
                        setState(() => _askWithoutRulebook = true),
                  )
                : ListView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _Bubble(
                        text: l10n.aiWelcome(widget.game.name),
                        mine: false,
                        showLabel: false,
                      ),
                      if (messages.isEmpty)
                        _QuickPrompts(
                          onPick: (q) {
                            _input.text = q;
                            _input.selection =
                                TextSelection.collapsed(offset: q.length);
                          },
                        ),
                      for (final (i, m) in messages.indexed)
                        _Exchange(
                          message: m,
                          onRetry: () => ref
                              .read(aiChatProvider(widget.game.id).notifier)
                              .retry(i),
                        ),
                    ],
                  ),
          ),
        ),
        if (!noRulebook)
          ColoredBox(
            color: AppColors.surfaceContainerLowest,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
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
                              style: AppTypography.bodyMedium,
                              decoration: InputDecoration(
                                hintText: l10n.aiPlaceholder,
                                hintStyle: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                                counterText: '',
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _SendButton(
                            enabled: !busy && _input.text.trim().isNotEmpty,
                            onTap: _send,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.aiFooterDisclaimer,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 9,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.gameName,
    required this.canClear,
    required this.onClear,
  });

  final String gameName;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aiTitle,
                    style: AppTypography.titleSmall.copyWith(height: 1.25),
                  ),
                  Text(
                    gameName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (canClear)
              IconButton(
                key: const Key('ai-clear'),
                tooltip: l10n.aiClear,
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: onClear,
              ),
            IconButton(
              tooltip: l10n.commonClose,
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.commonSend,
        child: Opacity(
          opacity: enabled ? 1 : 0.3,
          child: Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            elevation: enabled ? 4 : 0,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
            child: InkWell(
              key: const Key('ai-send'),
              customBorder: const CircleBorder(),
              // _send ignores empty input and busy chats itself.
              onTap: onTap,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ),
      );
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 32,
                color: AppColors.tertiary,
              ),
            ),
            AppSpacing.vGapLg,
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
            Material(
              color: AppColors.tertiaryContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                key: const Key('ai-ask-anyway'),
                customBorder: const StadiumBorder(),
                onTap: onAskAnyway,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    l10n.aiAskAnyway,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final p in prompts)
            Material(
              color: AppColors.tertiary.withValues(alpha: 0.1),
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onPick(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  child: Text(
                    p,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
              ),
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
        _Bubble(text: message.question, mine: true),
        if (message.isPending)
          const _Typing()
        else if (error != null)
          _Bubble(
            text: error is RateLimitException
                ? l10n.aiDailyLimit(20)
                : l10n.aiError,
            mine: false,
            isError: true,
            onRetry: error is RateLimitException ? null : onRetry,
          )
        else
          _Bubble(
            text: message.answer!,
            mine: false,
            sourceMode: message.sourceMode,
            disclaimer: message.disclaimer,
          ),
      ],
    );
  }
}

/// Renders `**bold**` and `*italic*` like the web drawer's inline markdown.
List<InlineSpan> _markdownSpans(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*', dotAll: true);
  var last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(
      m.group(1) != null
          ? TextSpan(
              text: m.group(1),
              style: base.copyWith(fontWeight: FontWeight.w700),
            )
          : TextSpan(
              text: m.group(2),
              style: base.copyWith(fontStyle: FontStyle.italic),
            ),
    );
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    this.isError = false,
    this.onRetry,
    this.sourceMode,
    this.disclaimer,
    this.showLabel = true,
  });

  final String text;
  final bool mine;
  final bool isError;
  final VoidCallback? onRetry;
  final String? sourceMode;
  final String? disclaimer;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
    final base = AppTypography.bodyMedium.copyWith(color: fg, height: 1.625);
    const r = Radius.circular(AppSpacing.radiusLg);
    final rulebook = sourceMode == 'rulebook';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85,
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: mine ? r : Radius.zero,
                    topRight: mine ? Radius.zero : r,
                    bottomLeft: r,
                    bottomRight: r,
                  ),
                  boxShadow: mine
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (text.contains('*'))
                      SelectableText.rich(
                        TextSpan(
                          style: base,
                          children: _markdownSpans(text, base),
                        ),
                      )
                    else
                      SelectableText(text, style: base),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: Text(l10n.commonRetry),
                      ),
                  ],
                ),
              ),
              if (sourceMode != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, AppSpacing.xs, 4, 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: rulebook
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : const Color(0x1AFBBF24),
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          rulebook
                              ? Icons.menu_book_rounded
                              : Icons.psychology_outlined,
                          size: 10,
                          color: rulebook
                              ? AppColors.primary
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (rulebook
                                  ? l10n.aiSourceRulebook
                                  : l10n.aiSourceGeneral)
                              .toUpperCase(),
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: rulebook
                                ? AppColors.primary
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (disclaimer != null && disclaimer!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, AppSpacing.xs, 4, 0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      disclaimer!,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 9,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              if (showLabel || !mine)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, AppSpacing.xs, 4, 0),
                  child: Text(
                    (mine ? l10n.aiYou : l10n.aiAssistant).toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three bouncing-dot placeholder while an answer is pending.
class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const Key('ai-typing'),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(AppSpacing.radiusLg),
                bottomLeft: Radius.circular(AppSpacing.radiusLg),
                bottomRight: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
