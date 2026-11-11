import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Network image that never shows the debug error cross: `data:` URIs and
/// failed loads fall back to [fallback].
class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty || !u.startsWith('http')) return fallback;
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) =>
          const ColoredBox(color: AppColors.surfaceContainerLow),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// The `casino` placeholder shown when a game has no usable cover.
class GameCoverFallback extends StatelessWidget {
  const GameCoverFallback({super.key, this.iconSize = 36});

  final double iconSize;

  @override
  Widget build(BuildContext context) => Center(
        child: Icon(
          Icons.casino_outlined,
          size: iconSize,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      );
}

/// Web library cover: `aspect-[3/4] rounded-[1.5rem]` white tile with the
/// box art contained over a blurred copy of itself, plus overlay [badges].
class GameCover extends StatelessWidget {
  const GameCover({super.key, required this.url, this.badges = const []});

  final String? url;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final usable = url != null && url!.startsWith('http');
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Opaque blend of `bg-surface-container-lowest/80` on the page so
          // the shadow (drawn underneath in Flutter) does not show through.
          color: Color.alphaBlend(
            AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
            AppColors.background,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (usable) ...[
                Opacity(
                  opacity: 0.4,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: SafeNetworkImage(
                      url: url,
                      fallback: const SizedBox.shrink(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SafeNetworkImage(
                    url: url,
                    fit: BoxFit.contain,
                    fallback: const GameCoverFallback(),
                  ),
                ),
              ] else
                const GameCoverFallback(),
              ...badges,
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon + text meta item (`material-symbols text-[14px]` + label).
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.style});

  final IconData icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: (style.fontSize ?? 11) + 4, color: style.color),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: style),
        ],
      );
}

/// Height of the text block under a catalog cover (title + meta row).
const double libraryTileTextExtent = 60;

/// Extra height of a collection tile (two-line title + star row).
const double collectionTileTextExtent = 98;

/// Catalog card of the "All Games" feed: cover with `#rank` and rating
/// badges, title and players / playtime.
class LibraryGameTile extends StatelessWidget {
  const LibraryGameTile({super.key, required this.game, this.onTap});

  final Game game;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = AppTypography.labelMedium.copyWith(fontSize: 11);
    return GestureDetector(
      key: ValueKey('game-${game.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameCover(
            url: game.coverUrl,
            badges: [
              if (game.averageRating != null)
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: RatingPill(rating: game.averageRating!),
                ),
              if (game.rank != null)
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: _RankPill(rank: game.rank!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.name,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    if (game.minPlayers != null)
                      _Meta(
                        icon: Icons.group_outlined,
                        text: '${game.minPlayers}'
                            '${game.maxPlayers != null ? '-${game.maxPlayers}' : '+'}',
                        style: meta,
                      ),
                    if (game.minPlayTimeMinutes != null)
                      _Meta(
                        icon: Icons.timer_outlined,
                        text: l10n.gameMinutes(game.minPlayTimeMinutes!),
                        style: meta,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White `★ 7.1` pill (top-right of a catalog cover).
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
          borderRadius: AppSpacing.borderRadiusFull,
          boxShadow: AppShadowsLite.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: AppColors.primaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: AppTypography.labelMedium.copyWith(
                fontSize: 11,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      );
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.9),
          borderRadius: AppSpacing.borderRadiusFull,
          boxShadow: AppShadowsLite.sm,
        ),
        child: Text(
          '#$rank',
          style: AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: AppColors.onPrimary,
          ),
        ),
      );
}

/// Shadow used by the cover badges (`shadow-sm`).
abstract final class AppShadowsLite {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
  ];
}

