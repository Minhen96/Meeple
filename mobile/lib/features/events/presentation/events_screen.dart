import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Events screen — Phase 1 stub.
///
/// Tabs: Upcoming | My Events | Past.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: MeepleAppBar(
          title: 'Events',
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Create event',
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            ColoredBox(
              color: AppColors.surface,
              child: TabBar(
                tabs: const [
                  Tab(text: 'UPCOMING'),
                  Tab(text: 'MY EVENTS'),
                  Tab(text: 'PAST'),
                ],
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
                unselectedLabelStyle: AppTypography.labelMedium,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _EventsList(),
                  _EmptyMyEvents(),
                  _EventsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, __) => AppSpacing.vGapSm,
      itemBuilder: (_, __) => _EventCardSkeleton(),
    );
  }
}

class _EmptyMyEvents extends StatelessWidget {
  const _EmptyMyEvents();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.event_outlined,
      title: 'No events yet',
      subtitle: 'Create an event or join one nearby to get started.',
    );
  }
}

class _EventCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
    );
  }
}
