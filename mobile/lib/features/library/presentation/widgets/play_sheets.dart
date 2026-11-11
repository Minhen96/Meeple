import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/library_widgets.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';

/// Log a play (web `/log-play` page as a sheet): the selected game, date,
/// duration, players and notes.
Future<void> showLogPlaySheet(BuildContext context, WidgetRef ref, Game game) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      backgroundColor: AppColors.background,
      builder: (_) => _LogPlaySheet(game: game),
    );

class _LogPlaySheet extends ConsumerStatefulWidget {
  const _LogPlaySheet({required this.game});

  final Game game;

  @override
  ConsumerState<_LogPlaySheet> createState() => _LogPlaySheetState();
}

class _LogPlaySheetState extends ConsumerState<_LogPlaySheet> {
  DateTime _playedAt = DateTime.now();
  final _players = TextEditingController();
  final _duration = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _players.dispose();
    _duration.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _playedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    setState(() => _playedAt = date);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      await ref.read(collectionNotifierProvider.notifier).logPlay(
            widget.game,
            playedAt: _playedAt,
            playerCount: int.tryParse(_players.text.trim()),
            durationMinutes: int.tryParse(_duration.text.trim()),
            notes: _notes.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(
        context,
        l10n.logPlaySuccess(widget.game.name),
        type: ToastType.success,
      );
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text.toUpperCase(), style: AppTypography.overline),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = widget.game;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.logPlayTitle,
              style: AppTypography.headlineMedium.copyWith(letterSpacing: 0),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: SafeNetworkImage(
                        url: game.coverUrl,
                        fallback: const ColoredBox(
                          color: AppColors.surfaceContainerHigh,
                          child: GameCoverFallback(iconSize: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.name,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (game.yearPublished != null)
                          Text(
                            '${game.yearPublished}',
                            style: AppTypography.bodySmall,
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              l10n.logPlaySelected,
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _label(l10n.playDate),
            Material(
              color: AppColors.inputFill,
              borderRadius: AppSpacing.borderRadiusFull,
              child: InkWell(
                key: const Key('log-play-date'),
                borderRadius: AppSpacing.borderRadiusFull,
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppDateUtils.formatDate(_playedAt),
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(l10n.logPlayDuration),
                      TextField(
                        key: const Key('log-play-duration'),
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        style: AppTypography.bodyMedium,
                        decoration: appFieldDecoration(
                          radius: AppSpacing.radiusFull,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(l10n.logPlayPlayers),
                      TextField(
                        key: const Key('log-play-players'),
                        controller: _players,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        style: AppTypography.bodyMedium,
                        decoration: appFieldDecoration(
                          radius: AppSpacing.radiusFull,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(l10n.collectionNotes),
            TextField(
              key: const Key('log-play-notes'),
              controller: _notes,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              style: AppTypography.bodyMedium,
              decoration: appFieldDecoration(
                hint: l10n.logPlayNotesPlaceholder,
                radius: AppSpacing.radiusXxl,
              ).copyWith(counterText: ''),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: const Key('log-play-save'),
              label: l10n.logPlaySubmit,
              icon: Icons.sports_esports_rounded,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
