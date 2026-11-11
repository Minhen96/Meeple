import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/paged_state.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';

/// Shared profile layout (SCREENS §8) — the web `ProfileHero`, `StatsBento`
/// and `ProfileContent`: tilted square avatar, name, @handle, bio, the
/// [actions] row, stat tiles, highlight rows, Favorite Games and the
/// Posts / Tagged / Collection pill tabs. One scroll view like the web page.
class ProfileView extends ConsumerStatefulWidget {
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
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  int _tab = 0;

  String get _id => widget.user.id;

  void _loadMore() {
    switch (_tab) {
      case 0:
        ref.read(userPostsProvider(_id).notifier).loadMore();
      case 1:
        ref.read(taggedPostsProvider(_id).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final own = widget.isSelf;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 &&
            n.metrics.maxScrollExtent > 0 &&
            n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverList.list(
              children: [
                ProfileHero(user: widget.user, actions: widget.actions),
                const SizedBox(height: AppSpacing.xxl),
                ProfileStatsBento(userId: _id, friendsTappable: own),
                _FavoriteGames(userId: _id, own: own),
                ProfileTabs(
                  index: _tab,
                  labels: [
                    l10n.profileTabPosts,
                    l10n.profileTabTagged,
                    l10n.profileTabCollection,
                  ],
                  onChanged: (i) => setState(() => _tab = i),
                ),
                AppSpacing.vGapLg,
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              120,
            ),
            sliver: switch (_tab) {
              0 => _PostsPanel(
                  key: const Key('profile-posts'),
                  state: ref.watch(userPostsProvider(_id)),
                  onRetry: () => ref.invalidate(userPostsProvider(_id)),
                  empty: own ? l10n.profileNoPostsOwn : l10n.profileNoPosts,
                ),
              1 => _PostsPanel(
                  key: const Key('profile-tagged'),
                  state: ref.watch(taggedPostsProvider(_id)),
                  onRetry: () => ref.invalidate(taggedPostsProvider(_id)),
                  empty: l10n.profileNoTagged,
                ),
              _ => SliverToBoxAdapter(
                  child: _CollectionPanel(userId: _id, own: own),
                ),
            },
          ),
        ],
      ),
    );
  }
}

/// Web `ProfileHero`: 112px tilted rounded-square avatar with a surface ring
/// and soft shadow, verified badge, name, @username, location, bio, actions.
class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, required this.user, required this.actions});

  final User user;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = user.deleted ? l10n.commonDeletedUser : user.displayName;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.rotate(
              angle: 3 * math.pi / 180,
              child: Container(
                key: const Key('profile-avatar'),
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: AppSpacing.borderRadiusLg,
                  child: SquareAvatar(
                    imageUrl: user.deleted ? null : user.avatarUrl,
                    name: name,
                    size: 112,
                  ),
                ),
              ),
            ),
            if (user.isVerified)
              Positioned(
                right: -8,
                bottom: -8,
                child: Tooltip(
                  message: l10n.profileVerified,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          name,
          style: AppTypography.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '@${user.username}',
          style: AppTypography.bodyMedium
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (user.location != null && user.location!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Opacity(
            opacity: 0.7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                AppSpacing.hGapXs,
                Text(
                  user.location!.toUpperCase(),
                  style:
                      AppTypography.labelSmall.weight(FontWeight.w700).copyWith(
                            letterSpacing: 1,
                            color: AppColors.onSurfaceVariant,
                          ),
                ),
              ],
            ),
          ),
        ],
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              user.bio!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.625,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: actions,
        ),
      ],
    );
  }
}

/// Square avatar (photo or initials on primary-fixed) — the web `Avatar`
/// with `size="none"` inside the tilted profile frame.
class SquareAvatar extends StatelessWidget {
  const SquareAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.size,
  });

  final String? imageUrl;
  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      width: size,
      height: size,
      color: AppColors.primaryFixed,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: AppTypography.titleSmall.copyWith(
          color: AppColors.onPrimaryFixed,
        ),
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return initials;
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => initials,
      errorWidget: (_, __, ___) => initials,
    );
  }
}

/// Web `StatsBento`: Owned | Sessions (primary tint) | Friends tiles, then
/// highlight rows (most played, favourite category, plays most with).
class ProfileStatsBento extends ConsumerWidget {
  const ProfileStatsBento({
    super.key,
    required this.userId,
    this.friendsTappable = false,
  });

