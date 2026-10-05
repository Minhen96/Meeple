import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_card.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';

/// Client-side filters of the All Games tab (SCREENS §5.2, MVP).
enum PlayerFilter { two, three, four, five }

enum DurationFilter { under30, from30to60, from1to2h, over2h }

enum WeightFilter { light, medium, heavy }

/// Whether [game] passes the selected filters (null = no filter).
bool gameMatchesFilters(
  Game game, {
  PlayerFilter? players,
  DurationFilter? duration,
  WeightFilter? weight,
}) {
  if (players != null) {
    final need = PlayerFilter.values.indexOf(players) + 2;
    final max = game.maxPlayers ?? game.minPlayers;
    if (max == null || max < need) return false;
  }
  if (duration != null) {
    final t = game.minPlayTimeMinutes;
    if (t == null) return false;
    final ok = switch (duration) {
      DurationFilter.under30 => t < 30,
      DurationFilter.from30to60 => t >= 30 && t <= 60,
      DurationFilter.from1to2h => t > 60 && t <= 120,
      DurationFilter.over2h => t > 120,
    };
    if (!ok) return false;
  }
  if (weight != null) {
    final w = game.complexity;
    if (w == null) return false;
    final ok = switch (weight) {
      WeightFilter.light => w < 2,
      WeightFilter.medium => w >= 2 && w < 3.5,
      WeightFilter.heavy => w >= 3.5,
    };
    if (!ok) return false;
  }
  return true;
}

