import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_shadows.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Localised status label + colours (web `statusChipClass`: Open on
/// secondary-container, Full on error-container, the rest neutral).
(String, Color, Color) eventStatusStyle(AppLocalizations l10n, Event e) {
  if (e.isCancelled) {
    return (
      l10n.eventStatusCancelled,
      AppColors.surfaceContainerHighest,
      AppColors.onSurfaceVariant,
    );
  }
  if (e.isCompleted) {
    return (
      l10n.eventStatusCompleted,
      AppColors.surfaceContainerHighest,
      AppColors.onSurfaceVariant,
    );
  }
  if (e.isFull) {
    return (
      l10n.eventStatusFull,
      AppColors.errorContainer,
      AppColors.onErrorContainer,
    );
  }
  return (
    l10n.eventStatusOpen,
    AppColors.secondaryContainer,
    AppColors.onSecondaryContainer,
  );
}

/// Status pill. [large] is the hero variant (`px-3 py-1 text-xs`); the
/// default is the card badge (`px-2 py-0.5 text-[10px]`).
class EventStatusChip extends StatelessWidget {
  const EventStatusChip({super.key, required this.event, this.large = false});

  final Event event;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = eventStatusStyle(context.l10n, event);
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Text(
        label,
        style: (large ? AppTypography.labelMedium : AppTypography.labelSmall)
            .copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// List card — web `EventCard` (phone row layout): white `rounded-xl`
/// card with an 80px game cover (or date tile), title + status, a 2×2 grid
/// of host / players / time / place, and a footer with the other players'
/// avatars and "You're going" / "You're invited". Past events are muted.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.muted,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  final Event event;
  final VoidCallback? onTap;

  /// Defaults to completed / cancelled events.
  final bool? muted;
  final EdgeInsetsGeometry margin;

  static const _radius = BorderRadius.all(Radius.circular(AppRadius.tile));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = event;
    final isMuted = muted ?? (e.isCompleted || e.isCancelled);
    final host = e.host;
    final others = [
      for (final p in e.acceptedParticipants)
        if (p.id != host?.id) p.asUser,
    ];
    final going = !e.isHost && e.isAttending;
    final showFooter = others.isNotEmpty || going || e.isInvited;
    final local = e.scheduledAt.toLocal();
    return Padding(
      padding: margin,
      child: Opacity(
        opacity: isMuted ? 0.7 : 1,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: _radius,
            boxShadow: AppShadows.sm,
          ),
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: _radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('event-${e.id}'),
              onTap: onTap ?? () => context.push(AppRoutes.eventDetail(e.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventCover(event: e),
                        AppSpacing.hGapLg,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.title,
                                      style: AppTypography.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  AppSpacing.hGapSm,
                                  EventStatusChip(event: e),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _MetaGrid(
                                cells: [
                                  if (host != null)
                                    _Meta(
                                      icon: Icons.person_outline_rounded,
                                      text: displayNameOf(context, host),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  _Meta(
                                    icon: Icons.group_outlined,
                                    text: l10n.eventCardPlayers(
                                      e.participantCount,
                                      e.maxParticipants,
                                    ),
                                  ),
                                  _Meta(
                                    icon: Icons.schedule_rounded,
                                    text: '${DateFormat.MMMEd().format(local)}'
                                        ' · ${AppDateUtils.formatTime(local)}',
                                    maxLines: 2,
                                  ),
                                  if (e.displayLocation != null)
                                    _Meta(
                                      icon: Icons.location_on_outlined,
                                      text: e.displayLocation!,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showFooter)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          AvatarStack(users: others),
                          const Spacer(),
                          if (going)
                            _FooterLabel(
                              icon: Icons.check_circle_rounded,
                              text: l10n.eventCardGoing,
                              color: AppColors.tertiary,
                            )
                          else if (e.isInvited)
                            _FooterLabel(
                              icon: Icons.mail_outline_rounded,
                              text: l10n.eventCardInvited,
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The game's cover in a rounded square, or — without a cover, or when it
/// fails to load — the web date tile (`bg-primary/10`, "NOV" over "12").
class EventCover extends StatelessWidget {
  const EventCover({super.key, required this.event, this.size = 80});

  final Event event;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = event.game?.coverUrl;
    final dateTile = _DateTile(date: event.scheduledAt);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.panel)),
      child: SizedBox.square(
        dimension: size,
        child: url == null || url.isEmpty
            ? dateTile
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const ColoredBox(color: AppColors.surfaceContainerHigh),
                errorWidget: (_, __, ___) => dateTile,
              ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppDateUtils.formatMonthShort(local),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${local.day}',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.primary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column grid of meta rows (`grid-cols-2 gap-x-4 gap-y-1`).
class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cells[i]),
                AppSpacing.hGapLg,
                Expanded(
                  child: i + 1 < cells.length
                      ? cells[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FooterLabel extends StatelessWidget {
  const _FooterLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          AppSpacing.hGapXs,
          Text(
            text,
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
        ],
      );
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.maxLines = 1,
    this.fontSize = 11,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  /// 11px in the list card grid (`text-[11px]`), 12px elsewhere.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
        ),
        AppSpacing.hGapXs,
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              fontSize: fontSize,
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Compact card for the horizontal "Upcoming" row — web
/// `EventCardCompact`: 256px wide, surface-container-low, `rounded-xl`
/// (48px), weekday/time badge, player count, title, place and avatars.
class EventMiniCard extends StatelessWidget {
  const EventMiniCard({super.key, required this.event, this.width = 256});

  final Event event;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return AppCard(
      width: width,
      radius: AppRadius.tile,
      onTap: () => context.push(AppRoutes.eventDetail(e.id)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppChip(
                    label: AppDateUtils.formatWeekdayTime(e.scheduledAt),
                    variant: AppChipVariant.secondary,
                    uppercase: true,
                    dense: true,
                  ),
                ),
              ),
              AppSpacing.hGapSm,
              Text(
                '${e.participantCount}/${e.maxParticipants}',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          AppSpacing.vGapMd,
          Text(
            e.title,
            style: AppTypography.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (e.displayLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _Meta(
                icon: Icons.location_on_outlined,
                text: e.displayLocation!,
                fontSize: 12,
              ),
            ),
          AppSpacing.vGapMd,
          AvatarStack(
            users: [for (final p in e.acceptedParticipants) p.asUser],
          ),
        ],
      ),
    );
  }
}