/// A collection-shelf card: badges (OWNED / WISHLIST / favourite / plays),
/// two-line title, meta and the five-star personal rating.
class CollectionGameTile extends StatelessWidget {
  const CollectionGameTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onRate,
    this.ratingBusy = false,
  });

  final UserGame entry;
  final VoidCallback? onTap;
  final ValueChanged<double>? onRate;
  final bool ratingBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = entry.game;
    final meta = AppTypography.eyebrow.copyWith(
      letterSpacing: 1,
      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
    );
    final players = game.minPlayers == null
        ? null
        : game.maxPlayers == null
            ? '${game.minPlayers}+'
            : '${game.minPlayers}–${game.maxPlayers}';
    return Column(
      key: ValueKey('game-${game.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GameCover(
                url: game.coverUrl,
                badges: [
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.isOwned)
                          _ShelfBadge(
                            label: l10n.badgeOwned,
                            bg: AppColors.tertiaryContainer,
                            fg: AppColors.onTertiaryContainer,
                          ),
                        if (entry.isWishlisted)
                          Padding(
                            padding: EdgeInsets.only(
                              top: entry.isOwned ? AppSpacing.xs : 0,
                            ),
                            child: _ShelfBadge(
                              label: l10n.libraryBadgeWishlist,
                              icon: Icons.bookmark_rounded,
                              bg: AppColors.secondaryContainer,
                              fg: AppColors.onSecondaryContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (entry.isFavorited)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Tooltip(
                        message: l10n.badgeFavorited,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest
                                .withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: AppShadowsLite.md,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  if (entry.playCount > 0)
                    Positioned(
                      bottom: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.8),
                          borderRadius: AppSpacing.borderRadiusFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sports_esports_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.playCount}',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.lg,
                      children: [
                        if (players != null)
                          _Meta(
                            icon: Icons.group_outlined,
                            text: players,
                            style: meta,
                          ),
                        if (game.minPlayTimeMinutes != null)
                          _Meta(
                            icon: Icons.timer_outlined,
                            text: l10n
                                .gameMinutes(game.minPlayTimeMinutes!)
                                .toUpperCase(),
                            style: meta,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, 0, 0),
          child: StarRating(
            rating: entry.personalRating,
            onRate: onRate,
            disabled: ratingBusy,
          ),
        ),
      ],
    );
  }
}

class _ShelfBadge extends StatelessWidget {
  const _ShelfBadge({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppSpacing.borderRadiusFull,
          boxShadow: AppShadowsLite.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: fg),
              const SizedBox(width: 2),
            ],
            Text(
              label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: fg,
              ),
            ),
          ],
        ),
      );
}

/// Stars filled for a 1–10 personal rating (web `starsFromRating`).
int starsFromRating(double? rating) {
  if (rating == null || rating.isNaN || rating < 1) return 0;
  return ((rating > 10 ? 10 : rating) / 2).ceil().clamp(0, 5);
}

/// Rating sent for a tap on star [stars]; tapping the current star clears
/// it (0) — web `ratingForStarTap`.
double ratingForStarTap(int stars, double? current) {
  final clamped = stars.clamp(1, 5);
  return starsFromRating(current) == clamped ? 0 : clamped * 2.0;
}

/// Five stars over the 1–10 personal rating. Interactive with [onRate];
/// read-only otherwise (hidden when unrated).
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.onRate,
    this.disabled = false,
    this.size = 16,
  });

  final double? rating;
  final ValueChanged<double>? onRate;
  final bool disabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final filled = starsFromRating(rating);
    if (onRate == null && filled == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            onRate == null
                ? Padding(
                    padding: const EdgeInsets.all(1),
                    child: _star(star <= filled, readOnly: true),
                  )
                : Semantics(
                    button: true,
                    label: l10n.libraryRatingStar(star),
                    selected: star <= filled,
                    child: InkResponse(
                      key: ValueKey('star-$star'),
                      radius: size,
                      onTap: disabled
                          ? null
                          : () => onRate!(ratingForStarTap(star, rating)),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _star(star <= filled),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _star(bool on, {bool readOnly = false}) => Icon(
        on ? Icons.star_rounded : Icons.star_outline_rounded,
        size: size,
        color: on
            ? AppColors.primaryContainer
            : AppColors.onSurfaceVariant
                .withValues(alpha: readOnly ? 0.3 : 0.4),
      );
}

/// Loading placeholder for one library card (`aspect-[3/4] rounded-[2rem]`
/// block + two text bars).
class LibraryTileSkeleton extends StatelessWidget {
  const LibraryTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: SkeletonBox(borderRadius: AppSpacing.borderRadiusXxl),
          ),
          SizedBox(height: AppSpacing.md),
          FractionallySizedBox(
            widthFactor: 0.75,
            child: SkeletonBox(height: 16),
          ),
          SizedBox(height: AppSpacing.sm),
          FractionallySizedBox(
            widthFactor: 0.5,
            child: SkeletonBox(height: 12),
          ),
        ],
      );
}

/// 2-column library grid delegate (`grid-cols-2 gap-5`): rows sized for a
/// 3:4 cover plus [textExtent].
SliverGridDelegate libraryGridDelegate(
  double crossAxisExtent, {
  double textExtent = libraryTileTextExtent,
  double spacing = 20,
}) {
  final width = (crossAxisExtent - spacing) / 2;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
    mainAxisExtent: width * 4 / 3 + textExtent,
  );
}
