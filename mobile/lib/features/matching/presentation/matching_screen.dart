import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/home_widgets.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_card.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_picker.dart';
import 'package:meeple_hearth/features/matching/providers/matching_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Matching (SCREENS §10): request form, active requests and suggestions.
class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  Game? _game;
  DateTime? _from;
  DateTime? _to;
  bool _saving = false;

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final game = _game;
    if (game == null) {
      showToast(context, l10n.matchPickGameFirst, type: ToastType.error);
      return;
    }
    if (_from != null && _to != null && !_to!.isAfter(_from!)) {
      showToast(context, l10n.matchInvalidRange, type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(myMatchRequestsProvider.notifier).create(
            gameId: game.id,
            availableFrom: _from,
            availableTo: _to,
          );
      if (!mounted) return;
      setState(() {
        _game = null;
        _from = null;
        _to = null;
      });
      showToast(context, l10n.matchRequestCreated, type: ToastType.success);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final requests = ref.watch(myMatchRequestsProvider);
    final suggestions = ref.watch(matchSuggestionsProvider);
    return Scaffold(
      appBar: MeepleAppBar(title: l10n.matchingTitle, showBackButton: true),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(myMatchRequestsProvider)
            ..invalidate(matchSuggestionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            Container(
              margin: const EdgeInsets.all(AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppSpacing.borderRadiusXl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.matchFormTitle, style: AppTypography.titleLarge),
                  Text(l10n.matchFormBody, style: AppTypography.bodySmall),
                  AppSpacing.vGapMd,
                  if (_game == null)
                    OutlinedButton.icon(
                      key: const Key('match-pick-game'),
                      onPressed: () async {
                        final g = await showGamePicker(context);
                        if (g != null) setState(() => _game = g);
                      },
                      icon: const Icon(Icons.search_rounded),
                      label: Text(l10n.eventPickGame),
                    )
                  else
                    GameListTile(
                      game: _game!,
                      trailing: IconButton(
                        tooltip: l10n.eventRemoveGame,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _game = null),
                      ),
                    ),
                  AppSpacing.vGapSm,
                  OutlinedButton.icon(
                    key: const Key('match-from'),
                    onPressed: () async {
                      final v = await _pickDateTime(_from);
                      if (v != null) setState(() => _from = v);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      _from == null
                          ? l10n.matchAvailableFrom
                          : l10n.matchFromValue(AppDateUtils.formatDateTime(_from!)),
                    ),
                  ),
                  AppSpacing.vGapSm,
                  OutlinedButton.icon(
                    key: const Key('match-to'),
                    onPressed: () async {
                      final v = await _pickDateTime(_to ?? _from);
                      if (v != null) setState(() => _to = v);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      _to == null
                          ? l10n.matchAvailableUntil
                          : l10n.matchUntilValue(AppDateUtils.formatDateTime(_to!)),
                    ),
                  ),
                  AppSpacing.vGapMd,
                  AppButton(
                    key: const Key('match-submit'),
                    label: l10n.matchSubmit,
                    isLoading: _saving,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            SectionHeader(title: l10n.matchActiveRequests),
            ...requests.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(localizedError(l10n, e)),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Text(
                          l10n.matchNoRequests,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    ]
                  : [
                      for (final r in list)
                        GameListTile(
                          key: ValueKey('match-request-${r.id}'),
                          game: r.game,
                          subtitle: r.availableFrom == null
                              ? null
                              : l10n.matchAvailableRange(
                                  AppDateUtils.formatDateTime(r.availableFrom!),
                                  r.availableTo == null
                                      ? '…'
                                      : AppDateUtils.formatDateTime(r.availableTo!),
                                ),
                          trailing: TextButton(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(myMatchRequestsProvider.notifier)
                                    .cancel(r.id);
                              } catch (e) {
                                if (context.mounted) showErrorToast(context, e);
                              }
                            },
                            child: Text(l10n.commonCancel),
                          ),
                        ),
                    ],
            ),
            SectionHeader(title: l10n.homeMatchesTitle),
            ...suggestions.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(localizedError(l10n, e)),
                ),
              ],
              data: (groups) => groups.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Text(
                          l10n.matchNoSuggestions,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    ]
                  : [
                      for (final g in groups)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          child: MatchSuggestionCard(group: g),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
