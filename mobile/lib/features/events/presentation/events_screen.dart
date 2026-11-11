import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/presentation/widgets/event_card.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// List filter of the events screen (web `?tab=`).
enum EventsTab { upcoming, past, community }

/// Events (SCREENS §6 / web `/events`): "Game Nights" heading with a
/// Create Event pill, a List / Calendar toggle, Upcoming / Past /
/// Community filter pills and event row cards — or the month calendar.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.calendarView = false});

  final bool calendarView;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late bool _calendar = widget.calendarView;
  EventsTab _tab = EventsTab.upcoming;

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
    return Scaffold(
      appBar: const MeepleBrandBar(),
      body: Consumer(
        builder: (context, ref, _) {
          Future<void> refresh() {
            if (_calendar) {
              ref.invalidate(calendarEventsProvider);
              return Future.value();
            }
            if (_tab == EventsTab.community) {
              return ref.refresh(communityEventsProvider.future);
            }
            return ref.refresh(eventsListProvider(_scopeOf(_tab)).future);
          }

          return RefreshIndicator(
            onRefresh: refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Heading(),
                        const SizedBox(height: 20),
                        AppSegmentedControl<bool>(
                          key: const Key('events-view-toggle'),
                          segments: [
                            AppSegment(
                              value: false,
                              label: l10n.eventsViewList,
                              icon: Icons.view_agenda_outlined,
                            ),
                            AppSegment(
                              value: true,
                              label: l10n.eventsViewCalendar,
                              icon: Icons.calendar_month_outlined,
                            ),
                          ],
                          selected: _calendar,
                          onChanged: (v) => setState(() => _calendar = v),
                        ),
                        AppSpacing.vGapLg,
                        if (!_calendar) ...[
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final t in EventsTab.values)
                                AppFilterPill(
                                  key: ValueKey('events-tab-${t.name}'),
                                  label: _tabLabel(l10n, t),
                                  selected: _tab == t,
                                  onTap: () => setState(() => _tab = t),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_calendar)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    sliver: SliverToBoxAdapter(child: EventCalendarView()),
                  )
                else if (_tab == EventsTab.community)
                  const _CommunityList()
                else
                  _ScopeList(key: ValueKey(_tab), tab: _tab),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
        },
      ),
    );
  }
}

EventScope _scopeOf(EventsTab tab) =>
    tab == EventsTab.past ? EventScope.past : EventScope.upcoming;

String _tabLabel(AppLocalizations l10n, EventsTab t) => switch (t) {
      EventsTab.upcoming => l10n.eventsTabUpcoming,
      EventsTab.past => l10n.eventsTabPast,
      EventsTab.community => l10n.eventsTabCommunity,
    };

/// "Game Nights" + subtitle, with the gradient Create Event pill.
class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.eventsPageTitle,
                  style: AppTypography.headlineLarge,
                ),
              ),
              AppSpacing.vGapXs,
              Text(
                l10n.eventsPageSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.hGapMd,
        AppButton(
          key: const Key('events-create'),
          label: l10n.eventCreateCta,
          icon: Icons.add_rounded,
          size: AppButtonSize.sm,
          minWidth: 0,
          onPressed: () => context.push(AppRoutes.createEvent),
        ),
      ],
    );
  }
}

/// Upcoming / Past list (`GET /events?scope=`).
class _ScopeList extends ConsumerWidget {
  const _ScopeList({super.key, required this.tab});

  final EventsTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = _scopeOf(tab);
    final events = ref.watch(eventsListProvider(scope));
    return events.when(
      loading: () => const _ListSkeleton(),
      error: (e, _) => SliverToBoxAdapter(
        child: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(eventsListProvider(scope)),
        ),
      ),
      data: (result) => SliverMainAxisGroup(
        slivers: [
          if (result.cachedAt != null)
            SliverToBoxAdapter(
              child: StaleDataBanner(cachedAt: result.cachedAt!),
            ),
          _cards(context, result.data, tab),
        ],
      ),
    );
  }
}

/// Community tab (`GET /events/community`) with "Load more".
class _CommunityList extends ConsumerWidget {
  const _CommunityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final page = ref.watch(communityEventsProvider);
    return page.when(
      loading: () => const _ListSkeleton(),
      error: (e, _) => SliverToBoxAdapter(
        child: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(communityEventsProvider),
        ),
      ),
      data: (s) => SliverMainAxisGroup(
        slivers: [
          _cards(context, s.items, EventsTab.community),
          if (s.hasMore && s.items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Center(
                  child: AppButton(
                    key: const Key('events-load-more'),
                    label: l10n.eventsLoadMore,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    minWidth: 0,
                    isLoading: s.isLoadingMore,
                    onPressed: () =>
                        ref.read(communityEventsProvider.notifier).loadMore(),
                  ),
                ),
              ),
            ),
          if (s.loadMoreError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  localizedError(l10n, s.loadMoreError!),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _cards(BuildContext context, List<Event> list, EventsTab tab) {
  if (list.isEmpty) {
    return SliverToBoxAdapter(child: _EmptyEvents(tab: tab));
  }
  return SliverList.builder(
    itemCount: list.length,
    itemBuilder: (_, i) => EventCard(
      event: list[i],
      muted: tab == EventsTab.past,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
    ),
  );
}

/// Web empty state: faded 48px icon, title, body and (except Past) a
/// solid Create Event pill.
class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents({required this.tab});

  final EventsTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, body, cta) = switch (tab) {
      EventsTab.upcoming => (
          l10n.eventsEmptyUpcomingTitle,
          l10n.eventsEmptyUpcomingBody,
          true,
        ),
      EventsTab.past => (
          l10n.eventsEmptyPastTitle,
          l10n.eventsEmptyPastBody,
          false,
        ),
      EventsTab.community => (
          l10n.eventsEmptyCommunityTitle,
          l10n.eventsEmptyCommunityBody,
          true,
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 64,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_outlined,
            size: 48,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          AppSpacing.vGapMd,
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapXs,
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (cta) ...[
            AppSpacing.vGapLg,
            AppButton(
              key: const Key('events-empty-create'),
              label: l10n.eventCreateCta,
              variant: AppButtonVariant.solid,
              size: AppButtonSize.sm,
              minWidth: 0,
              onPressed: () => context.push(AppRoutes.createEvent),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: 3,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SkeletonShimmer(
          child: SkeletonBox(
            height: 112,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.tile)),
          ),
        ),
      ),
    );
  }
}

