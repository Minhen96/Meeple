import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';

/// Card displaying an [Event] summary in a list or grid.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onRsvpTap,
  });

  final Event event;
  final VoidCallback? onTap;
  final VoidCallback? onRsvpTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventDateBadge(event: event),
              AppSpacing.vGapMd,
              Text(
                event.title,
                style: AppTypography.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.vGapXs,
              _EventMeta(event: event),
              if (event.gameNames.isNotEmpty) ...[
                AppSpacing.vGapMd,
                _GameChips(gameNames: event.gameNames),
              ],
              AppSpacing.vGapMd,
              _EventFooter(event: event, onRsvpTap: onRsvpTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDateBadge extends StatelessWidget {
  const _EventDateBadge({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final startTime = event.startTime;
    final dayName = DateFormat.E().format(startTime).toUpperCase();
    final dayNum = DateFormat.d().format(startTime);
    final month = DateFormat.MMM().format(startTime).toUpperCase();

    return Row(
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          child: Column(
            children: [
              Text(
                dayName,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
              Text(
                dayNum,
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
              Text(
                month,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.hGapMd,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.jm().format(startTime),
              style: AppTypography.titleSmall,
            ),
            Text(
              'by ${event.organizerDisplayName}',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _EventMeta extends StatelessWidget {
  const _EventMeta({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: AppColors.onSurfaceVariant,
        ),
        AppSpacing.hGapXs,
        Expanded(
          child: Text(
            event.location,
            style: AppTypography.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GameChips extends StatelessWidget {
  const _GameChips({required this.gameNames});

  final List<String> gameNames;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: gameNames
          .take(3)
          .map(
            (name) => AppChip(
              label: name,
              variant: AppChipVariant.tertiary,
              icon: Icons.casino_outlined,
            ),
          )
          .toList(),
    );
  }
}

class _EventFooter extends StatelessWidget {
  const _EventFooter({required this.event, this.onRsvpTap});

  final Event event;
  final VoidCallback? onRsvpTap;

  @override
  Widget build(BuildContext context) {
    final isFull = event.maxAttendees != null &&
        event.attendeeCount >= event.maxAttendees!;

    return Row(
      children: [
        const Icon(
          Icons.people_outline_rounded,
          size: 16,
          color: AppColors.onSurfaceVariant,
        ),
        AppSpacing.hGapXs,
        Text(
          event.maxAttendees != null
              ? '${event.attendeeCount} / ${event.maxAttendees}'
              : '${event.attendeeCount} attending',
          style: AppTypography.bodySmall,
        ),
        const Spacer(),
        if (isFull && !event.isAttending)
          const AppChip(label: 'Full', variant: AppChipVariant.error)
        else
          _RsvpButton(isAttending: event.isAttending, onTap: onRsvpTap),
      ],
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({required this.isAttending, this.onTap});

  final bool isAttending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          gradient: isAttending ? null : AppColors.primaryGradient,
          color: isAttending ? AppColors.surfaceContainerHigh : null,
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        child: Text(
          isAttending ? 'Going ✓' : 'RSVP',
          style: AppTypography.labelLarge.copyWith(
            color: isAttending
                ? AppColors.onSurfaceVariant
                : AppColors.onPrimary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
