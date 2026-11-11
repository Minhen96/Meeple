import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_shadows.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/presentation/widgets/event_card.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/post_card.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/social/presentation/friend_picker.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// What the action bar shows (web `rsvpAction`, SCREENS §6.4).
enum EventAction {
  cancelled,
  completed,
  host,
  going,
  kicked,
  respond,
  changeToGoing,
  join,
  full,

  /// Not invited to a non-public event: no action, a notice instead.
  none;

  static EventAction of(Event e) {
    if (e.isCancelled) return EventAction.cancelled;
    if (e.isCompleted) return EventAction.completed;
    if (e.isHost) return EventAction.host;
    switch (e.myRsvp) {
      case 'ACCEPTED':
        return EventAction.going;
      case 'KICKED':
        return EventAction.kicked;
      case 'INVITED':
        return EventAction.respond;
      case 'DECLINED':
        return e.isFull ? EventAction.full : EventAction.changeToGoing;
    }
    if (e.visibilityValue != EventVisibility.public) return EventAction.none;
    return e.isFull ? EventAction.full : EventAction.join;
  }
}

/// Event detail (SCREENS §6.4 / web `/events/[eventId]`): gradient hero
/// with back button, status + visibility and title; host row, When / Where
/// tiles, the game, description and players; a floating action bar with
/// RSVP buttons, or the host's "Manage Event" sheet (edit, invite,
/// participants, cancel).
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final event = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircleBackButton(),
                ),
              ),
              Expanded(
                child: e is NotFoundException
                    ? EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: l10n.eventNotFound,
                      )
                    : ErrorState(
                        error: e,
                        onRetry: () =>
                            ref.invalidate(eventDetailProvider(eventId)),
                      ),
              ),
            ],
          ),
        ),
        data: (e) => Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => ref.refresh(eventDetailProvider(eventId).future),
              child: _Body(event: e),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _ActionBar(event: e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.event});

  final Event event;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _showMemories = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = widget.event;
    final action = EventAction.of(e);
    final host = e.host;
    final others = [
      for (final p in e.acceptedParticipants)
        if (p.id != host?.id) p,
    ];
    final spotsLeft = (e.maxParticipants - e.participantCount).clamp(0, 9999);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 120),
      children: [
        _Hero(event: e),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, AppSpacing.xl, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action == EventAction.cancelled)
                _Banner(
                  text: l10n.eventCancelledBanner,
                  color: AppColors.errorContainer,
                  textColor: AppColors.onErrorContainer,
                  bold: true,
                )
              else if (action == EventAction.completed)
                _Banner(
                  text: l10n.eventEndedBanner,
                  color: AppColors.surfaceContainerHigh,
                  textColor: AppColors.onSurface,
                  bold: true,
                  action: AppButton(
                    key: const Key('event-memories'),
                    label: l10n.eventViewMemories,
                    variant: AppButtonVariant.solid,
                    size: AppButtonSize.sm,
                    minWidth: 0,
                    onPressed: () => setState(() => _showMemories = true),
                  ),
                )
              else if (action == EventAction.kicked)
                _Banner(
                  text: l10n.eventYouWereRemoved,
                  color: AppColors.surfaceContainerHigh,
                  textColor: AppColors.onSurfaceVariant,
                ),
              if (host != null) _HostRow(host: host),
              AppSpacing.vGapXl,
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.calendar_today_outlined,
                        iconColor: AppColors.primary,
                        label: l10n.eventDetailWhen,
                        value: DateFormat.MMMMEEEEd()
                            .add_jm()
                            .format(e.scheduledAt.toLocal()),
                      ),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.location_on_outlined,
                        iconColor: AppColors.secondary,
                        label: l10n.eventDetailWhere,
                        value: e.displayLocation ?? l10n.eventLocationTbd,
                        muted: e.displayLocation == null,
                        hint: (e.location?.isEmpty ?? true) &&
                                (e.locationDisplay?.isNotEmpty ?? false)
                            ? l10n.eventLocationHidden
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (e.game != null) ...[
                AppSpacing.vGapXl,
                _GameRow(event: e),
              ],
              if (e.description != null && e.description!.isNotEmpty) ...[
                AppSpacing.vGapXl,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    e.description!,
                    style: AppTypography.bodyLarge.copyWith(height: 1.6),
                  ),
                ),
              ],
              AppSpacing.vGapXl,
              _PlayersHeader(event: e, spotsLeft: spotsLeft),
              AppSpacing.vGapMd,
              _PlayersPanel(players: others),
              if (_showMemories) ...[
                AppSpacing.vGapXl,
                _Memories(eventId: e.id),
              ],
              if (action == EventAction.none) ...[
                AppSpacing.vGapXl,
                Text(
                  l10n.eventInviteOnlyNotice,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Web hero: diagonal primary → secondary → tertiary gradient with the game
/// art blended in, a frosted back button, and status / visibility / title
/// over a dark bottom fade.
class _Hero extends StatelessWidget {
  const _Hero({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = event;
    final top = MediaQuery.paddingOf(context).top;
    final (visIcon, visLabel) = switch (e.visibilityValue) {
      EventVisibility.public => (
          Icons.public_rounded,
          l10n.eventVisPublicEvent
        ),
      EventVisibility.friends => (
          Icons.group_outlined,
          l10n.eventVisFriendsOnly
        ),
      EventVisibility.inviteOnly => (
          Icons.lock_outline_rounded,
          l10n.visibilityInviteOnly,
        ),
    };
    final url = e.game?.heroUrl;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, top, AppSpacing.lg, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.panel),
        ),
        child: SizedBox(
          height: 256,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.surface),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.secondary.withValues(alpha: 0.7),
                      AppColors.tertiary.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              if (url != null && url.isNotEmpty)
                Opacity(
                  opacity: 0.4,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Transform.scale(
                      scale: 1.1,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            EventStatusChip(event: e, large: true),
                            AppSpacing.hGapSm,
                            Icon(
                              visIcon,
                              size: 14,
                              color: AppColors.onPrimary.withValues(alpha: 0.8),
                            ),
                            AppSpacing.hGapXs,
                            Flexible(
                              child: Text(
                                visLabel,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onPrimary
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.vGapSm,
                        Text(
                          e.title,
                          style: AppTypography.headlineLarge.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                            shadows: const [
                              Shadow(
                                color: Color(0x40000000),
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                child: _GlassCircle(
                  key: const Key('event-back'),
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.events),
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _GlassCircle(
                  key: const Key('event-share'),
                  icon: Icons.share_outlined,
                  tooltip: l10n.commonShare,
                  onTap: () =>
                      Share.share('${AppConfig.webOrigin}/events/${e.id}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44px frosted white/20 circle (hero back button).
class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.white.withValues(alpha: 0.2),
              child: InkWell(
                onTap: onTap,
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(icon, color: AppColors.onPrimary),
                ),
              ),
            ),
          ),
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.color,
    required this.textColor,
    this.bold = false,
    this.action,
  });

  final String text;
  final Color color;
  final Color textColor;
  final bool bold;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xl),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius:
              const BorderRadius.all(Radius.circular(AppRadius.panel)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (action != null) ...[AppSpacing.hGapMd, action!],
          ],
        ),
      );
}

/// "Hosted by …" / HOST row; links to the host's profile unless deleted.
class _HostRow extends StatelessWidget {
  const _HostRow({required this.host});

  final UserSummary host;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = displayNameOf(context, host);
    final deleted = host.deleted;
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.panel)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('event-host'),
        onTap:
            deleted ? null : () => context.push(AppRoutes.userProfile(host.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: deleted ? null : host.avatarUrl,
                displayName: name,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.eventHostedBy(name),
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.eventDetailHost.toUpperCase(),
                      style: AppTypography.overline.copyWith(
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!deleted)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.hint,
    this.muted = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? hint;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.panel)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor),
            AppSpacing.vGapSm,
            Text(label.toUpperCase(), style: AppTypography.eyebrow),
            AppSpacing.vGapSm,
            Text(
              value,
              style: AppTypography.titleSmall.copyWith(
                height: 1.25,
                color: muted ? AppColors.onSurfaceVariant : null,
              ),
            ),
            if (hint != null) ...[
              AppSpacing.vGapXs,
              Text(
                hint!,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final game = event.game!;
    final url = game.coverUrl;
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.panel)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('event-game'),
        onTap: () => context.push(AppRoutes.gameDetail(game.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              if (url != null && url.isNotEmpty) ...[
                ClipRRect(
                  borderRadius:
                      const BorderRadius.all(Radius.circular(AppRadius.panel)),
                  child: SizedBox.square(
                    dimension: 56,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.casino_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                AppSpacing.hGapLg,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.eventDetailPlaying.toUpperCase(),
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      game.name,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayersHeader extends StatelessWidget {
  const _PlayersHeader({required this.event, required this.spotsLeft});

  final Event event;
  final int spotsLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final max = event.maxParticipants;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.eventDetailPlayers.toUpperCase(),
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                Text(
                  l10n.eventDetailSpots(event.participantCount, spotsLeft),
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (max > 0)
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: AppSpacing.borderRadiusFull,
                child: LinearProgressIndicator(
                  value: (event.participantCount / max).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  color: AppColors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Going players other than the host, four to a row.
class _PlayersPanel extends StatelessWidget {
  const _PlayersPanel({required this.players});

  final List<EventParticipant> players;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.panel)),
      ),
      child: players.isEmpty
          ? Text(
              context.l10n.eventDetailNoOneYet,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          : LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 3 * AppSpacing.md) / 4;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final p in players)
                      SizedBox(
                        width: w,
                        child: InkWell(
                          key: ValueKey('participant-${p.id}'),
                          onTap: () =>
                              context.push(AppRoutes.userProfile(p.id)),
                          child: Column(
                            children: [
                              AppAvatar(
                                imageUrl: p.avatarUrl,
                                displayName: p.displayName,
                                size: AvatarSize.lg,
                              ),
                              AppSpacing.vGapXs,
                              Text(
                                p.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/// "Memories" section of a finished event: posts tagged to it.
class _Memories extends ConsumerWidget {
  const _Memories({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final posts = ref.watch(eventPostsProvider(eventId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.eventMemoriesTitle.toUpperCase(),
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('event-share-memory'),
                onTap: () =>
                    context.push('${AppRoutes.createPost}?eventId=$eventId'),
                child: Text(
                  l10n.eventShareMemory,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vGapMd,
        ...posts.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => [
            ErrorState(
              error: e,
              onRetry: () => ref.invalidate(eventPostsProvider(eventId)),
            ),
          ],
          data: (list) => list.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.eventNoMemories,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ]
              : [for (final p in list) PostCard(post: p)],
        ),
      ],
    );
  }
}

/// Floating glass action bar (web: `bg-surface/80 backdrop-blur-xl
/// rounded-full p-2 shadow-lg`) with the RSVP buttons or "Manage Event".
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.event});

  final Event event;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, {String? success}) async {
    setState(() => _busy = true);
    try {
      await f();
      if (success != null && mounted) {
        showToast(context, success, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = widget.event;
    final notifier = ref.read(eventDetailProvider(e.id).notifier);
    final action = EventAction.of(e);
    Widget? child;
    switch (action) {
      case EventAction.host:
        child = _ManageButton(event: e);
      case EventAction.going:
        child = Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.tertiary,
              size: 20,
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                l10n.eventCardGoing,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.tertiary,
                ),
              ),
            ),
            _Pill(
              key: const Key('rsvp-leave'),
              label: l10n.eventLeave,
              color: AppColors.surfaceContainerHighest,
              textColor: AppColors.onSurfaceVariant,
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await showConfirmSheet(
                        context,
                        title: l10n.eventLeaveTitle,
                        message: l10n.eventLeaveMessage,
                        confirmLabel: l10n.eventLeaveConfirm,
                      );
                      if (ok) await _run(notifier.leave);
                    },
            ),
          ],
        );
      case EventAction.respond:
        child = Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('rsvp-accept'),
                label: e.isFull ? l10n.eventFull : l10n.eventAccept,
                isLoading: _busy,
                onPressed: e.isFull
                    ? null
                    : () => _run(
                          () => notifier.rsvp('ACCEPTED'),
                          success: l10n.eventJoined,
                        ),
              ),
            ),
            AppSpacing.hGapSm,
            _Pill(
              key: const Key('rsvp-decline'),
              label: l10n.eventDecline,
              color: AppColors.surfaceContainerHigh,
              textColor: AppColors.onSurface,
              onPressed:
                  _busy ? null : () => _run(() => notifier.rsvp('DECLINED')),
            ),
          ],
        );
      case EventAction.changeToGoing:
      case EventAction.join:
        child = AppButton(
          key: const Key('rsvp-join'),
          label: action == EventAction.join
              ? l10n.eventJoin
              : l10n.eventChangeToGoing,
          isLoading: _busy,
          onPressed: () =>
              _run(() => notifier.rsvp('ACCEPTED'), success: l10n.eventJoined),
        );
      case EventAction.full:
        child = AppButton(
          key: const Key('rsvp-full'),
          label: l10n.eventFull,
          variant: AppButtonVariant.secondary,
          onPressed: null,
        );
      case EventAction.cancelled:
      case EventAction.completed:
      case EventAction.kicked:
      case EventAction.none:
        child = null;
    }
    if (child == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppSpacing.borderRadiusFull,
        boxShadow: AppShadows.bar,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusFull,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(
            color: AppColors.surface.withValues(alpha: 0.8),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact filled pill (`px-5 py-3 rounded-full text-sm font-bold`).
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          color: color,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(color: textColor),
              ),
            ),
          ),
        ),
      );
}

/// Dark "Manage Event" button; opens the host sheet.
class _ManageButton extends ConsumerWidget {
  const _ManageButton({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Material(
      color: AppColors.onSurface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('event-manage'),
        onTap: () => _openManageSheet(context, ref, event),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tune_rounded,
                  size: 20, color: AppColors.surface),
              AppSpacing.hGapSm,
              Text(
                l10n.eventManage,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openManageSheet(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  final l10n = context.l10n;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(
              key: const Key('manage-edit'),
              icon: Icons.edit_outlined,
              label: l10n.eventEdit,
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            _MenuItem(
              key: const Key('manage-invite'),
              icon: Icons.person_add_alt_outlined,
              label: l10n.eventInviteFriends,
              onTap: () => Navigator.of(sheet).pop('invite'),
            ),
            _MenuItem(
              key: const Key('manage-participants'),
              icon: Icons.groups_outlined,
              label: l10n.eventManageParticipants,
              onTap: () => Navigator.of(sheet).pop('participants'),
            ),
            _MenuItem(
              key: const Key('manage-cancel'),
              icon: Icons.event_busy_outlined,
              label: l10n.eventCancelConfirm,
              danger: true,
              onTap: () => Navigator.of(sheet).pop('cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  final notifier = ref.read(eventDetailProvider(event.id).notifier);
  switch (choice) {
    case 'edit':
      await context.push(AppRoutes.editEvent(event.id));
    case 'invite':
      final picked = await showFriendPicker(
        context,
        title: l10n.eventInviteFriends,
        exclude: {
          for (final p in event.participants)
            if (p.status == 'INVITED' || p.status == 'ACCEPTED') p.id,
        },
      );
      if (picked == null || picked.isEmpty) return;
      try {
        await notifier.invite([for (final u in picked) u.id]);
        if (context.mounted) {
          showToast(context, l10n.eventInvitesSent, type: ToastType.success);
        }
      } catch (e) {
        if (context.mounted) showErrorToast(context, e);
      }
    case 'participants':
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => _ParticipantsSheet(eventId: event.id),
      );
    case 'cancel':
      final ok = await showConfirmSheet(
        context,
        title: l10n.eventCancelTitle,
        message: l10n.eventCancelMessage,
        confirmLabel: l10n.eventCancelConfirm,
      );
      if (!ok) return;
      try {
        await notifier.cancel();
      } catch (e) {
        if (context.mounted) showErrorToast(context, e);
      }
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.onSurface;
    return Material(
      color: AppColors.transparent,
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
              Icon(icon, size: 20, color: color),
              AppSpacing.hGapMd,
              Text(
                label,
                style: AppTypography.titleSmall.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Host's participant list with "Remove" for going / invited players.
class _ParticipantsSheet extends ConsumerWidget {
  const _ParticipantsSheet({required this.eventId});

  final String eventId;

  String _status(AppLocalizations l10n, String s) => switch (s) {
        'INVITED' => l10n.eventRsvpInvited,
        'ACCEPTED' => l10n.eventRsvpAccepted,
        'DECLINED' => l10n.eventRsvpDeclined,
        'LEFT' => l10n.eventRsvpLeft,
        'KICKED' => l10n.eventRsvpKicked,
        _ => s,
      };

  Future<void> _kick(
    BuildContext context,
    WidgetRef ref,
    EventParticipant p,
  ) async {
    final l10n = context.l10n;
    final ok = await showConfirmSheet(
      context,
      title: l10n.eventKickTitle,
      message: l10n.eventKickMessage(p.displayName),
      confirmLabel: l10n.eventKick,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(eventDetailProvider(eventId).notifier).kick(p.id);
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final event = ref.watch(eventDetailProvider(eventId)).valueOrNull;
    final managed = [
      for (final p in event?.participants ?? const <EventParticipant>[])
        if (p.id != event?.host?.id) p,
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.eventParticipantsTitle, style: AppTypography.titleLarge),
            AppSpacing.vGapLg,
            if (managed.isEmpty)
              Text(
                l10n.eventDetailNoOneYet,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: managed.length,
                  separatorBuilder: (_, __) => AppSpacing.vGapSm,
                  itemBuilder: (_, i) {
                    final p = managed[i];
                    final canKick =
                        p.status == 'ACCEPTED' || p.status == 'INVITED';
                    return Container(
                      key: ValueKey('managed-${p.id}'),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.panel),
                        ),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            imageUrl: p.avatarUrl,
                            displayName: p.displayName,
                            size: AvatarSize.sm,
                          ),
                          AppSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.displayName,
                                  style: AppTypography.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _status(l10n, p.status),
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canKick)
                            AppChip(
                              key: ValueKey('kick-${p.id}'),
                              label: l10n.eventKick,
                              variant: AppChipVariant.error,
                              onTap: () => _kick(context, ref, p),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
