import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/presentation/widgets/event_card.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/features/home/domain/feed_item_model.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/home_widgets.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/post_card.dart';
import 'package:meeple_hearth/features/home/providers/feed_provider.dart';
import 'package:meeple_hearth/features/matching/providers/matching_provider.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Home (SCREENS §4): greeting, match suggestions, upcoming events and the
/// infinite activity feed.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Fetch the next page at 80% scroll depth (SCREENS §4.6).
  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent * 0.8) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(matchSuggestionsProvider)
      ..invalidate(eventsListProvider(EventScope.mine));
    await ref.read(feedNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final feed = ref.watch(feedNotifierProvider);
    final state = feed.valueOrNull;

    return Scaffold(
      appBar: MeepleBrandBar(
        leading: IconButton(
          key: const Key('home-search'),
          tooltip: l10n.commonSearch,
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push(AppRoutes.search),
        ),
        actions: const [NotificationBell()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _Greeting()),
            const SliverToBoxAdapter(child: _MatchSuggestions()),
            const SliverToBoxAdapter(child: _UpcomingEvents()),
            if (state?.cachedAt != null)
              SliverToBoxAdapter(
                child: StaleDataBanner(cachedAt: state!.cachedAt!),
              ),
            SliverToBoxAdapter(child: SectionHeader(title: l10n.homeFeedTitle)),
            ...feed.when(
              loading: () => [
                SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (_, __) => const PostCardSkeleton(),
                ),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(
                  child: ErrorState(
                    error: e,
                    title: l10n.homeFeedError,
                    onRetry: () => ref.invalidate(feedNotifierProvider),
                  ),
                ),
              ],
              data: (s) {
                final items =
                    s.items.where((i) => i is! FeedUnknownItem).toList();
                if (items.isEmpty) {
                  return [const SliverToBoxAdapter(child: _EmptyFeed())];
                }
                return [
                  SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => switch (items[i]) {
                      final FeedPostItem p => PostCard(post: p.post),
                      final FeedActivityItem a => ActivityCard(item: a),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                  SliverToBoxAdapter(
                    child: ListFooter(
                      isLoading: s.isLoadingMore,
                      hasMore: s.hasMore,
                      error: s.loadMoreError,
                      onRetry: () =>
                          ref.read(feedNotifierProvider.notifier).loadMore(),
                    ),
                  ),
                ];
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final hour = DateTime.now().hour;
    final name = user?.displayName ?? '';
    final greeting = hour >= 6 && hour < 12
        ? l10n.greetingMorning(name)
        : hour >= 12 && hour < 18
            ? l10n.greetingAfternoon(name)
            : l10n.greetingEvening(name);
    final next = _nextEvent(ref);
    String subtitle;
    if (next == null) {
      subtitle = l10n.greetingNoEvents;
    } else {
      final days = DateUtils.dateOnly(next.scheduledAt.toLocal())
          .difference(DateUtils.dateOnly(DateTime.now()))
          .inDays;
      subtitle = l10n.greetingNextSession(days);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: AppTypography.headlineLarge),
          AppSpacing.vGapXs,
          Text(
            subtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soonest upcoming event the user is part of.
Event? _nextEvent(WidgetRef ref) {
  final events = _myUpcoming(ref);
  return events.isEmpty ? null : events.first;
}

List<Event> _myUpcoming(WidgetRef ref) {
  final now = DateTime.now();
  final events = ref.watch(eventsListProvider(EventScope.mine)).valueOrNull?.data ??
      const <Event>[];
  return events
      .where((e) => e.scheduledAt.isAfter(now) && !e.isCancelled)
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}

class _MatchSuggestions extends ConsumerWidget {
  const _MatchSuggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(matchSuggestionsProvider).valueOrNull ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.homeMatchesTitle,
          actionLabel: groups.length > 1 ? l10n.homeMoreMatches(groups.length - 1) : null,
          onAction: () => context.push(AppRoutes.matching),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (_, __) => AppSpacing.hGapMd,
            itemBuilder: (context, i) => MatchSuggestionCard(
              group: groups[i],
              width: MediaQuery.sizeOf(context).width - AppSpacing.lg * 2 -
                  (groups.length > 1 ? 40 : 0),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpcomingEvents extends ConsumerWidget {
  const _UpcomingEvents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = _myUpcoming(ref);
    // Hidden entirely when there is nothing upcoming (SCREENS §4.5).
    if (events.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.homeUpcomingTitle,
          actionLabel: l10n.homeViewCalendar,
          onAction: () => context.go('${AppRoutes.events}?view=calendar'),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => AppSpacing.hGapMd,
            itemBuilder: (_, i) => EventMiniCard(event: events[i]),
          ),
        ),
      ],
    );
  }
}

class _EmptyFeed extends ConsumerWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(authNotifierProvider).valueOrNull;
    final friends = me == null
        ? null
        : ref.watch(userStatsProvider(me.id)).valueOrNull?.friends;
    if (friends == 0) {
      return EmptyState(
        icon: Icons.waving_hand_outlined,
        title: l10n.homeEmptyNoFriendsTitle,
        subtitle: l10n.homeEmptyNoFriendsBody,
        actionLabel: l10n.homeFindFriends,
        onAction: () => context.push(AppRoutes.friends),
      );
    }
    return EmptyState(
      icon: Icons.local_cafe_outlined,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homeEmptyBody,
      actionLabel: l10n.homeCreatePost,
      onAction: () => context.push(AppRoutes.createPost),
    );
  }
}
