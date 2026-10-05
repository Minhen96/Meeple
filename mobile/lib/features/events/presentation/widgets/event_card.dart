import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Localised status label + colours (Open / Full / Completed / Cancelled).
(String, Color, Color) eventStatusStyle(AppLocalizations l10n, Event e) {
  if (e.isCancelled) {
    return (l10n.eventStatusCancelled, AppColors.errorContainer,
        AppColors.onErrorContainer);
  }
  if (e.isCompleted) {
    return (l10n.eventStatusCompleted, AppColors.surfaceContainerHighest,
        AppColors.onSurfaceVariant);
  }
  if (e.isFull) {
    return (l10n.eventStatusFull, AppColors.surfaceContainerHighest,
        AppColors.onSurface);
  }
  return (l10n.eventStatusOpen, AppColors.secondaryContainer,
      AppColors.onSecondaryContainer);
}

class EventStatusChip extends StatelessWidget {
  const EventStatusChip({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = eventStatusStyle(context.l10n, event);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: fg),
      ),
    );
  }
}

/// List card (SCREENS §6.2): game thumbnail, title, host, date, location,
/// participant bar and status. Past events are muted.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = event;
    final muted = e.isCompleted || e.isCancelled;
    final host = e.host;
    return Opacity(
      opacity: muted ? 0.7 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Material(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.borderRadiusXl,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('event-${e.id}'),
            onTap: onTap ?? () => context.push(AppRoutes.eventDetail(e.id)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventThumb(event: e),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.title,
                                style: AppTypography.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AppSpacing.hGapSm,
                            EventStatusChip(event: e),
                          ],
                        ),
                        AppSpacing.vGapXs,
                        _Meta(
                          icon: Icons.schedule_rounded,
                          text: AppDateUtils.formatDateTime(e.scheduledAt),
                        ),
                        if (e.displayLocation != null)
                          _Meta(
                            icon: Icons.location_on_outlined,
                            text: e.displayLocation!,
                          ),
                        AppSpacing.vGapSm,
                        Row(
                          children: [
                            if (host != null) ...[
                              AppAvatar(
                                imageUrl: host.avatarUrl,
                                displayName: host.displayName,
                                size: AvatarSize.xs,
                              ),
                              AppSpacing.hGapXs,
                              Expanded(
                                child: Text(
                                  l10n.eventHostedBy(displayNameOf(context, host)),
                                  style: AppTypography.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else
                              const Spacer(),
                            Text(
                              e.maxParticipants > 0
                                  ? l10n.eventPlayersCount(
                                      e.participantCount,
                                      e.maxParticipants,
                                    )
                                  : l10n.eventGoingCount(e.participantCount),
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                        if (e.maxParticipants > 0) ...[
                          AppSpacing.vGapXs,
                          ClipRRect(
                            borderRadius: AppSpacing.borderRadiusFull,
                            child: LinearProgressIndicator(
                              value: (e.participantCount / e.maxParticipants)
                                  .clamp(0, 1)
                                  .toDouble(),
                              minHeight: 4,
                              backgroundColor: AppColors.surfaceContainerHigh,
                              color: AppColors.primaryContainer,
                            ),
                          ),
                        ],
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

/// Compact card for the horizontal "Upcoming" row (DESIGN event card).
class EventMiniCard extends StatelessWidget {
  const EventMiniCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return SizedBox(
      width: 240,
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusXl,
        child: InkWell(
          borderRadius: AppSpacing.borderRadiusXl,
          onTap: () => context.push(AppRoutes.eventDetail(e.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: Text(
                    AppDateUtils.formatDateTime(e.scheduledAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ),
                AppSpacing.vGapSm,
                Text(
                  e.title,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (e.displayLocation != null)
                  _Meta(
                    icon: Icons.location_on_outlined,
                    text: e.displayLocation!,
                  ),
                const Spacer(),
                AvatarStack(
                  users: [for (final p in e.acceptedParticipants) p.asUser],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventThumb extends StatelessWidget {
  const _EventThumb({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final url = event.game?.coverUrl;
    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusLg,
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null
            ? DecoratedBox(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Center(
                  child: Text(
                    '${event.scheduledAt.toLocal().day}',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          AppSpacing.hGapXs,
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
