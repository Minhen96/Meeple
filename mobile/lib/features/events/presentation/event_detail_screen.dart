import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: eventAsync.when(
        loading: () => const _EventDetailSkeleton(),
        error: (Object e, __) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        data: (Event event) => _EventDetailContent(event: event),
      ),
    );
  }
}

class _EventDetailContent extends ConsumerWidget {
  const _EventDetailContent({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFull = event.maxAttendees != null &&
        event.attendeeCount >= event.maxAttendees!;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: AppSpacing.pagePadding,
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Date badge + title
              _DateRow(startTime: event.startTime, endTime: event.endTime),
              AppSpacing.vGapMd,
              Text(event.title, style: AppTypography.headlineSmall),
              AppSpacing.vGapSm,
              Text(
                'Organised by ${event.organizerDisplayName}',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.vGapXl,

              // Location
              _InfoRow(
                icon: Icons.location_on_outlined,
                title: event.location,
                subtitle: event.locationDetails,
              ),
              AppSpacing.vGapMd,

              // Attendees
              _InfoRow(
                icon: Icons.people_outline_rounded,
                title: event.maxAttendees != null
                    ? '${event.attendeeCount} / ${event.maxAttendees} attending'
                    : '${event.attendeeCount} attending',
                subtitle: isFull ? 'Event is full' : null,
                subtitleColor: isFull ? AppColors.error : null,
              ),
              AppSpacing.vGapXl,

              // Description
              Text('About this event', style: AppTypography.titleMedium),
              AppSpacing.vGapSm,
              Text(event.description, style: AppTypography.bodyMedium),

              // Games
              if (event.gameNames.isNotEmpty) ...[
                AppSpacing.vGapXl,
                Text('Games', style: AppTypography.titleMedium),
                AppSpacing.vGapSm,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: event.gameNames
                      .map(
                        (String name) => AppChip(
                          label: name,
                          variant: AppChipVariant.tertiary,
                          icon: Icons.casino_outlined,
                        ),
                      )
                      .toList(),
                ),
              ],

              const SizedBox(height: 120),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.startTime, this.endTime});

  final DateTime startTime;
  final DateTime? endTime;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(startTime);
    final startStr = DateFormat.jm().format(startTime);
    final timeLabel = endTime != null
        ? '$startStr – ${DateFormat.jm().format(endTime!)}'
        : startStr;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          child: Text(
            DateFormat.d().format(startTime),
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ),
        AppSpacing.hGapMd,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr, style: AppTypography.titleSmall),
            Text(timeLabel, style: AppTypography.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodyMedium),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.bodySmall.copyWith(
                    color: subtitleColor ?? AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventDetailSkeleton extends StatelessWidget {
  const _EventDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 120, height: 16),
            AppSpacing.vGapMd,
            const SkeletonBox(height: 28),
            AppSpacing.vGapSm,
            const SkeletonBox(width: 160, height: 14),
            AppSpacing.vGapXl,
            const SkeletonBox(height: 14),
            AppSpacing.vGapSm,
            const SkeletonBox(height: 14),
            AppSpacing.vGapXl,
            const SkeletonBox(height: 14),
            AppSpacing.vGapXs,
            const SkeletonBox(height: 14),
            AppSpacing.vGapXs,
            const SkeletonBox(width: 200, height: 14),
          ],
        ),
      ),
    );
  }
}

/// RSVP / cancel-RSVP button shown as a bottom sheet action.
class EventRsvpBar extends ConsumerWidget {
  const EventRsvpBar({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFull = event.maxAttendees != null &&
        event.attendeeCount >= event.maxAttendees!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: event.isAttending
            ? AppOutlinedButton(
                label: 'Cancel RSVP',
                onPressed: () =>
                    ref.read(eventsNotifierProvider.notifier).refresh(),
              )
            : AppButton(
                label: isFull ? 'Join Waitlist' : 'RSVP',
                onPressed: isFull ? null : () {},
              ),
      ),
    );
  }
}
