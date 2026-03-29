import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';

/// Grid tile for a [Game] in search results or the browse view.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    this.onTap,
    this.trailing,
  });

  final Game game;
  final VoidCallback? onTap;

  /// Optional widget placed in the top-right corner (e.g. add-to-collection
  /// button or collection-status icon).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GameThumbnail(game: game, trailing: trailing),
          AppSpacing.vGapSm,
          Text(
            game.name,
            style: AppTypography.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.vGapXs,
          _GameMeta(game: game),
        ],
      ),
    );
  }
}

class _GameThumbnail extends StatelessWidget {
  const _GameThumbnail({required this.game, this.trailing});

  final Game game;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: AppSpacing.borderRadiusLg,
            child: game.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: game.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const _GameThumbnailFallback(),
                  )
                : const _GameThumbnailFallback(),
          ),
          if (game.averageRating != null)
            Positioned(
              bottom: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _RatingBadge(rating: game.averageRating!),
            ),
          if (trailing != null)
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

class _GameThumbnailFallback extends StatelessWidget {
  const _GameThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: const Icon(
        Icons.casino_outlined,
        size: 48,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.inverseSurface.withValues(alpha: 0.85),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.primaryContainer),
          AppSpacing.hGapXs,
          Text(
            rating.toStringAsFixed(1),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.inverseOnSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMeta extends StatelessWidget {
  const _GameMeta({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final players = _playerRange(game);
    return Text(
      players,
      style: AppTypography.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _playerRange(Game g) {
    if (g.minPlayers != null && g.maxPlayers != null) {
      if (g.minPlayers == g.maxPlayers) return '${g.minPlayers} players';
      return '${g.minPlayers}–${g.maxPlayers} players';
    }
    if (g.minPlayers != null) return '${g.minPlayers}+ players';
    return '';
  }
}

/// List-row variant for collection screens.
class GameListTile extends StatelessWidget {
  const GameListTile({
    super.key,
    required this.game,
    this.onTap,
    this.trailing,
    this.subtitle,
  });

  final Game game;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: AppSpacing.borderRadiusSm,
        child: game.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: game.thumbnailUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const SizedBox(width: 48, height: 48),
              )
            : Container(
                width: 48,
                height: 48,
                color: AppColors.surfaceContainerHigh,
                child: const Icon(Icons.casino_outlined, size: 24),
              ),
      ),
      title: Text(
        game.name,
        style: AppTypography.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTypography.bodySmall)
          : null,
      trailing: trailing,
    );
  }
}