/// Library (SCREENS §5): All Games | My Collection | Wishlist | Favorites.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.initialTab});

  /// `all` | `collection` | `wishlist` | `favorites`.
  final String? initialTab;

  static int tabIndexOf(String? name) => switch (name) {
        'collection' || 'owned' => 1,
        'wishlist' || 'wishlisted' => 2,
        'favorites' || 'favorited' => 3,
        _ => 0,
      };

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: LibraryScreen.tabIndexOf(widget.initialTab),
  );
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tabs.animateTo(LibraryScreen.tabIndexOf(widget.initialTab));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: MeepleAppBar(title: l10n.libraryTitle),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: TextField(
              key: const Key('library-search'),
              controller: _search,
              onChanged: _onQueryChanged,
              onTap: () {
                if (_tabs.index != 0) _tabs.animateTo(0);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.librarySearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.commonClose,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: AppColors.transparent,
            tabs: [
              Tab(text: l10n.libraryTabAll),
              Tab(text: l10n.libraryTabCollection),
              Tab(text: l10n.libraryTabWishlist),
              Tab(text: l10n.libraryTabFavorites),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AllGamesTab(query: _query),
                _CollectionTab(
                  filter: CollectionFilter.owned,
                  onBrowse: () => _tabs.animateTo(0),
                ),
                _CollectionTab(
                  filter: CollectionFilter.wishlisted,
                  onBrowse: () => _tabs.animateTo(0),
                ),
                _CollectionTab(
                  filter: CollectionFilter.favorited,
                  onBrowse: () => _tabs.animateTo(0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: AppSpacing.md,
  mainAxisSpacing: AppSpacing.lg,
  childAspectRatio: 0.62,
);

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({this.count = 9});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: _gridDelegate,
      itemCount: count,
      itemBuilder: (_, __) => const GameCardSkeleton(),
    );
  }
}

class _AllGamesTab extends ConsumerStatefulWidget {
  const _AllGamesTab({required this.query});

  final String query;

  @override
  ConsumerState<_AllGamesTab> createState() => _AllGamesTabState();
}

class _AllGamesTabState extends ConsumerState<_AllGamesTab>
    with AutomaticKeepAliveClientMixin {
  PlayerFilter? _players;
  DurationFilter? _duration;
  WeightFilter? _weight;

  @override
  bool get wantKeepAlive => true;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
      ref.read(gameSearchNotifierProvider(widget.query).notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final results = ref.watch(gameSearchNotifierProvider(widget.query));
    final chips = <Widget>[
      for (final p in PlayerFilter.values)
        _FilterChip(
          label: l10n.filterPlayers(PlayerFilter.values.indexOf(p) + 2),
          selected: _players == p,
          onTap: () => setState(() => _players = _players == p ? null : p),
        ),
      for (final d in DurationFilter.values)
        _FilterChip(
          label: switch (d) {
            DurationFilter.under30 => l10n.filterUnder30,
            DurationFilter.from30to60 => l10n.filter30to60,
            DurationFilter.from1to2h => l10n.filter1to2h,
            DurationFilter.over2h => l10n.filterOver2h,
          },
          selected: _duration == d,
          onTap: () => setState(() => _duration = _duration == d ? null : d),
        ),
      for (final w in WeightFilter.values)
        _FilterChip(
          label: switch (w) {
            WeightFilter.light => l10n.filterLight,
            WeightFilter.medium => l10n.filterMedium,
            WeightFilter.heavy => l10n.filterHeavy,
          },
          selected: _weight == w,
          onTap: () => setState(() => _weight = _weight == w ? null : w),
        ),
    ];
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => AppSpacing.hGapSm,
            itemBuilder: (_, i) => Center(child: chips[i]),
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const _GridSkeleton(),
            error: (e, _) => ErrorState(
              error: e,
              title: l10n.libraryDatabaseUnavailable,
              onRetry: () =>
                  ref.invalidate(gameSearchNotifierProvider(widget.query)),
            ),
            data: (page) {
              final games = page.content
                  .where(
                    (g) => gameMatchesFilters(
                      g,
                      players: _players,
                      duration: _duration,
                      weight: _weight,
                    ),
                  )
                  .toList();
              if (games.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off_rounded,
                  title: widget.query.isEmpty
                      ? l10n.libraryNoGames
                      : l10n.libraryNoResults(widget.query),
                  subtitle: l10n.libraryNoResultsHint,
                );
              }
              return NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    96,
                  ),
                  gridDelegate: _gridDelegate,
                  itemCount: games.length,
                  itemBuilder: (_, i) => _OwnedBadgeCard(game: games[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Game card with the viewer's collection badges overlaid.
class _OwnedBadgeCard extends ConsumerWidget {
  const _OwnedBadgeCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry =
        ref.watch(collectionNotifierProvider).valueOrNull?.entryFor(game.id);
    return GameCard(
      game: game,
      trailing: entry == null ? null : CollectionBadges(entry: entry),
      onTap: () => context.push(AppRoutes.gameDetail(game.id)),
    );
  }
}

class _CollectionTab extends ConsumerWidget {
  const _CollectionTab({required this.filter, required this.onBrowse});

  final CollectionFilter filter;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final collection = ref.watch(collectionNotifierProvider);
    return collection.when(
      loading: () => const _GridSkeleton(count: 6),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(collectionNotifierProvider),
      ),
      data: (state) {
        final entries = state.filtered(filter);
        return RefreshIndicator(
          onRefresh: () => ref.read(collectionNotifierProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (state.cachedAt != null)
                SliverToBoxAdapter(
                  child: StaleDataBanner(cachedAt: state.cachedAt!),
                ),
              if (entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: switch (filter) {
                    CollectionFilter.wishlisted => EmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: l10n.libraryEmptyWishlistTitle,
                        subtitle: l10n.libraryEmptyWishlistBody,
                        actionLabel: l10n.libraryBrowseGames,
                        onAction: onBrowse,
                      ),
                    CollectionFilter.favorited => EmptyState(
                        icon: Icons.star_border_rounded,
                        title: l10n.libraryEmptyFavoritesTitle,
                        subtitle: l10n.libraryEmptyFavoritesBody,
                      ),
                    _ => EmptyState(
                        icon: Icons.shelves,
                        title: l10n.libraryEmptyCollectionTitle,
                        subtitle: l10n.libraryEmptyCollectionBody,
                        actionLabel: l10n.libraryBrowseGames,
                        onAction: onBrowse,
                      ),
                  },
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    96,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: _gridDelegate,
                    itemCount: entries.length,
                    itemBuilder: (_, i) => GameCard(
                      game: entries[i].game,
                      trailing: CollectionBadges(entry: entries[i]),
                      onTap: () =>
                          context.push(AppRoutes.gameDetail(entries[i].gameId)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Owned / wishlist / favourite icons shown on a card corner.
class CollectionBadges extends StatelessWidget {
  const CollectionBadges({super.key, required this.entry});

  final UserGame entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final icons = [
      if (entry.isOwned) (Icons.shelves, l10n.badgeOwned),
      if (entry.isWishlisted) (Icons.bookmark_rounded, l10n.badgeWishlisted),
      if (entry.isFavorited) (Icons.star_rounded, l10n.badgeFavorited),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.inverseSurface.withValues(alpha: 0.8),
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, label) in icons)
            Tooltip(
              message: label,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(icon, size: 14, color: AppColors.primaryContainer),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      backgroundColor: AppColors.surfaceContainerHighest,
      selectedColor: AppColors.secondaryContainer,
      labelStyle: AppTypography.labelLarge.copyWith(
        color: selected
            ? AppColors.onSecondaryContainer
            : AppColors.onSurfaceVariant,
      ),
    );
  }
}
