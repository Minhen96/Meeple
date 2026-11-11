import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_picker.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/library_widgets.dart';
import 'package:meeple_hearth/features/matching/domain/match_model.dart';
import 'package:meeple_hearth/features/matching/providers/matching_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

enum _MatchTab { suggestions, requests }

/// Matching (web `/match`): "Match" header with + New Request, the inline
/// request form, Suggestions / My Requests segmented tabs.
class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  _MatchTab _tab = _MatchTab.suggestions;
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final requests = ref.watch(myMatchRequestsProvider);
    final suggestions = ref.watch(matchSuggestionsProvider);
    final count = suggestions.valueOrNull?.length ?? 0;
    final loading = requests.isLoading || suggestions.isLoading;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.matchTitle,
        showBackButton: true,
        actions: [
          TextButton.icon(
            key: const Key('match-new'),
            onPressed: () => setState(() => _showForm = !_showForm),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
            icon: Icon(
              _showForm ? Icons.close_rounded : Icons.add_rounded,
              size: 18,
            ),
            label: Text(
              _showForm ? l10n.commonCancel : l10n.matchNew,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(myMatchRequestsProvider)
            ..invalidate(matchSuggestionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (_showForm)
              _RequestForm(
                onCreated: () => setState(() {
                  _showForm = false;
                  _tab = _MatchTab.requests;
                }),
              ),
            _Tabs(
              selected: _tab,
              labels: {
                _MatchTab.suggestions: count > 0
                    ? l10n.matchTabSuggestionsCount(count)
                    : l10n.matchTabSuggestions,
                _MatchTab.requests: l10n.matchTabRequests,
              },
              onSelect: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 20),
            if (loading)
              const SkeletonShimmer(
                child: Column(
                  children: [
                    SkeletonBox(
                        height: 144, borderRadius: AppSpacing.borderRadiusLg),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(
                        height: 144, borderRadius: AppSpacing.borderRadiusLg),
                  ],
                ),
              )
            else if (_tab == _MatchTab.suggestions)
              ...suggestions.when(
                loading: () => const [],
                error: (e, _) => [_ErrorText(error: e)],
                data: (groups) => groups.isEmpty
                    ? [
                        _MatchEmpty(
                          icon: Icons.groups_rounded,
                          title: l10n.matchEmptySuggestionsTitle,
                          body: l10n.matchEmptySuggestionsBody,
                        ),
                      ]
                    : [
                        for (final g in groups)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: MatchGroupCard(group: g),
                          ),
                      ],
              )
            else
              ...requests.when(
                loading: () => const [],
                error: (e, _) => [_ErrorText(error: e)],
                data: (list) => list.isEmpty
                    ? [
                        _MatchEmpty(
                          icon: Icons.sports_esports_outlined,
                          title: l10n.matchEmptyRequestsTitle,
                          body: l10n.matchEmptyRequestsBody,
                        ),
                      ]
                    : [for (final r in list) _RequestRow(request: r)],
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Text(
          localizedError(context.l10n, error),
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
}

/// Full-width `bg-surface-container-low p-1` segmented tabs; the active
/// one is filled primary.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  final _MatchTab selected;
  final Map<_MatchTab, String> labels;
  final ValueChanged<_MatchTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          for (final MapEntry(key: tab, value: label) in labels.entries)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: tab == _MatchTab.suggestions ? 0 : AppSpacing.xs,
                ),
                child: Semantics(
                  selected: tab == selected,
                  button: true,
                  child: Material(
                    color: tab == selected
                        ? AppColors.primary
                        : AppColors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.panel),
                    child: InkWell(
                      key: ValueKey('match-tab-${tab.name}'),
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                      onTap: () => onSelect(tab),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tab == selected
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
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

/// Phone empty state: plain icon, semibold title, body (`py-16`).
class _MatchEmpty extends StatelessWidget {
  const _MatchEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final muted = AppTypography.bodyMedium.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 64,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(body, textAlign: TextAlign.center, style: muted),
        ],
      ),
    );
  }
}

/// `w-10 h-10` game thumbnail (falls back to the casino icon).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.game, this.size = 40});

  final Game game;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: SizedBox(
          width: size,
          height: size,
          child: SafeNetworkImage(
            url: game.coverUrl,
            fallback: ColoredBox(
              color: AppColors.surfaceContainerHigh,
              child: GameCoverFallback(iconSize: size * 0.5),
            ),
          ),
        ),
      );
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request});

  final MatchRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final from = request.availableFrom;
    final to = request.availableTo;
    final when = from == null
        ? l10n.matchAnyTime
        : to == null
            ? AppDateUtils.formatDayMonth(from)
            : '${AppDateUtils.formatDayMonth(from)} – '
                '${AppDateUtils.formatDayMonth(to)}';
    return Container(
      key: ValueKey('match-request-${request.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          _Thumb(game: request.game),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(when, style: AppTypography.bodySmall),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('match-cancel-${request.id}'),
            tooltip: l10n.matchCancelRequest,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.onSurfaceVariant,
            ),
            onPressed: () async {
              try {
                await ref
                    .read(myMatchRequestsProvider.notifier)
                    .cancel(request.id);
              } catch (e) {
                if (context.mounted) showErrorToast(context, e);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// The inline "Looking to play…" form: game, time window, submit.
class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
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
      showToast(context, l10n.matchRequestCreated, type: ToastType.success);
      widget.onCreated();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required Key key,
    required String text,
    required bool placeholder,
    required VoidCallback onTap,
    Widget? leading,
    Widget? trailing,
  }) =>
      Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              leading == null ? AppSpacing.md : AppSpacing.sm,
              AppSpacing.sm + 2,
              trailing == null ? AppSpacing.md : AppSpacing.xs,
              AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: AppSpacing.sm)
                ],
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: placeholder
                          ? AppColors.onSurfaceVariant.withValues(alpha: 0.6)
                          : AppColors.onSurface,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = _game;
    final label = AppTypography.bodySmall;
    return Container(
      key: const Key('match-form'),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.matchLookingToPlay,
            style:
                AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            key: const Key('match-pick-game'),
            text: game?.name ?? l10n.matchSearchGame,
            placeholder: game == null,
            leading: game == null ? null : _Thumb(game: game, size: 28),
            trailing: game == null
                ? null
                : InkResponse(
                    onTap: () => setState(() => _game = null),
                    child: Tooltip(
                      message: l10n.eventRemoveGame,
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
            onTap: () async {
              final g = await showGamePicker(context);
              if (g == null || !mounted) return;
              setState(() => _game = g);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final (i, (text, value)) in [
                (l10n.matchAvailableFrom, _from),
                (l10n.matchUntil, _to),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(text, style: label),
                      ),
                      _field(
                        key: Key(i == 0 ? 'match-from' : 'match-to'),
                        text: value == null
                            ? '—'
                            : '${AppDateUtils.formatDayMonth(value)}, '
                                '${AppDateUtils.formatTime(value)}',
                        placeholder: value == null,
                        onTap: () async {
                          final v = await _pickDateTime(
                            i == 0 ? _from : (_to ?? _from),
                          );
                          if (v == null || !mounted) return;
                          setState(() => i == 0 ? _from = v : _to = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Opacity(
            opacity: game == null || _saving ? 0.5 : 1,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: InkWell(
                key: const Key('match-submit'),
                borderRadius: BorderRadius.circular(AppRadius.tile),
                onTap: _saving ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _saving ? l10n.matchSubmitting : l10n.matchSubmitRequest,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
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

/// A match suggestion (web `MatchSuggestionCard`): "Match Found!", the
/// game and time window, the members, Create Event / Dismiss.
class MatchGroupCard extends ConsumerStatefulWidget {
  const MatchGroupCard({super.key, required this.group});

  final MatchGroup group;

  @override
  ConsumerState<MatchGroupCard> createState() => _MatchGroupCardState();
}

class _MatchGroupCardState extends ConsumerState<MatchGroupCard> {
  bool _busy = false;

  Future<void> _dismiss() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(matchSuggestionsProvider.notifier)
          .dismiss(widget.group.id);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _window(AppLocalizations l10n) {
    final g = widget.group;
    final start = g.overlapStart;
    if (start == null) return l10n.matchAnyTime;
    final date = AppDateUtils.formatDayMonth(start);
    final from = AppDateUtils.formatTime(start);
    final end = g.overlapEnd;
    return end == null
        ? '$date · $from'
        : '$date · $from – ${AppDateUtils.formatTime(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final g = widget.group;
    final names = g.members.map((m) => displayNameOf(context, m)).join(', ');
    return Container(
      key: ValueKey('match-group-${g.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primaryContainer.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.matchFound.toUpperCase(),
                style:
                    AppTypography.overline.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Thumb(game: g.game, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(_window(l10n),
                              style: AppTypography.bodySmall),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final m in g.members)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppAvatar(
                    imageUrl: m.avatarUrl,
                    displayName: displayNameOf(context, m),
                    size: 24,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  names,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  key: ValueKey('match-create-${g.id}'),
                  label: l10n.matchCreateEvent,
                  primary: true,
                  onTap: _busy
                      ? null
                      : () =>
                          context.push(AppRoutes.createEventFromMatch(g.id)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CardButton(
                key: ValueKey('match-dismiss-${g.id}'),
                label: l10n.matchDismiss,
                onTap: _busy ? null : _dismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Material(
          color: primary ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 10,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: primary
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
}
