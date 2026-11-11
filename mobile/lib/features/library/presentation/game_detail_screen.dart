import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/ai/presentation/ai_rules_sheet.dart';
import 'package:meeple_hearth/features/library/data/collection_repository.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/how_to_play_section.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/library_widgets.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/play_sheets.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Game detail (web `/library/[gameId]`): cover hero, stat tiles, rating
/// row, round collection actions + Ask AI, "Log a play", and Overview /
/// How to Play / Reviews / Sessions / Friends tabs.
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

enum _DetailTab { overview, howToPlay, reviews, sessions, friends }

class _GameDetailBody extends ConsumerStatefulWidget {
  const _GameDetailBody({required this.game, this.cachedAt});

  final Game game;
  final DateTime? cachedAt;

  @override
  ConsumerState<_GameDetailBody> createState() => _GameDetailBodyState();
}

class _GameDetailBodyState extends ConsumerState<_GameDetailBody> {
  _DetailTab _tab = _DetailTab.overview;

  bool _onScroll(ScrollNotification n) {
    if (_tab == _DetailTab.sessions &&
        n.metrics.axis == Axis.vertical &&
        n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
      ref.read(gameSessionsProvider(widget.game.id).notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = widget.game;
    final tabs = {
      _DetailTab.overview: l10n.gameTabOverview,
      _DetailTab.howToPlay: l10n.gameTabHowToPlay,
      _DetailTab.reviews: l10n.gameTabReviews,
      _DetailTab.sessions: l10n.gameTabSessions,
      _DetailTab.friends: l10n.gameTabFriends,
    };
    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Hero(
                    game: game,
                    onFriends: () => setState(() => _tab = _DetailTab.friends),
                  ),
                ),
                if (widget.cachedAt != null)
                  SliverToBoxAdapter(
                    child: StaleDataBanner(cachedAt: widget.cachedAt!),
                  ),
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  sliver: SliverList.list(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      _StatTiles(game: game),
                      const SizedBox(height: 20),
                      _RatingRow(game: game),
                      const SizedBox(height: 20),
                      _Actions(game: game),
                      const SizedBox(height: AppSpacing.xl),
                      _DetailTabs(
                        tabs: tabs,
                        selected: _tab,
                        onSelect: (t) => setState(() => _tab = t),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: switch (_tab) {
                      _DetailTab.overview => _OverviewTab(game: game),
                      _DetailTab.howToPlay => HowToPlaySection(game: game),
                      _DetailTab.reviews => _ReviewsTab(gameId: game.id),
                      _DetailTab.sessions => _SessionsTab(gameId: game.id),
                      _DetailTab.friends => _FriendsTab(gameId: game.id),
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: CircleBackButton(
                  color: AppColors.scrim.withValues(alpha: 0.3),
                  iconColor: AppColors.onPrimary,
                  onPressed: () =>
                      meepleGoBack(context, fallbackRoute: AppRoutes.library),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover image with the title block over a fade into the page.
class _Hero extends StatelessWidget {
  const _Hero({required this.game, required this.onFriends});

  final Game game;
  final VoidCallback onFriends;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 320 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeNetworkImage(
            url: game.heroUrl,
            fallback: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, AppColors.primaryFixedDim],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.background,
                  AppColors.background.withValues(alpha: 0.3),
                  AppColors.background.withValues(alpha: 0),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (game.families.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                    child: Text(
                      game.families.first.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Text(
                  game.name,
                  style: AppTypography.headlineMedium.copyWith(
                    letterSpacing: 0,
                    height: 1.25,
                  ),
                ),
                if (game.designers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.gameBy(game.designers.take(2).join(', ')),
                      style: AppTypography.bodySmall,
                    ),
                  ),
                if (game.ownedByFriends.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: onFriends,
                      child: Row(
                        children: [
                          AvatarStack(users: game.ownedByFriends),
                          AppSpacing.hGapSm,
                          Text(
                            l10n.gameOwnedByFriends(game.ownedByFriends.length),
                            style: AppTypography.labelMedium.copyWith(
                              fontFamily: AppTypography.titleSmall.fontFamily,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Players / Time / Complexity tiles (`grid-cols-3 gap-2`).
class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final players = game.minPlayers != null && game.maxPlayers != null
        ? '${game.minPlayers}–${game.maxPlayers}'
        : game.minPlayers != null
            ? '${game.minPlayers}+'
            : '—';
    final cells = [
      (Icons.group_outlined, l10n.gameStatPlayers, players),
      (
        Icons.timer_outlined,
        l10n.gameStatTime,
        game.minPlayTimeMinutes == null
            ? '—'
            : l10n.gameMinutes(game.minPlayTimeMinutes!),
      ),
      (
        Icons.psychology_outlined,
        l10n.gameStatComplexity,
        game.complexity == null ? '—' : game.complexity!.toStringAsFixed(1),
      ),
    ];
    return Row(
      children: [
        for (final (i, (icon, label, value)) in cells.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// BGG rating, friends' average, rank and year.
class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = NumberFormat.decimalPattern();
    final strong = AppTypography.titleSmall;
    final meta = AppTypography.bodySmall;
    final friendAvg = game.friendAvgRating;
    final year = game.yearPublished;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (game.averageRating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(game.averageRating!.toStringAsFixed(2), style: strong),
                    if (game.usersRated != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        l10n.gameRatingsCount(number.format(game.usersRated)),
                        style: meta,
                      ),
                    ],
                  ],
                ),
              if (friendAvg != null && game.friendRatingCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_rounded,
                        size: 16, color: AppColors.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      game.friendRatingCount == 1
                          ? l10n.gameFriendAvgOne(friendAvg.toStringAsFixed(1))
                          : l10n.gameFriendRating(
                              friendAvg.toStringAsFixed(1),
                              game.friendRatingCount,
                            ),
                      style: AppTypography.labelMedium.copyWith(
                        fontFamily: strong.fontFamily,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              if (game.rank != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.military_tech_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.gameBggRank(number.format(game.rank)),
                      style: AppTypography.labelMedium.copyWith(
                        fontFamily: strong.fontFamily,
                      ),
                    ),
                  ],
                ),
            ],
          )),
          if (year != null) Text('$year', style: meta),
        ],
      ),
    );
  }
}

/// Own / Wishlist / Favorite toggles + Ask AI (`grid-cols-4`), then the
/// full-width "Log a play" button.
class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.game});

  final Game game;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _saving = false;

  Future<void> _toggle({
    bool? isOwned,
    bool? isWishlisted,
    bool? isFavorited,
    String? success,
  }) async {
    setState(() => _saving = true);
    try {
      await ref.read(collectionNotifierProvider.notifier).setFlags(
            widget.game,
            isOwned: isOwned,
            isWishlisted: isWishlisted,
            isFavorited: isFavorited,
          );
      if (success != null && mounted) {
        showToast(context, success, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = widget.game;
    final entry =
        ref.watch(collectionNotifierProvider).valueOrNull?.entryFor(game.id);
    final owned = entry?.isOwned ?? false;
    final wishlisted = entry?.isWishlisted ?? false;
    final favorited = entry?.isFavorited ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ActionTile(
              key: Key(owned ? 'game-in-collection' : 'game-add-collection'),
              icon: owned ? Icons.check_box_rounded : Icons.check_box_outlined,
              label: owned ? l10n.gameInCollection : l10n.gameActionOwn,
              active: owned,
              enabled: !_saving,
              onTap: () => _toggle(
                isOwned: !owned,
                success: owned ? null : l10n.gameAddedToCollection,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ActionTile(
              key: const Key('game-wishlist'),
              icon: wishlisted
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: wishlisted ? l10n.gameOnWishlist : l10n.gameWishlist,
              active: wishlisted,
              enabled: !_saving,
              onTap: () => _toggle(isWishlisted: !wishlisted),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ActionTile(
              key: const Key('game-favorite'),
              icon: favorited
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: favorited
                  ? l10n.gameActionFavorited
                  : l10n.gameActionFavorite,
              active: favorited,
              enabled: !_saving,
              onTap: () => _toggle(isFavorited: !favorited),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ActionTile(
              key: const Key('game-ai'),
              icon: Icons.smart_toy_outlined,
              label: l10n.gameActionAskAi,
              background: AppColors.tertiaryContainer,
              foreground: AppColors.onTertiaryContainer,
              onTap: () => showAiRulesSheet(context, game),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: InkWell(
            key: const Key('game-log-play'),
            borderRadius: BorderRadius.circular(AppRadius.tile),
            onTap: () => showLogPlaySheet(context, ref, game),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sports_esports_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.gameLogPlay,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ??
        (active ? AppColors.primary : AppColors.surfaceContainerHigh);
    final fg = foreground ??
        (active ? AppColors.onPrimary : AppColors.onSurfaceVariant);
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: 2,
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        fontFamily: AppTypography.titleSmall.fontFamily,
                        fontSize: 11,
                        height: 1.2,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bold text-sm tab labels with a 2px primary underline on the active one.
class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final Map<_DetailTab, String> tabs;
  final _DetailTab selected;
  final ValueChanged<_DetailTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final MapEntry(key: tab, value: label) in tabs.entries)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xl),
              child: InkWell(
                key: tab == _DetailTab.howToPlay
                    ? const Key('how-to-play')
                    : ValueKey('game-tab-${tab.name}'),
                onTap: () => onSelect(tab),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          label,
                          style: AppTypography.titleSmall.copyWith(
                            color: tab == selected
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: tab == selected
                              ? AppColors.primary
                              : AppColors.transparent,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _cleanDescription(String raw) => raw
    .replaceAll(RegExp('<[^>]*>'), '')
    .replaceAll('&#10;', '\n')
    .replaceAll(RegExp('&quot;|&#34;'), '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp('&#39;|&apos;'), "'")
    .replaceAll('&ndash;', '–')
    .replaceAll('&mdash;', '—')
    .replaceAll('&nbsp;', ' ')
    .trim();

/// Uppercase `text-xs font-bold tracking-widest` section label.
class _OverviewLabel extends StatelessWidget {
  const _OverviewLabel(this.text, {this.bottom = AppSpacing.sm});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Text(text.toUpperCase(), style: AppTypography.overline),
      );
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.game});

  final Game game;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _expanded = false;

  Widget _chips(String label, List<String> values, Color bg, Color fg) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OverviewLabel(label),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final v in values)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                    child: Text(
                      v,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                k,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            Text(v, style: AppTypography.titleSmall),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = widget.game;
    final description = _cleanDescription(game.description ?? '');
    final type = game.gameType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description.isNotEmpty) ...[
          _OverviewLabel(l10n.gameAbout),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(height: 1.625),
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _expanded ? l10n.commonShowLess : l10n.commonReadMore,
                  style: AppTypography.labelMedium.copyWith(
                    fontFamily: AppTypography.titleSmall.fontFamily,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (game.categories.isNotEmpty)
          _chips(
            l10n.gameCategories,
            game.categories,
            AppColors.secondaryContainer,
            AppColors.onSecondaryContainer,
          ),
        if (game.mechanics.isNotEmpty)
          _chips(
            l10n.gameMechanics,
            game.mechanics,
            AppColors.surfaceContainerHigh,
            AppColors.onSurface,
          ),
        if (game.honors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverviewLabel(l10n.gameAwards),
                for (final h in game.honors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 14,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            h,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (game.designers.isNotEmpty)
          _chips(
            l10n.gameDesigners,
            game.designers,
            AppColors.surfaceContainerHigh,
            AppColors.onSurface,
          ),
        if (game.publishers.isNotEmpty)
          _chips(
            l10n.gamePublishers,
            game.publishers.take(5).toList(),
            AppColors.surfaceContainerHigh,
            AppColors.onSurface,
          ),
        if (game.families.isNotEmpty)
          _chips(
            l10n.libraryFiltersGenre,
            game.families,
            AppColors.tertiaryContainer,
            AppColors.onTertiaryContainer,
          ),
        if (game.minAge != null)
          _kv(l10n.gameMinAge, l10n.gameAgePlus(game.minAge!)),
        if (type != null && type.isNotEmpty)
          _kv(
            l10n.gameTypeLabel,
            '${type[0].toUpperCase()}${type.substring(1)}',
          ),
        if (game.bggUrl != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Material(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: InkWell(
              key: const Key('game-bgg-link'),
              borderRadius: BorderRadius.circular(AppRadius.tile),
              onTap: () => launchUrl(
                Uri.parse(game.bggUrl!),
                mode: LaunchMode.externalApplication,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: AppColors.onSurface,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.gameViewOnBgg, style: AppTypography.titleSmall),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _MyPanel(game: game),
      ],
    );
  }
}

/// "Your rating", play history and notes (web overview side panel).
class _MyPanel extends ConsumerStatefulWidget {
  const _MyPanel({required this.game});

  final Game game;

  @override
  ConsumerState<_MyPanel> createState() => _MyPanelState();
}

class _MyPanelState extends ConsumerState<_MyPanel> {
  late final TextEditingController _notes = TextEditingController(
    text: _entry?.notes ?? '',
  );
  final _notesFocus = FocusNode();
  bool _saving = false;
  bool _savingNotes = false;

  UserGame? get _entry => ref
      .read(collectionNotifierProvider)
      .valueOrNull
      ?.entryFor(widget.game.id);

  @override
  void initState() {
    super.initState();
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) _saveNotes();
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _rate(double rating) async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref
          .read(collectionNotifierProvider.notifier)
          .rate(widget.game, rating: rating);
    } catch (_) {
      if (mounted) {
        showToast(context, l10n.libraryRatingSaveFailed, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNotes() async {
    final text = _notes.text.trim();
    if ((_entry?.notes ?? '') == text) return;
    setState(() => _savingNotes = true);
    try {
      await ref
          .read(collectionNotifierProvider.notifier)
          .rate(widget.game, notes: text);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  Future<void> _deletePlay(PlayLog play) async {
    final l10n = context.l10n;
    try {
      await ref.read(collectionRepositoryProvider).deletePlay(play.id);
      ref.invalidate(gamePlaysProvider(widget.game.id));
      if (mounted) {
        showToast(context, l10n.gamePlayDeleted, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = ref
        .watch(collectionNotifierProvider)
        .valueOrNull
        ?.entryFor(widget.game.id);
    final plays = ref.watch(gamePlaysProvider(widget.game.id));
    final noPlays = Text(
      l10n.collectionNoPlays,
      style: AppTypography.bodyMedium.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
    );
    return Container(
      key: const Key('game-my-panel'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewLabel(l10n.libraryRatingLabel),
          StarRating(
            rating: entry?.personalRating,
            onRate: _rate,
            disabled: _saving,
            size: 24,
          ),
          const SizedBox(height: 20),
          _OverviewLabel(
            l10n.gamePlayHistory(entry?.playCount ?? 0),
            bottom: AppSpacing.md,
          ),
          plays.when(
            loading: () => const SkeletonShimmer(
              child: SkeletonBox(
                  height: 40, borderRadius: AppSpacing.borderRadiusPill),
            ),
            error: (_, __) => noPlays,
            data: (list) => list.isEmpty
                ? noPlays
                : Column(
                    children: [
                      for (final (i, p) in list.indexed)
                        _PlayRow(
                          play: p,
                          latest: i == 0,
                          onDelete: () => _deletePlay(p),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          _OverviewLabel(l10n.collectionNotes),
          TextField(
            key: const Key('game-notes'),
            controller: _notes,
            focusNode: _notesFocus,
            maxLines: 3,
            maxLength: 1000,
            style: AppTypography.bodyMedium,
            onTapOutside: (_) => _notesFocus.unfocus(),
            decoration: InputDecoration(
              hintText: l10n.gameNotesPlaceholder,
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              counterText: '',
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          if (_savingNotes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l10n.gameNotesSaving, style: AppTypography.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _PlayRow extends StatelessWidget {
  const _PlayRow({
    required this.play,
    required this.latest,
    required this.onDelete,
  });

  final PlayLog play;
  final bool latest;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = [
      if (play.durationMinutes != null) l10n.gameMinutes(play.durationMinutes!),
      if (play.playerCount != null) l10n.gamePlayerCount(play.playerCount!),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.sports_esports_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: AppDateUtils.formatDate(play.playedAt),
                    children: [
                      if (latest)
                        TextSpan(
                          text: '  ${l10n.gameLatestPlay.toUpperCase()}',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  style: AppTypography.titleSmall,
                ),
                if (meta.isNotEmpty) Text(meta, style: AppTypography.bodySmall),
                if (play.notes != null && play.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      play.notes!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('play-delete-${play.id}'),
            tooltip: l10n.gameDeletePlay,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.onSurfaceVariant,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Avatar list skeleton shown while a friends tab loads.
class _TabSkeleton extends StatelessWidget {
  const _TabSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    SkeletonCircle(size: 40),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.5,
                            child: SkeletonBox(height: 12),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          FractionallySizedBox(
                            widthFactor: 0.33,
                            child: SkeletonBox(height: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Centered `text-sm` message (`py-10`) for an empty or failed tab.
class _TabMessage extends StatelessWidget {
  const _TabMessage(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  context.l10n.commonRetry,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      );
}

/// `bg-surface-container-low rounded-2xl` friend row: avatar, name, plays,
/// stars.
class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.user,
    required this.playCount,
    this.rating,
    this.notes,
  });

  final UserSummaryLike user;
  final int playCount;
  final double? rating;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap:
              user.deleted ? null : () => context.push('/profile/${user.id}'),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: notes == null ? AppSpacing.md : AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      imageUrl: user.avatarUrl,
                      displayName: user.name,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: AppTypography.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(l10n.gamePlays(playCount),
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    StarRating(rating: rating),
                  ],
                ),
                if (notes != null && notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(notes!, style: AppTypography.bodyMedium),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The parts of a user a friend card shows.
final class UserSummaryLike {
  const UserSummaryLike({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.deleted = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool deleted;
}

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(gameReviewsProvider(gameId)).when(
          loading: () => const _TabSkeleton(),
          error: (e, _) => _TabMessage(
            l10n.gameLoadFailed,
            onRetry: () => ref.invalidate(gameReviewsProvider(gameId)),
          ),
          data: (reviews) => reviews.isEmpty
              ? _TabMessage(l10n.gameNoReviews)
              : Column(
                  children: [
                    for (final r in reviews)
                      _FriendCard(
                        user: UserSummaryLike(
                          id: r.user.id,
                          name: displayNameOf(context, r.user),
                          avatarUrl: r.user.avatarUrl,
                          deleted: r.user.deleted,
                        ),
                        playCount: r.playCount,
                        rating: r.personalRating,
                        notes: r.notes ?? '',
                      ),
                  ],
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
          loading: () => const _TabSkeleton(),
          error: (e, _) => _TabMessage(
            l10n.gameLoadFailed,
            onRetry: () => ref.invalidate(gameFriendsProvider(gameId)),
          ),
          data: (friends) => friends.isEmpty
              ? _TabMessage(l10n.gameNoFriendsOwn)
              : Column(
                  children: [
                    for (final f in friends)
                      _FriendCard(
                        user: UserSummaryLike(
                          id: f.user.id,
                          name: displayNameOf(context, f.user),
                          avatarUrl: f.user.avatarUrl,
                          deleted: f.user.deleted,
                        ),
                        playCount: f.playCount,
                        rating: f.personalRating,
                      ),
                  ],
                ),
        );
  }
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(gameSessionsProvider(gameId)).when(
          loading: () => const _TabSkeleton(),
          error: (e, _) => e is NotFoundException
              ? _TabMessage(l10n.gameNoSessions)
              : _TabMessage(
                  l10n.gameLoadFailed,
                  onRetry: () => ref.invalidate(gameSessionsProvider(gameId)),
                ),
          data: (s) => s.items.isEmpty
              ? _TabMessage(l10n.gameNoSessions)
              : Column(
                  children: [
                    for (final p in s.items) _SessionCard(post: p),
                  ],
                ),
        );
  }
}

/// A game-night post in the Sessions tab.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final image = post.imageUrls.isEmpty ? null : post.imageUrls.first;
    final name = displayNameOf(context, post.author);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          key: ValueKey('session-${post.id}'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push(AppRoutes.postDetail(post.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: SafeNetworkImage(
                        url: image,
                        fallback: const ColoredBox(
                          color: AppColors.surfaceContainerHigh,
                          child: GameCoverFallback(iconSize: 28),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.hGapMd,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(
                            imageUrl: post.author.avatarUrl,
                            displayName: name,
                            size: 24,
                          ),
                          AppSpacing.hGapSm,
                          Expanded(
                            child: Text(
                              name,
                              style: AppTypography.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppDateUtils.formatDate(
                            post.playedAt ?? post.createdAt),
                        style: AppTypography.bodySmall.copyWith(fontSize: 11),
                      ),
                      if (post.caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            post.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      if (post.taggedUsers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: AvatarStack(
                            users: post.taggedUsers,
                            max: 6,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MeepleAppBar(
        showBackButton: true,
        fallbackRoute: AppRoutes.library,
      ),
      body: SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            SkeletonBox(height: 280, borderRadius: AppSpacing.borderRadiusXxl),
            AppSpacing.vGapLg,
            Row(
              children: [
                Expanded(
                  child: SkeletonBox(
                      height: 80, borderRadius: AppSpacing.borderRadiusPill),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: SkeletonBox(
                      height: 80, borderRadius: AppSpacing.borderRadiusPill),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: SkeletonBox(
                      height: 80, borderRadius: AppSpacing.borderRadiusPill),
                ),
              ],
            ),
            AppSpacing.vGapLg,
            SkeletonBox(height: 64, borderRadius: AppSpacing.borderRadiusPill),
            AppSpacing.vGapSm,
            SkeletonBox(height: 44, borderRadius: AppSpacing.borderRadiusPill),
          ],
        ),
      ),
    );
  }
}