  final String userId;

  /// Own profile: the Friends tile opens the friends list.
  final bool friendsTappable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(userStatsProvider(userId)).valueOrNull;
    Widget tile(String label, int? value,
            {bool accent = false, VoidCallback? onTap}) =>
        Expanded(
          child: Material(
            color: accent
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surfaceContainerLow,
            borderRadius: AppSpacing.borderRadiusLg,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Opacity(
                      opacity: accent ? 0.8 : 0.7,
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall
                            .weight(FontWeight.w700)
                            .copyWith(
                              letterSpacing: 1,
                              color: accent
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                      ),
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      value?.toString() ?? '–',
                      style: AppTypography.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    final highlights = <(IconData, Color, String, VoidCallback?)>[
      if (stats?.mostPlayedGame != null)
        (
          Icons.emoji_events_outlined,
          AppColors.primary,
          l10n.statMostPlayed(
            stats!.mostPlayedGame!.title,
            stats.mostPlayedGame!.playCount,
          ),
          () =>
              context.push(AppRoutes.gameDetail(stats.mostPlayedGame!.gameId)),
        ),
      if (stats?.favoriteCategory != null)
        (
          Icons.category_outlined,
          AppColors.secondary,
          l10n.statFavoriteCategory(stats!.favoriteCategory!),
          null,
        ),
      if (stats?.mostPlayedWith != null)
        (
          Icons.group_outlined,
          AppColors.tertiary,
          l10n.statMostPlayedWith(
            stats!.mostPlayedWith!.displayName,
            stats.mostPlayedWith!.sharedSessions,
          ),
          () =>
              context.push(AppRoutes.userProfile(stats.mostPlayedWith!.userId)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            tile(l10n.statGamesOwned, stats?.gamesOwned),
            AppSpacing.hGapMd,
            tile(l10n.statSessions, stats?.sessions, accent: true),
            AppSpacing.hGapMd,
            tile(
              l10n.statFriends,
              stats?.friends,
              onTap: friendsTappable
                  ? () => context.push(AppRoutes.friends)
                  : null,
            ),
          ],
        ),
        AppSpacing.vGapLg,
        for (final (icon, color, text, onTap) in highlights) ...[
          Material(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        text,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppSpacing.vGapSm,
        ],
        SizedBox(height: highlights.isEmpty ? AppSpacing.lg : AppSpacing.xl),
      ],
    );
  }
}

class _FavoriteGames extends ConsumerWidget {
  const _FavoriteGames({required this.userId, required this.own});

  final String userId;
  final bool own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(userFavoritesProvider(userId)).valueOrNull;
    if (favorites == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.profileFavoriteGames,
                  style: AppTypography.headlineSmall,
                ),
              ),
              if (own && favorites.isNotEmpty)
                InkWell(
                  key: const Key('profile-favorites-see-all'),
                  borderRadius: AppSpacing.borderRadiusFull,
                  onTap: () =>
                      context.go('${AppRoutes.library}?filter=favorites'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Row(
                      children: [
                        Text(
                          l10n.commonSeeAll,
                          style: AppTypography.titleSmall
                              .copyWith(color: AppColors.primary),
                        ),
                        AppSpacing.hGapXs,
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.vGapLg,
          if (favorites.isEmpty)
            ProfilePanelMessage(
              own ? l10n.profileNoFavorites : l10n.profileNoFavoritesOther,
              padding: const EdgeInsets.all(AppSpacing.xl),
            )
          else
            SizedBox(
              height: 212,
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                separatorBuilder: (_, __) => AppSpacing.hGapLg,
                itemBuilder: (_, i) => _FavoriteCard(game: favorites[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.game});

  final UserGame game;

  @override
  Widget build(BuildContext context) {
    final cover = game.game.coverUrl;
    const placeholder = Center(
      child: Opacity(
        opacity: 0.3,
        child: Icon(Icons.casino_outlined,
            size: 30, color: AppColors.onSurfaceVariant),
      ),
    );
    return GestureDetector(
      key: ValueKey('favorite-${game.gameId}'),
      onTap: () => context.push(AppRoutes.gameDetail(game.gameId)),
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 176,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: AppSpacing.borderRadiusLg,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: cover == null
                  ? placeholder
                  : CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      width: 128,
                      errorWidget: (_, __, ___) => placeholder,
                    ),
            ),
            AppSpacing.vGapSm,
            Text(
              game.game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Web profile tab bar: a surface-container-low pill holding three pill tabs
/// (icon + label); the active one is white with primary text.
class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  static const _icons = [
    Icons.grid_on_rounded,
    Icons.sell_outlined,
    Icons.inventory_2_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) AppSpacing.hGapXs,
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: i == index
                          ? AppColors.surfaceContainerLowest
                          : AppColors.transparent,
                      borderRadius: AppSpacing.borderRadiusFull,
                      boxShadow: i == index
                          ? const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _icons[i % _icons.length],
                          size: 18,
                          color: i == index
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall
                                .weight(FontWeight.w700)
                                .copyWith(
                                  color: i == index
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Web in-panel message: `text-sm text-center py-10 bg-surface-container-low
/// rounded-2xl`.
class ProfilePanelMessage extends StatelessWidget {
  const ProfilePanelMessage(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: 40,
    ),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium
            .copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

/// A 3-column grid of post thumbnails over a paged post list (sliver).
class _PostsPanel extends StatelessWidget {
  const _PostsPanel({
    super.key,
    required this.state,
    required this.onRetry,
    required this.empty,
  });

  final AsyncValue<PagedState<Post>> state;
  final VoidCallback onRetry;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: ErrorState(error: e, onRetry: onRetry),
      ),
      data: (s) => s.items.isEmpty
          ? SliverToBoxAdapter(child: ProfilePanelMessage(empty))
          : SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: s.items.length,
              itemBuilder: (_, i) => _PostThumb(post: s.items[i]),
            ),
    );
  }
}

class _PostThumb extends StatelessWidget {
  const _PostThumb({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final cover = post.imageUrls.isNotEmpty
        ? post.imageUrls.first
        : post.game?.thumbnailUrl;
    final caption = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          post.caption,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('post-thumb-${post.id}'),
        onTap: () => context.push(AppRoutes.postDetail(post.id)),
        child: cover == null
            ? caption
            : Opacity(
                opacity: post.imageUrls.isNotEmpty ? 1 : 0.8,
                child: CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => caption,
                ),
              ),
      ),
    );
  }
}

class _CollectionPanel extends ConsumerWidget {
  const _CollectionPanel({required this.userId, required this.own});

  static const _preview = 8;

  final String userId;
  final bool own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!own) {
      final status =
          ref.watch(friendStatusNotifierProvider(userId)).valueOrNull;
      if (status != null && status.status != FriendshipStatus.friends) {
        return ProfilePanelMessage(l10n.profileCollectionFriendsOnly);
      }
    }
    return ref.watch(userCollectionProvider(userId)).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(userCollectionProvider(userId)),
          ),
          data: (games) {
            final owned = games.where((g) => g.isOwned).toList();
            if (owned.isEmpty) {
              return ProfilePanelMessage(
                own ? l10n.profileNoCollectionOwn : l10n.profileNoCollection,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final g in owned.take(_preview)) ...[
                  _CollectionRow(game: g),
                  AppSpacing.vGapSm,
                ],
                if (own)
                  Center(
                    child: InkWell(
                      borderRadius: AppSpacing.borderRadiusFull,
                      onTap: () =>
                          context.go('${AppRoutes.library}?filter=collection'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.commonSeeAll,
                              style: AppTypography.titleSmall
                                  .copyWith(color: AppColors.primary),
                            ),
                            AppSpacing.hGapXs,
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.game});

  final UserGame game;

  @override
  Widget build(BuildContext context) {
    final cover = game.game.coverUrl;
    const placeholder = Opacity(
      opacity: 0.4,
      child: Icon(Icons.casino_outlined, color: AppColors.onSurfaceVariant),
    );
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.gameDetail(game.gameId)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: cover == null
                    ? placeholder
                    : CachedNetworkImage(
                        imageUrl: cover,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => placeholder,
                      ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall,
                    ),
                    Text(
                      context.l10n.gamePlays(game.playCount),
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.onSurfaceVariant),
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
}
