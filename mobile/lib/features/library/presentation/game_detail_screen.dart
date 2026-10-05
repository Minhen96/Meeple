import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/ai/presentation/ai_rules_sheet.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/post_card.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/how_to_play_section.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/play_sheets.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Game detail (SCREENS §5.4): hero, info bar, collection actions, AI Rules
/// Assistant, How to Play and Overview / Reviews / Sessions / Friends tabs.
class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(gameDetailProvider(gameId));
    return detail.when(
      loading: () => const _DetailSkeleton(),
      error: (e, _) => Scaffold(
        appBar: const MeepleAppBar(
          showBackButton: true,
          fallbackRoute: AppRoutes.library,
        ),
        body: e is NotFoundException
            ? EmptyState(
                icon: Icons.search_off_rounded,
                title: context.l10n.gameNotFound,
                actionLabel: context.l10n.gameBackToLibrary,
                onAction: () => context.go(AppRoutes.library),
              )
            : ErrorState(
                error: e,
                onRetry: () => ref.invalidate(gameDetailProvider(gameId)),
              ),
      ),
      data: (result) => _GameDetailBody(
        game: result.data,
        cachedAt: result.cachedAt,
      ),
    );
  }
}

class _GameDetailBody extends ConsumerWidget {
  const _GameDetailBody({required this.game, this.cachedAt});

