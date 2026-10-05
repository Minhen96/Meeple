import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_card.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_picker.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/matching/providers/matching_provider.dart';
import 'package:meeple_hearth/features/social/presentation/friend_picker.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Create or edit an event (SCREENS §6.5): game, title, date & time,
/// location, max players, visibility, invited friends, description.
/// `?matchGroupId=` pre-fills game, time and invitees from a match.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({
    super.key,
    this.matchGroupId,
    this.gameId,
    this.editEventId,
  });

  final String? matchGroupId;
  final String? gameId;
  final String? editEventId;

  bool get isEdit => editEventId != null;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  Game? _game;
  DateTime? _date;
  TimeOfDay? _time;
  int _maxPlayers = 8;
  EventVisibility _visibility = EventVisibility.inviteOnly;
  List<UserSummary> _invited = [];
  bool _titleEdited = false;
  bool _saving = false;
  bool _prefilled = false;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      if (widget.isEdit) {
        final e = await ref.read(eventDetailProvider(widget.editEventId!).future);
        if (!mounted) return;
        final local = e.scheduledAt.toLocal();
        setState(() {
          _game = e.game;
          _title.text = e.title;
          _titleEdited = true;
          _location.text = e.location ?? '';
          _description.text = e.description ?? '';
          _date = DateUtils.dateOnly(local);
          _time = TimeOfDay.fromDateTime(local);
          if (e.maxParticipants > 0) _maxPlayers = e.maxParticipants;
          _visibility = e.visibilityValue;
        });
      } else if (widget.matchGroupId != null) {
        final groups = await ref.read(matchSuggestionsProvider.future);
        final me = ref.read(authNotifierProvider).valueOrNull;
        final group = groups.where((g) => g.id == widget.matchGroupId).firstOrNull;
        if (!mounted || group == null) return;
        final start = group.overlapStart?.toLocal();
        setState(() {
          _setGame(group.game);
          _invited = group.members.where((m) => m.id != me?.id).toList();
          if (start != null && start.isAfter(DateTime.now())) {
            _date = DateUtils.dateOnly(start);
            _time = TimeOfDay.fromDateTime(start);
          }
        });
      } else if (widget.gameId != null) {
        final game = await ref.read(gameDetailProvider(widget.gameId!).future);
        if (mounted) setState(() => _setGame(game.data));
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _prefilled = true);
    }
  }

  void _setGame(Game? game) {
    _game = game;
    if (!_titleEdited) {
      _title.text = game == null ? '' : context.l10n.eventDefaultTitle(game.name);
    }
  }

  DateTime? get _scheduledAt {
    final d = _date;
    final t = _time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked == null) return;
    // 30-minute increments (SCREENS §6.5).
    final minute = picked.minute < 15
        ? 0
        : picked.minute < 45
            ? 30
            : 0;
    final hour = picked.minute >= 45 ? (picked.hour + 1) % 24 : picked.hour;
    setState(() => _time = TimeOfDay(hour: hour, minute: minute));
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final at = _scheduledAt;
    setState(() {
      _dateError = at == null
          ? l10n.eventDateRequired
          : at.isBefore(DateTime.now())
              ? l10n.eventDateInPast
              : null;
    });
    if (!_form.currentState!.validate() || _dateError != null) return;
    final draft = EventDraft(
      title: _title.text.trim(),
      description: _description.text.trim(),
      location: _location.text.trim(),
      scheduledAt: at!,
      gameId: _game?.id,
      maxParticipants: _maxPlayers,
      visibility: _visibility,
      invitedUserIds: [for (final u in _invited) u.id],
    );
    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await ref
            .read(eventDetailProvider(widget.editEventId!).notifier)
            .save(draft);
        if (!mounted) return;
        showToast(context, l10n.eventUpdated, type: ToastType.success);
        context.pop();
      } else {
        final event = await ref.read(eventActionsProvider).create(draft);
        if (!mounted) return;
        showToast(
          context,
          _invited.isEmpty ? l10n.eventCreated : l10n.eventCreatedInvites,
          type: ToastType.success,
        );
        context.pushReplacement(AppRoutes.eventDetail(event.id));
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = _scheduledAt;
    return Scaffold(
      appBar: MeepleAppBar(
        title: widget.isEdit ? l10n.eventEdit : l10n.createEvent,
        showBackButton: true,
        fallbackRoute: AppRoutes.events,
      ),
      body: !_prefilled && (widget.isEdit || widget.matchGroupId != null)
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _Label(l10n.eventFieldGame),
                  if (_game == null)
                    OutlinedButton.icon(
                      key: const Key('event-pick-game'),
                      onPressed: () async {
                        final g = await showGamePicker(context);
                        if (g != null) setState(() => _setGame(g));
                      },
                      icon: const Icon(Icons.search_rounded),
                      label: Text(l10n.eventPickGame),
                    )
                  else
                    Material(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.borderRadiusLg,
                      child: GameListTile(
                        game: _game!,
                        trailing: IconButton(
                          tooltip: l10n.eventRemoveGame,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _setGame(null)),
                        ),
                      ),
                    ),
                  AppSpacing.vGapLg,
                  TextFormField(
                    key: const Key('event-title'),
                    controller: _title,
                    maxLength: 100,
                    onChanged: (_) => _titleEdited = true,
                    decoration: InputDecoration(labelText: l10n.eventFieldTitle),
                    validator: (v) => (v ?? '').trim().length < 3
                        ? l10n.eventTitleTooShort
                        : null,
                  ),
                  AppSpacing.vGapSm,
                  _Label(l10n.eventFieldDateTime),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('event-date'),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            _date == null
                                ? l10n.eventPickDate
                                : AppDateUtils.formatDate(_date!),
                          ),
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('event-time'),
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(
                            _time == null
                                ? l10n.eventPickTime
                                : _time!.format(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (at != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        AppDateUtils.formatDateTime(at),
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  if (_dateError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        _dateError!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  AppSpacing.vGapLg,
                  TextFormField(
                    key: const Key('event-location'),
                    controller: _location,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: l10n.eventFieldLocation,
                      hintText: l10n.eventLocationHint,
                    ),
                  ),
                  _Label(l10n.eventFieldMaxPlayers),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: l10n.playFewerPlayers,
                        onPressed: _maxPlayers <= 2
                            ? null
                            : () => setState(() => _maxPlayers--),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '$_maxPlayers',
                          key: const Key('event-max-players'),
                          textAlign: TextAlign.center,
                          style: AppTypography.titleLarge,
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: l10n.playMorePlayers,
                        onPressed: _maxPlayers >= 50
                            ? null
                            : () => setState(() => _maxPlayers++),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  AppSpacing.vGapLg,
                  _Label(l10n.eventFieldVisibility),
                  SegmentedButton<EventVisibility>(
                    key: const Key('event-visibility'),
                    segments: [
                      ButtonSegment(
                        value: EventVisibility.inviteOnly,
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: Text(l10n.visibilityInviteOnly),
                      ),
                      ButtonSegment(
                        value: EventVisibility.friends,
                        icon: const Icon(Icons.group_outlined),
                        label: Text(l10n.visibilityFriends),
                      ),
                      ButtonSegment(
                        value: EventVisibility.public,
                        icon: const Icon(Icons.public_rounded),
                        label: Text(l10n.visibilityPublic),
                      ),
                    ],
                    selected: {_visibility},
                    onSelectionChanged: (s) =>
                        setState(() => _visibility = s.first),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      switch (_visibility) {
                        EventVisibility.inviteOnly =>
                          l10n.visibilityInviteOnlyHint,
                        EventVisibility.friends => l10n.visibilityFriendsHint,
                        EventVisibility.public => l10n.visibilityPublicHint,
                      },
                      style: AppTypography.bodySmall,
                    ),
                  ),
                  AppSpacing.vGapLg,
                  _Label(l10n.eventInviteFriends),
                  if (_invited.isNotEmpty)
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final u in _invited)
                          InputChip(
                            avatar: AppAvatar(
                              imageUrl: u.avatarUrl,
                              displayName: u.displayName,
                              size: AvatarSize.xs,
                            ),
                            label: Text(u.displayName),
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            onDeleted: () =>
                                setState(() => _invited.remove(u)),
                          ),
                      ],
                    ),
                  TextButton.icon(
                    key: const Key('event-invite'),
                    onPressed: () async {
                      final picked = await showFriendPicker(
                        context,
                        title: l10n.eventInviteFriends,
                        initial: _invited,
                      );
                      if (picked != null) setState(() => _invited = picked);
                    },
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: Text(l10n.eventChooseFriends),
                  ),
                  AppSpacing.vGapSm,
                  TextFormField(
                    key: const Key('event-description'),
                    controller: _description,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.eventFieldDescription,
                    ),
                  ),
                  AppSpacing.vGapXxl,
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(
            key: const Key('event-submit'),
            label: widget.isEdit ? l10n.commonSave : l10n.createEvent,
            isLoading: _saving,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTypography.titleSmall),
      );
}
