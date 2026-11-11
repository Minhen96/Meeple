import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:meeple_hearth/features/library/presentation/widgets/game_picker.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/matching/providers/matching_provider.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Create or edit an event (SCREENS §6.5 / web `EventForm`): game, title,
/// date & time, location; max players and visibility; invited friends;
/// description — in rounded panels with eyebrow labels and filled inputs.
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

  static const minPlayers = 2;
  static const maxPlayers = 50;
  static const descriptionMax = 1000;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  Game? _game;

  // Web default: tomorrow at 19:00.
  DateTime? _date =
      DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
  TimeOfDay? _time = const TimeOfDay(hour: 19, minute: 0);
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
    _description.addListener(() => setState(() {}));
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
        final e =
            await ref.read(eventDetailProvider(widget.editEventId!).future);
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
        final group =
            groups.where((g) => g.id == widget.matchGroupId).firstOrNull;
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
      _title.text =
          game == null ? '' : context.l10n.eventDefaultTitle(game.name);
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
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked == null || !mounted) return;
    // 30-minute increments (SCREENS §6.5).
    final minute = picked.minute < 15
        ? 0
        : picked.minute < 45
            ? 30
            : 0;
    final hour = picked.minute >= 45 ? (picked.hour + 1) % 24 : picked.hour;
    setState(() => _time = TimeOfDay(hour: hour, minute: minute));
  }

  void _setPlayers(int n) => setState(
        () => _maxPlayers = n.clamp(
          CreateEventScreen.minPlayers,
          CreateEventScreen.maxPlayers,
        ),
      );

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
    final subtitle = widget.isEdit
        ? null
        : widget.matchGroupId != null
            ? l10n.eventFormFromMatch
            : l10n.eventFormSubtitle;
    return Scaffold(
      appBar: MeepleAppBar(
        showBackButton: true,
        fallbackRoute: AppRoutes.events,
        titleWidget: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEdit
                    ? l10n.eventFormEditTitle
                    : l10n.eventFormCreateTitle,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle.toUpperCase(),
                  style: AppTypography.overline.copyWith(
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: !_prefilled && (widget.isEdit || widget.matchGroupId != null)
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      128,
                    ),
                    children: [
                      _detailsPanel(l10n),
                      const SizedBox(height: 20),
                      _settingsPanel(l10n),
                      if (!widget.isEdit) ...[
                        const SizedBox(height: 20),
                        _Panel(
                          children: [
                            _Label(l10n.eventInviteFriends),
                            _InviteFriends(
                              selected: _invited,
                              onChanged: (list) =>
                                  setState(() => _invited = list),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      _Panel(
                        children: [
                          _Label(l10n.eventFieldDescriptionLabel),
                          TextFormField(
                            key: const Key('event-description'),
                            controller: _description,
                            maxLength: CreateEventScreen.descriptionMax,
                            minLines: 4,
                            maxLines: 8,
                            style: AppTypography.bodyMedium,
                            decoration: _fieldDecoration(
                              l10n.eventDescriptionHint,
                              radius: AppRadius.panel,
                            ).copyWith(counterText: ''),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                            child: Text(
                              l10n.eventCharCount(
                                _description.text.length,
                                CreateEventScreen.descriptionMax,
                              ),
                              textAlign: TextAlign.right,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: ColoredBox(
                        color: AppColors.surface.withValues(alpha: 0.8),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: AppButton(
                              key: const Key('event-submit'),
                              label: widget.isEdit
                                  ? l10n.eventSaveChanges
                                  : l10n.eventCreateCta,
                              height: 56,
                              isLoading: _saving,
                              onPressed: _submit,
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

  Widget _detailsPanel(AppLocalizations l10n) {
    return _Panel(
      children: [
        _Label(l10n.eventFieldGame),
        if (_game == null)
          _FieldButton(
            key: const Key('event-pick-game'),
            icon: Icons.search_rounded,
            text: l10n.eventPickGame,
            placeholder: true,
            onTap: () async {
              final g = await showGamePicker(context);
              if (g == null || !mounted) return;
              setState(() => _setGame(g));
            },
          )
        else
          _PickedGame(
            game: _game!,
            onClear: () => setState(() => _setGame(null)),
          ),
        const SizedBox(height: 20),
        _Label(l10n.eventFieldTitle),
        TextFormField(
          key: const Key('event-title'),
          controller: _title,
          maxLength: 100,
          onChanged: (_) => _titleEdited = true,
          style: AppTypography.bodyMedium,
          decoration:
              _fieldDecoration(l10n.eventTitleHint).copyWith(counterText: ''),
          validator: (v) =>
              (v ?? '').trim().length < 3 ? l10n.eventTitleTooShort : null,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(l10n.eventFieldDate),
                  _FieldButton(
                    key: const Key('event-date'),
                    icon: Icons.calendar_today_outlined,
                    trailingIcon: true,
                    text: _date == null
                        ? l10n.eventPickDate
                        : AppDateUtils.formatDate(_date!),
                    placeholder: _date == null,
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(l10n.eventFieldTime),
                  _FieldButton(
                    key: const Key('event-time'),
                    icon: Icons.schedule_rounded,
                    trailingIcon: true,
                    text: _time == null
                        ? l10n.eventPickTime
                        : _time!.format(context),
                    placeholder: _time == null,
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_dateError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
            child: Text(
              _dateError!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        const SizedBox(height: 20),
        _Label(l10n.eventFieldLocation),
        TextFormField(
          key: const Key('event-location'),
          controller: _location,
          maxLength: 100,
          style: AppTypography.bodyMedium,
          decoration: _fieldDecoration(l10n.eventLocationHint)
              .copyWith(counterText: ''),
        ),
      ],
    );
  }

  Widget _settingsPanel(AppLocalizations l10n) {
    final options = [
      (
        EventVisibility.public,
        Icons.public_rounded,
        l10n.visibilityPublic,
        l10n.eventVisPublicDesc,
      ),
      (
        EventVisibility.friends,
        Icons.group_outlined,
        l10n.visibilityFriends,
        l10n.eventVisFriendsDesc,
      ),
      (
        EventVisibility.inviteOnly,
        Icons.lock_outline_rounded,
        l10n.visibilityInviteOnly,
        l10n.eventVisInviteOnlyDesc,
      ),
    ];
    return _Panel(
      children: [
        Row(
          children: [
            Expanded(child: _Label(l10n.eventFieldMaxPlayers, bottom: 0)),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: AppSpacing.borderRadiusFull,
              ),
              child: Text(
                l10n.eventPlayersLabel(_maxPlayers),
                key: const Key('event-max-players'),
                style: AppTypography.labelMedium.copyWith(
                  fontFamily: AppTypography.titleSmall.fontFamily,
                  fontWeight: FontWeight.w900,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.vGapSm,
        Row(
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              tooltip: l10n.playFewerPlayers,
              onPressed: _maxPlayers <= CreateEventScreen.minPlayers
                  ? null
                  : () => _setPlayers(_maxPlayers - 1),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.surfaceContainerHighest,
                  thumbColor: AppColors.primary,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 9),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Slider(
                    key: const Key('event-players-slider'),
                    value: _maxPlayers.toDouble(),
                    min: CreateEventScreen.minPlayers.toDouble(),
                    max: CreateEventScreen.maxPlayers.toDouble(),
                    divisions: CreateEventScreen.maxPlayers -
                        CreateEventScreen.minPlayers,
                    onChanged: (v) => _setPlayers(v.round()),
                  ),
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              tooltip: l10n.playMorePlayers,
              onPressed: _maxPlayers >= CreateEventScreen.maxPlayers
                  ? null
                  : () => _setPlayers(_maxPlayers + 1),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Label(l10n.eventFieldVisibility),
        for (final (value, icon, label, desc) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _VisibilityOption(
              key: ValueKey('visibility-${value.name}'),
              icon: icon,
              label: label,
              description: desc,
              selected: _visibility == value,
              onTap: () => setState(() => _visibility = value),
            ),
          ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(String hint,
        {double radius = AppRadius.panel}) =>
    appFieldDecoration(
      hint: hint,
      fill: AppColors.surfaceContainerHighest,
      radius: radius,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
    ).copyWith(
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );

/// `bg-surface-container-low rounded-lg p-5` form section.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.panel)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

/// Web form label: 10px black uppercase, widest tracking.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.bottom = AppSpacing.sm});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, bottom),
        child: Text(text.toUpperCase(), style: AppTypography.eyebrow),
      );
}

/// A filled input-looking button (date, time, game search).
class _FieldButton extends StatelessWidget {
  const _FieldButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.placeholder = false,
    this.trailingIcon = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool placeholder;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 18, color: AppColors.onSurfaceVariant);
    return Material(
      color: AppColors.surfaceContainerHighest,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.panel)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              if (!trailingIcon) ...[iconWidget, AppSpacing.hGapSm],
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
              if (trailingIcon) iconWidget,
            ],
          ),
        ),
      ),
    );
  }
}

/// Chosen game (web `GamePicker` selected state) with a remove button.
class _PickedGame extends StatelessWidget {
  const _PickedGame({required this.game, required this.onClear});

  final Game game;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final url = game.coverUrl;
    final fallback = ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: const Icon(Icons.casino_outlined, color: AppColors.primary),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.panel)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.all(Radius.circular(AppRadius.panel)),
            child: SizedBox.square(
              dimension: 48,
              child: url == null || url.isEmpty
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => fallback,
                    ),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleSmall.copyWith(fontSize: 16),
            ),
          ),
          Tooltip(
            message: context.l10n.eventRemoveGame,
            child: Material(
              color: AppColors.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('event-remove-game'),
                customBorder: const CircleBorder(),
                onTap: onClear,
                child: const SizedBox.square(
                  dimension: 36,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
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

/// 40px rounded square − / + button.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: Material(
            color: AppColors.surfaceContainerHigh,
            borderRadius: AppSpacing.borderRadiusLg,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 40,
                child: Icon(icon, color: AppColors.onSurface),
              ),
            ),
          ),
        ),
      );
}

/// Visibility option card: icon tile, label and description; the selected
/// one is tinted primary with a ring.
class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadius.panel));
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : AppColors.surfaceContainerHighest,
                    borderRadius: AppSpacing.borderRadiusLg,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.hGapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.titleSmall.copyWith(
                          color: selected
                              ? AppColors.primary
                              : AppColors.onSurface,
                        ),
                      ),
                      Text(
                        description,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline friend picker (web `FriendPicker`): chosen friends as removable
/// chips, a search field and a checkbox list of friends.
class _InviteFriends extends ConsumerStatefulWidget {
  const _InviteFriends({required this.selected, required this.onChanged});

  final List<UserSummary> selected;
  final ValueChanged<List<UserSummary>> onChanged;

  @override
  ConsumerState<_InviteFriends> createState() => _InviteFriendsState();
}

class _InviteFriendsState extends ConsumerState<_InviteFriends> {
  String _query = '';

  void _toggle(UserSummary u) {
    final chosen = widget.selected.any((s) => s.id == u.id);
    widget.onChanged(
      chosen
          ? widget.selected.where((s) => s.id != u.id).toList()
          : [...widget.selected, u],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friends = ref.watch(friendsListProvider);
    final chosenIds = {for (final u in widget.selected) u.id};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final u in widget.selected)
                Semantics(
                  button: true,
                  label: u.displayName,
                  child: GestureDetector(
                    key: ValueKey('invitee-${u.id}'),
                    onTap: () => _toggle(u),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.borderRadiusFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppAvatar(
                            imageUrl: u.avatarUrl,
                            displayName: u.displayName,
                            size: AvatarSize.xs,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 128),
                            child: Text(
                              u.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.vGapSm,
          Text(
            l10n.eventSelectedCount(widget.selected.length),
            style: AppTypography.labelSmall.copyWith(fontSize: 11),
          ),
          AppSpacing.vGapMd,
        ],
        ...friends.when(
          loading: () => [
            for (var i = 0; i < 3; i++)
              Container(
                height: 48,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius:
                      BorderRadius.all(Radius.circular(AppRadius.panel)),
                ),
              ),
          ],
          error: (e, _) => [
            Text(
              localizedError(l10n, e),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ],
          data: (s) {
            if (s.items.isEmpty) {
              return [
                Text(
                  l10n.friendPickerEmpty,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ];
            }
            final q = _query.toLowerCase();
            final visible = s.items
                .where(
                  (u) =>
                      q.isEmpty ||
                      u.displayName.toLowerCase().contains(q) ||
                      u.username.toLowerCase().contains(q),
                )
                .toList();
            return [
              TextField(
                key: const Key('event-invite-search'),
                onChanged: (v) => setState(() => _query = v.trim()),
                style: AppTypography.bodyMedium,
                decoration: appFieldDecoration(
                  hint: l10n.eventInviteSearch,
                  prefixIcon: Icons.search_rounded,
                  fill: AppColors.surfaceContainerHighest,
                  radius: AppRadius.panel,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 10,
                  ),
                ),
              ),
              AppSpacing.vGapSm,
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 256),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          l10n.friendPickerEmpty,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final u in visible)
                      _FriendRow(
                        friend: u,
                        selected: chosenIds.contains(u.id),
                        onTap: () => _toggle(u),
                      ),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.selected,
    required this.onTap,
  });

  final UserSummary friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.panel)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('invite-pick-${friend.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onTap(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                AppSpacing.hGapMd,
                AppAvatar(
                  imageUrl: friend.avatarUrl,
                  displayName: friend.displayName,
                  size: AvatarSize.sm,
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall,
                      ),
                      Text(
                        '@${friend.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