  final Game game;
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              backgroundColor: AppColors.glassBackground,
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.library),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _Hero(game: game),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cachedAt != null) StaleDataBanner(cachedAt: cachedAt!),
                  _InfoBar(game: game),
                  _Actions(game: game),
                  HowToPlaySection(game: game),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: AppColors.transparent,
                  tabs: [
                    Tab(text: l10n.gameTabOverview),
                    Tab(text: l10n.gameTabReviews),
                    Tab(text: l10n.gameTabSessions),
                    Tab(text: l10n.gameTabFriends),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(game: game),
              _ReviewsTab(gameId: game.id),
              _SessionsTab(gameId: game.id),
              _FriendsTab(gameId: game.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final byline = [
      if (game.designers.isNotEmpty) game.designers.take(2).join(', '),
      if (game.publishers.isNotEmpty) game.publishers.first,
      if (game.yearPublished != null) '${game.yearPublished}',
    ].join(' · ');
    return Stack(
      fit: StackFit.expand,
      children: [
        if (game.heroUrl != null)
          CachedNetworkImage(imageUrl: game.heroUrl!, fit: BoxFit.cover)
        else
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.primaryGradientVertical),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.surface,
                Color(0x33F8F9FA),
                AppColors.transparent,
              ],
              stops: [0, 0.5, 1],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: AppSpacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (game.categories.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: AppSpacing.borderRadiusFull,
                  ),
                  child: Text(
                    game.categories.first,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ),
              AppSpacing.vGapSm,
              Text(game.name, style: AppTypography.headlineLarge),
              if (byline.isNotEmpty)
                Text(
                  byline,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              if (game.ownedByFriends.isNotEmpty) ...[
                AppSpacing.vGapSm,
                Row(
                  children: [
                    AvatarStack(users: game.ownedByFriends),
                    AppSpacing.hGapSm,
                    Text(
                      l10n.gameOwnedByFriends(game.ownedByFriends.length),
                      style: AppTypography.labelLarge,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = game.minPlayTimeMinutes;
    final cells = [
      (Icons.groups_outlined, l10n.gameInfoPlayers, game.playersLabel ?? '–'),
      (
        Icons.schedule_rounded,
        l10n.gameInfoDuration,
        time == null ? '–' : l10n.gameMinutes(time),
      ),
      (
        Icons.psychology_outlined,
        l10n.gameInfoComplexity,
        game.complexity == null ? '–' : '${game.complexity!.toStringAsFixed(1)}/5',
      ),
    ];
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final (icon, label, value) in cells)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                child: Column(
                  children: [
                    Icon(icon, color: AppColors.primary),
                    AppSpacing.vGapXs,
                    Text(label.toUpperCase(), style: AppTypography.labelSmall),
                    Text(value, style: AppTypography.titleMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.game});

  final Game game;

  Future<void> _run(BuildContext context, Future<void> Function() f,
      {String? success}) async {
    try {
      await f();
      if (success != null && context.mounted) {
        showToast(context, success, type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry =
        ref.watch(collectionNotifierProvider).valueOrNull?.entryFor(game.id);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final owned = entry?.isOwned ?? false;
    final wishlisted = entry?.isWishlisted ?? false;
    final favorited = entry?.isFavorited ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!owned)
            FilledButton.icon(
              key: const Key('game-add-collection'),
              style: _pill(AppColors.primary, AppColors.onPrimary),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.gameAddToCollection),
              onPressed: () => _run(
                context,
                () => notifier.setFlags(game, isOwned: true),
                success: l10n.gameAddedToCollection,
              ),
            )
          else
            GestureDetector(
              onLongPress: () => _run(
                context,
                () => notifier.setFlags(game, isOwned: false),
              ),
              child: FilledButton.icon(
                key: const Key('game-in-collection'),
                style: _pill(
                  AppColors.secondaryContainer,
                  AppColors.onSecondaryContainer,
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.gameInCollection),
                onPressed: () => _showEntrySheet(context, ref, entry!),
              ),
            ),
          AppSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('game-wishlist'),
                  style: _pill(
                    AppColors.surfaceContainerHigh,
                    AppColors.onSurfaceVariant,
                  ),
                  icon: Icon(
                    wishlisted
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                  label: Text(
                    wishlisted ? l10n.gameOnWishlist : l10n.gameWishlist,
                  ),
                  onPressed: () => _run(
                    context,
                    () => notifier.setFlags(game, isWishlisted: !wishlisted),
                  ),
                ),
              ),
              AppSpacing.hGapSm,
              IconButton.filledTonal(
                key: const Key('game-favorite'),
                tooltip: favorited ? l10n.gameUnfavorite : l10n.gameFavorite,
                icon: Icon(
                  favorited ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorited ? AppColors.primary : null,
                ),
                onPressed: () => _run(
                  context,
                  () => notifier.setFlags(game, isFavorited: !favorited),
                ),
              ),
              IconButton.filledTonal(
                key: const Key('game-log-play'),
                tooltip: l10n.gameLogPlay,
                icon: const Icon(Icons.casino_outlined),
                onPressed: () => showLogPlaySheet(context, ref, game),
              ),
            ],
          ),
          AppSpacing.vGapSm,
          Tooltip(
            message: game.hasRulebook ? '' : l10n.aiNoRulebookTooltip,
            child: FilledButton.icon(
              key: const Key('game-ai'),
              style: _pill(
                game.hasRulebook
                    ? AppColors.tertiaryContainer
                    : AppColors.surfaceContainerHigh,
                game.hasRulebook
                    ? AppColors.onTertiaryContainer
                    : AppColors.onSurfaceVariant,
              ),
              icon: const Icon(Icons.smart_toy_outlined),
              label: Text(l10n.aiRulesAssistant),
              onPressed: () => showAiRulesSheet(context, game),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _pill(Color bg, Color fg) => FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: AppTypography.titleSmall,
      );

  Future<void> _showEntrySheet(
    BuildContext context,
    WidgetRef ref,
    UserGame entry,
  ) =>
      showCollectionEntrySheet(context, ref, entry);
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.game});

  final Game game;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = widget.game;
    final description = (game.description ?? '')
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll('&#10;', '\n')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        96,
      ),
      children: [
        if (description.isNotEmpty) ...[
          Text(
            description,
            style: AppTypography.bodyLarge,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? l10n.commonShowLess : l10n.commonReadMore),
          ),
        ],
        if (game.averageRating != null)
          _RatingRow(
            icon: Icons.stars_rounded,
            text: l10n.gameBggRating(game.averageRating!.toStringAsFixed(1)),
          ),
        if (game.friendAvgRating != null && game.friendRatingCount > 0)
          _RatingRow(
            icon: Icons.group_outlined,
            text: l10n.gameFriendRating(
              game.friendAvgRating!.toStringAsFixed(1),
              game.friendRatingCount,
            ),
          ),
        if (game.categories.isNotEmpty) ...[
          AppSpacing.vGapLg,
          Text(l10n.gameCategories, style: AppTypography.titleMedium),
          AppSpacing.vGapSm,
          _ChipWrap(values: game.categories),
        ],
        if (game.mechanics.isNotEmpty) ...[
          AppSpacing.vGapLg,
          Text(l10n.gameMechanics, style: AppTypography.titleMedium),
          AppSpacing.vGapSm,
          _ChipWrap(values: game.mechanics),
        ],
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryContainer),
            AppSpacing.hGapSm,
            Expanded(child: Text(text, style: AppTypography.titleSmall)),
          ],
        ),
      );
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final v in values)
            Chip(
              label: Text(v),
              side: BorderSide.none,
              shape: const StadiumBorder(),
              backgroundColor: AppColors.surfaceContainerHighest,
              labelStyle: AppTypography.labelLarge,
            ),
        ],
      );
}

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(gameReviewsProvider(gameId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(gameReviewsProvider(gameId)),
          ),
          data: (reviews) => reviews.isEmpty
              ? EmptyState(
                  icon: Icons.rate_review_outlined,
                  title: l10n.gameNoReviews,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: reviews.length,
                  itemBuilder: (_, i) {
                    final r = reviews[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserRow(
                          user: r.user,
                          subtitle: l10n.gamePlays(r.playCount),
                          trailing: r.personalRating == null
                              ? null
                              : _Score(value: r.personalRating!),
                        ),
                        if (r.notes != null && r.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              72,
                              0,
                              AppSpacing.lg,
                              AppSpacing.md,
                            ),
                            child: Text(r.notes!, style: AppTypography.bodyMedium),
                          ),
                      ],
                    );
                  },
                ),
        );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: AppColors.primaryContainer),
          Text(value.toStringAsFixed(1), style: AppTypography.labelLarge),
        ],
      );
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(gameSessionsProvider(gameId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => e is NotFoundException
              ? EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: l10n.gameNoSessions,
                )
              : ErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(gameSessionsProvider(gameId)),
                ),
          data: (s) => s.items.isEmpty
              ? EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: l10n.gameNoSessions,
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
                      ref.read(gameSessionsProvider(gameId).notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: s.items.length,
                    itemBuilder: (_, i) =>
                        PostCard(post: s.items[i], compact: true),
                  ),
                ),
        );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(gameFriendsProvider(gameId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(gameFriendsProvider(gameId)),
          ),
          data: (friends) {
            final owners = friends.where((f) => f.isOwned).toList();
            final shown = owners.isEmpty ? friends : owners;
            return shown.isEmpty
                ? EmptyState(
                    icon: Icons.group_outlined,
                    title: l10n.gameNoFriendsOwn,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => UserRow(
                      user: shown[i].user,
                      subtitle: l10n.gamePlays(shown[i].playCount),
                      trailing: shown[i].personalRating == null
                          ? null
                          : _Score(value: shown[i].personalRating!),
                    ),
                  );
          },
        );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: AppColors.background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MeepleAppBar(showBackButton: true),
      body: SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            SkeletonBox(height: 320, borderRadius: AppSpacing.borderRadiusXl),
            AppSpacing.vGapLg,
            SkeletonBox(height: 88, borderRadius: AppSpacing.borderRadiusXl),
            AppSpacing.vGapLg,
            SkeletonBox(height: 52, borderRadius: AppSpacing.borderRadiusPill),
            AppSpacing.vGapSm,
            SkeletonBox(height: 52, borderRadius: AppSpacing.borderRadiusPill),
          ],
        ),
      ),
    );
  }
}
