import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/library/data/collection_repository.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';

ShapeBorder get _sheetShape => const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXxl),
      ),
    );

/// Log a play: date, players, duration and notes (GAP §6.1 plays).
Future<void> showLogPlaySheet(BuildContext context, WidgetRef ref, Game game) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: _sheetShape,
      backgroundColor: AppColors.surfaceContainerLowest,
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
  int? _players;
  final _duration = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
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
    if (date != null) setState(() => _playedAt = date);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      await ref.read(collectionNotifierProvider.notifier).logPlay(
            widget.game,
            playedAt: _playedAt,
            playerCount: _players,
            durationMinutes: int.tryParse(_duration.text.trim()),
            notes: _notes.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, l10n.playLogged, type: ToastType.success);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.playLogTitle(widget.game.name),
            style: AppTypography.titleLarge,
          ),
          AppSpacing.vGapLg,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l10n.playDate),
            trailing: Text(AppDateUtils.formatDate(_playedAt)),
            onTap: _pickDate,
          ),
          Row(
            children: [
              Expanded(child: Text(l10n.playPlayers)),
              IconButton(
                tooltip: l10n.playFewerPlayers,
                onPressed: (_players ?? 1) <= 1
                    ? null
                    : () => setState(() => _players = (_players ?? 2) - 1),
                icon: const Icon(Icons.remove_rounded),
              ),
              Text('${_players ?? '–'}', style: AppTypography.titleMedium),
              IconButton(
                tooltip: l10n.playMorePlayers,
                onPressed: () => setState(() => _players = (_players ?? 0) + 1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          AppSpacing.vGapSm,
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.playDuration,
              suffixText: l10n.minutesSuffix,
            ),
          ),
          AppSpacing.vGapMd,
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(labelText: l10n.playNotes),
          ),
          AppSpacing.vGapMd,
          AppButton(
            key: const Key('log-play-save'),
            label: l10n.gameLogPlay,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// "In Collection" sheet: rating, notes, play history, remove.
Future<void> showCollectionEntrySheet(
  BuildContext context,
  WidgetRef ref,
  UserGame entry,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: _sheetShape,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) => _EntrySheet(entry: entry),
    );

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({required this.entry});

  final UserGame entry;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late double _rating = widget.entry.personalRating ?? 7;
  late final _notes = TextEditingController(text: widget.entry.notes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(collectionNotifierProvider.notifier).rate(
            widget.entry.game,
            rating: _rating,
            notes: _notes.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final ok = await showConfirmSheet(
      context,
      title: l10n.collectionRemoveTitle,
      message: l10n.collectionRemoveMessage(widget.entry.game.name),
      confirmLabel: l10n.collectionRemove,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(collectionNotifierProvider.notifier)
          .remove(widget.entry.gameId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _deletePlay(PlayLog play) async {
    try {
      await ref.read(collectionRepositoryProvider).deletePlay(play.id);
      ref.invalidate(gamePlaysProvider(widget.entry.gameId));
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plays = ref.watch(gamePlaysProvider(widget.entry.gameId));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.entry.game.name, style: AppTypography.titleLarge),
            Text(
              l10n.gamePlays(widget.entry.playCount),
              style: AppTypography.bodySmall,
            ),
            AppSpacing.vGapLg,
            Text(
              l10n.collectionRating(_rating.toStringAsFixed(1)),
              style: AppTypography.titleSmall,
            ),
            Slider(
              key: const Key('rating-slider'),
              value: _rating,
              min: 1,
              max: 10,
              divisions: 18,
              label: _rating.toStringAsFixed(1),
              onChanged: (v) => setState(() => _rating = v),
            ),
            TextField(
              controller: _notes,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(labelText: l10n.collectionNotes),
            ),
            AppSpacing.vGapSm,
            AppButton(label: l10n.commonSave, isLoading: _saving, onPressed: _save),
            AppSpacing.vGapLg,
            Text(l10n.collectionPlayHistory, style: AppTypography.titleMedium),
            plays.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(l10n.collectionNoPlays, style: AppTypography.bodySmall),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(
                        l10n.collectionNoPlays,
                        style: AppTypography.bodySmall,
                      ),
                    )
                  : Column(
                      children: [
                        for (final p in list)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.casino_outlined),
                            title: Text(AppDateUtils.formatDate(p.playedAt)),
                            subtitle: p.notes == null || p.notes!.isEmpty
                                ? null
                                : Text(p.notes!),
                            trailing: IconButton(
                              tooltip: l10n.commonDelete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deletePlay(p),
                            ),
                          ),
                      ],
                    ),
            ),
            AppSpacing.vGapMd,
            TextButton.icon(
              key: const Key('collection-remove'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: _remove,
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(l10n.collectionRemove),
            ),
          ],
        ),
      ),
    );
  }
}
