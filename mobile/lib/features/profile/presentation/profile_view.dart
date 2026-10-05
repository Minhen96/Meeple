import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_card.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';

/// Shared profile layout (SCREENS §8): hero, stats bento, actions, favourite
/// games and Posts / Tagged / Collection tabs.
class ProfileView extends ConsumerWidget {
  const ProfileView({
    super.key,
    required this.user,
    required this.actions,
    required this.isSelf,
  });

  final User user;
  final Widget actions;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(child: _Header(user: user)),
          SliverToBoxAdapter(child: _StatsBento(userId: user.id)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: actions,
            ),
          ),
          SliverToBoxAdapter(child: _FavoriteGames(userId: user.id)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsDelegate(
              TabBar(
                dividerColor: AppColors.transparent,
                tabs: [
                  Tab(text: l10n.profileTabPosts),
                  Tab(text: l10n.profileTabTagged),
                  Tab(text: l10n.profileTabCollection),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _PostsGrid(
              key: const Key('profile-posts'),
              state: ref.watch(userPostsProvider(user.id)),
              onRetry: () => ref.invalidate(userPostsProvider(user.id)),
              onLoadMore: () =>
                  ref.read(userPostsProvider(user.id).notifier).loadMore(),
              emptyIcon: Icons.photo_library_outlined,
              emptyTitle: l10n.profileNoPosts,
            ),
            _PostsGrid(
              key: const Key('profile-tagged'),
              state: ref.watch(taggedPostsProvider(user.id)),
              onRetry: () => ref.invalidate(taggedPostsProvider(user.id)),
              onLoadMore: () =>
                  ref.read(taggedPostsProvider(user.id).notifier).loadMore(),
              emptyIcon: Icons.sell_outlined,
              emptyTitle: l10n.profileTaggedTitle,
              emptySubtitle: l10n.profileTaggedBody,
            ),
            _CollectionList(userId: user.id, isSelf: isSelf),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: 3 * math.pi / 180,
                child: AppAvatar(
                  imageUrl: user.avatarUrl,
                  displayName: user.displayName,
                  size: AvatarSize.xxl,
                ),
              ),
              if (user.isVerified)
                Positioned(
                  right: -4,
                  bottom: 4,
                  child: Tooltip(
                    message: l10n.profileVerified,
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primaryContainer,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.vGapMd,
          Text(
            user.deleted ? l10n.commonDeletedUser : user.displayName,
            style: AppTypography.displaySmall,
            textAlign: TextAlign.center,
          ),
          Text('@${user.username}', style: AppTypography.bodyMedium),
          if (user.location != null && user.location!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  Text(user.location!, style: AppTypography.bodySmall),
                ],
              ),
            ),
          if (user.bio != null && user.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                user.bio!,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsBento extends ConsumerWidget {
  const _StatsBento({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(userStatsProvider(userId)).valueOrNull;
    final cells = [
      (l10n.statGamesOwned, stats?.gamesOwned),
      (l10n.statSessions, stats?.sessions),
      (l10n.statFriends, stats?.friends),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) AppSpacing.hGapMd,
                Expanded(
                  child: InkWell(
                    borderRadius: AppSpacing.borderRadiusXxl,
                    onTap: i == 2 ? () => context.push(AppRoutes.friends) : null,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppSpacing.borderRadiusXxl,
                        // Middle card emphasised (DESIGN stats bento).
                        border: i == 1
                            ? const Border(
                                left: BorderSide(color: AppColors.primary, width: 4),
                              )
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            cells[i].$1.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                          Text(
                            cells[i].$2?.toString() ?? '–',
                            style: AppTypography.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (stats?.mostPlayedGame != null || stats?.favoriteCategory != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (stats!.mostPlayedGame != null)
                    Chip(
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                      label: Text(
                        l10n.statMostPlayed(
                          stats.mostPlayedGame!.title,
                          stats.mostPlayedGame!.playCount,
                        ),
                      ),
                    ),
                  if (stats.favoriteCategory != null)
                    Chip(
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      avatar: const Icon(Icons.category_outlined, size: 16),
                      label: Text(stats.favoriteCategory!),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteGames extends ConsumerWidget {
  const _FavoriteGames({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(userFavoritesProvider(userId)).valueOrNull;
    if (favorites == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(l10n.profileFavoriteGames, style: AppTypography.titleMedium),
        ),
        if (favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(l10n.profileNoFavorites, style: AppTypography.bodySmall),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, __) => AppSpacing.hGapMd,
              itemBuilder: (_, i) => SizedBox(
                width: 96,
                child: GameCard(
                  game: favorites[i].game,
                  onTap: () =>
                      context.push(AppRoutes.gameDetail(favorites[i].gameId)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A 3-column grid of post thumbnails over a paged post list.
class _PostsGrid extends StatelessWidget {
  const _PostsGrid({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
  });

  final AsyncValue<PagedState<Post>> state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(error: e, onRetry: onRetry),
      data: (s) => s.items.isEmpty
          ? EmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle)
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
                  onLoadMore();
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  96,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppSpacing.xs,
                  mainAxisSpacing: AppSpacing.xs,
                ),
                itemCount: s.items.length,
                itemBuilder: (_, i) => _PostThumb(post: s.items[i]),
              ),
            ),
    );
  }
}

class _PostThumb extends StatelessWidget {
  const _PostThumb({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('post-thumb-${post.id}'),
      onTap: () => context.push(AppRoutes.postDetail(post.id)),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusLg,
        child: post.imageUrls.isNotEmpty
            ? CachedNetworkImage(imageUrl: post.imageUrls.first, fit: BoxFit.cover)
            : ColoredBox(
                color: AppColors.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    post.caption,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall,
                  ),
                ),
              ),
      ),
    );
  }
}

class _CollectionList extends ConsumerWidget {
  const _CollectionList({required this.userId, required this.isSelf});

  final String userId;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(userCollectionProvider(userId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(userCollectionProvider(userId)),
          ),
          data: (games) => games.isEmpty
              ? EmptyState(
                  icon: Icons.shelves,
                  title: l10n.libraryEmptyCollectionTitle,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final g in games.take(10))
                      GameListTile(
                        game: g.game,
                        subtitle: l10n.gamePlays(g.playCount),
                        onTap: () => context.push(AppRoutes.gameDetail(g.gameId)),
                      ),
                    if (isSelf)
                      TextButton(
                        onPressed: () =>
                            context.go('${AppRoutes.library}?filter=collection'),
                        child: Text(l10n.commonSeeAll),
                      ),
                  ],
                ),
        );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: AppColors.background, child: tabBar);

  @override
  bool shouldRebuild(_TabsDelegate oldDelegate) => false;
}
