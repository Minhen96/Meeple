import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/presentation/widgets/event_card.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';

import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';
import 'package:table_calendar/table_calendar.dart';

/// Events (SCREENS §6): List (Upcoming | Past | Mine) or Calendar.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.calendarView = false});

  final bool calendarView;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late bool _calendar = widget.calendarView;

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendarView != widget.calendarView) {
      _calendar = widget.calendarView;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: MeepleAppBar(
          title: l10n.eventsTitle,
          actions: [
            IconButton(
              key: const Key('events-toggle-view'),
              tooltip: _calendar ? l10n.eventsListView : l10n.eventsCalendarView,
              icon: Icon(
                _calendar
                    ? Icons.view_list_rounded
                    : Icons.calendar_month_outlined,
              ),
              onPressed: () => setState(() => _calendar = !_calendar),
            ),
            IconButton(
              key: const Key('events-create'),
              tooltip: l10n.createEvent,
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => context.push(AppRoutes.createEvent),
            ),
          ],
        ),
        body: _calendar
            ? const EventCalendarView()
            : Column(
                children: [
                  TabBar(
                    dividerColor: AppColors.transparent,
                    tabs: [
                      Tab(text: l10n.eventsTabUpcoming),
                      Tab(text: l10n.eventsTabPast),
                      Tab(text: l10n.eventsTabMine),
                    ],
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        _EventList(scope: EventScope.upcoming),
                        _EventList(scope: EventScope.past),
                        _EventList(scope: EventScope.mine),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EventList extends ConsumerWidget {
  const _EventList({required this.scope});

  final EventScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final events = ref.watch(eventsListProvider(scope));
    Future<void> refresh() => ref.refresh(eventsListProvider(scope).future);
    return events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(error: e, onRetry: refresh),
      data: (result) {
        final list = result.data;
        return RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (result.cachedAt != null)
                SliverToBoxAdapter(
                  child: StaleDataBanner(cachedAt: result.cachedAt!),
                ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: scope == EventScope.past
                      ? EmptyState(
                          icon: Icons.history_rounded,
                          title: l10n.eventsEmptyPastTitle,
                          subtitle: l10n.eventsEmptyPastBody,
                        )
                      : EmptyState(
                          icon: Icons.event_available_outlined,
                          title: l10n.eventsEmptyUpcomingTitle,
                          subtitle: l10n.eventsEmptyUpcomingBody,
                          actionLabel: l10n.createEvent,
                          onAction: () => context.push(AppRoutes.createEvent),
                        ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 96),
                  sliver: SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => EventCard(event: list[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Monthly calendar with event dots; tapping a day lists its events in a
/// bottom sheet (SCREENS §6.3).
class EventCalendarView extends ConsumerStatefulWidget {
  const EventCalendarView({super.key});

  @override
  ConsumerState<EventCalendarView> createState() => _EventCalendarViewState();
}

class _EventCalendarViewState extends ConsumerState<EventCalendarView> {
  DateTime _focused = DateTime.now();

  DateTime get _month => DateTime(_focused.year, _focused.month);

  List<Event> _eventsOn(List<Event> events, DateTime day) =>
      events.where((e) => isSameDay(e.scheduledAt.toLocal(), day)).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  Future<void> _showDay(DateTime day, List<Event> events) async {
    if (events.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                AppDateUtils.formatFullDate(day),
                style: AppTypography.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [for (final e in events) EventCard(event: e)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final events = ref.watch(calendarEventsProvider(_month));
    final list = events.valueOrNull ?? const <Event>[];
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (events.isLoading) const LinearProgressIndicator(),
        if (events.hasError)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              localizedError(l10n, events.error!),
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        TableCalendar<Event>(
          key: const Key('events-calendar'),
          locale: Localizations.localeOf(context).toLanguageTag(),
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focused,
          startingDayOfWeek: StartingDayOfWeek.monday,
          availableCalendarFormats: const {CalendarFormat.month: ''},
          eventLoader: (day) => _eventsOn(list, day),
          onPageChanged: (day) => setState(() => _focused = day),
          onDaySelected: (selected, focused) {
            setState(() => _focused = focused);
            _showDay(selected, _eventsOn(list, selected));
          },
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: AppTypography.titleMedium,
          ),
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 3,
          ),
        ),
        if (!events.isLoading && list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              l10n.eventsNoneThisMonth,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ),
        for (final e in [...list]
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)))
          EventCard(event: e),
      ],
    );
  }
}