/// Month grid (web `MonthCalendar`): a surface-container-low panel with
/// round prev/next buttons, the month title (+ "Today" when away from the
/// current month), weekday labels and day circles with an event dot.
/// Tapping a day with events opens its agenda in a bottom sheet.
class EventCalendarView extends ConsumerStatefulWidget {
  const EventCalendarView({super.key, this.today});

  /// Overrides "now" (tests).
  final DateTime? today;

  @override
  ConsumerState<EventCalendarView> createState() => _EventCalendarViewState();
}

class _EventCalendarViewState extends ConsumerState<EventCalendarView> {
  late final DateTime _today =
      DateUtils.dateOnly(widget.today ?? DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);

  List<Event> _eventsOn(List<Event> events, DateTime day) => events
      .where((e) => DateUtils.isSameDay(e.scheduledAt.toLocal(), day))
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _showDay(DateTime day, List<Event> events) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Text(
                  l10n.calendarEventsOn(
                    DateFormat.MMMMEEEEd(locale).format(day),
                  ),
                  style: AppTypography.titleLarge,
                ),
              ),
              Flexible(
                child: events.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          l10n.calendarNoEventsDay,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        children: [
                          for (final e in events)
                            EventCard(
                              event: e,
                              margin: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                0,
                                AppSpacing.xl,
                                AppSpacing.md,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final events = ref.watch(calendarEventsProvider(_month));
    final list = events.valueOrNull ?? const <Event>[];
    // Sunday-first grid of whole weeks covering the month (web monthGrid).
    final first = DateTime(_month.year, _month.month);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final cellCount = ((first.weekday % 7) + daysInMonth + 6) ~/ 7 * 7;
    final isCurrentMonth =
        _month.year == _today.year && _month.month == _today.month;
    return Container(
      key: const Key('events-calendar'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.panel)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RoundButton(
                key: const Key('calendar-prev'),
                icon: Icons.chevron_left_rounded,
                tooltip: l10n.calendarPrevMonth,
                onPressed: () => _changeMonth(-1),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat.yMMMM(locale).format(_month),
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isCurrentMonth) ...[
                      AppSpacing.hGapSm,
                      GestureDetector(
                        key: const Key('calendar-today'),
                        onTap: () => setState(
                          () => _month = DateTime(_today.year, _today.month),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppSpacing.borderRadiusFull,
                          ),
                          child: Text(
                            l10n.calendarToday,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _RoundButton(
                key: const Key('calendar-next'),
                icon: Icons.chevron_right_rounded,
                tooltip: l10n.calendarNextMonth,
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          AppSpacing.vGapLg,
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    // 2023-01-01 was a Sunday.
                    DateFormat.E(locale)
                        .format(DateTime(2023, 1, 1 + i))
                        .toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTypography.overline.copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
          AppSpacing.vGapXs,
          if (events.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < cellCount; i++)
                _DayCell(
                  day: DateTime(start.year, start.month, start.day + i),
                  month: _month,
                  today: _today,
                  events: _eventsOn(
                    list,
                    DateTime(start.year, start.month, start.day + i),
                  ),
                  onTap: _showDay,
                ),
            ],
          ),
          if (events.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                localizedError(l10n, events.error!),
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.today,
    required this.events,
    required this.onTap,
  });

  final DateTime day;
  final DateTime month;
  final DateTime today;
  final List<Event> events;
  final void Function(DateTime, List<Event>) onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(day, today);
    final inMonth = day.month == month.month && day.year == month.year;
    final has = events.isNotEmpty;
    final fg = isToday
        ? AppColors.onPrimary
        : inMonth
            ? AppColors.onSurface
            : AppColors.onSurfaceVariant.withValues(alpha: 0.4);
    return Material(
      color: isToday ? AppColors.primary : AppColors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('calendar-day-${day.month}-${day.day}'),
        onTap: has ? () => onTap(day, events) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: AppTypography.bodyMedium.copyWith(
                fontFamily: AppTypography.titleMedium.fontFamily,
                color: fg,
                fontWeight: isToday
                    ? FontWeight.w800
                    : has
                        ? FontWeight.w700
                        : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !has
                    ? AppColors.transparent
                    : isToday
                        ? AppColors.onPrimary
                        : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.surfaceContainerHigh,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, color: AppColors.onSurface),
            ),
          ),
        ),
      );
}
