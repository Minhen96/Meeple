import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameDetailProvider(gameId));

    return Scaffold(
      body: gameAsync.when(
        loading: () => const _GameDetailSkeleton(),
        error: (Object e, __) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(gameDetailProvider(gameId)),
        ),
        data: (Game game) => _GameDetailContent(game: game),
      ),
    );
  }
}

class _GameDetailContent extends ConsumerWidget {
  const _GameDetailContent({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        _GameAppBar(game: game),
        SliverPadding(
          padding: AppSpacing.pagePadding,
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _GameStats(game: game),
              AppSpacing.vGapXl,
              if (game.description != null) ...[
                Text('About', style: AppTypography.titleMedium),
                AppSpacing.vGapSm,
                Text(game.description!, style: AppTypography.bodyMedium),
                AppSpacing.vGapXl,
              ],
              if (game.categories.isNotEmpty) ...[
                Text('Categories', style: AppTypography.titleMedium),
                AppSpacing.vGapSm,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: game.categories
                      .map((String c) => AppChip(label: c))
                      .toList(),
                ),
                AppSpacing.vGapXl,
              ],
              if (game.mechanics.isNotEmpty) ...[
                Text('Mechanics', style: AppTypography.titleMedium),
                AppSpacing.vGapSm,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: game.mechanics
                      .map((String m) => AppChip(
                            label: m,
                            variant: AppChipVariant.secondary,
                          ))
                      .toList(),
                ),
                AppSpacing.vGapXl,
              ],
              if (game.designers.isNotEmpty) ...[
                Text('Designers', style: AppTypography.titleMedium),
                AppSpacing.vGapSm,
                Text(
                  game.designers.join(', '),
                  style: AppTypography.bodyMedium,
                ),
                AppSpacing.vGapXl,
              ],
              const SizedBox(height: 96),
            ]),
          ),
        ),
      ],
    );
  }
}

class _GameAppBar extends StatelessWidget {
  const _GameAppBar({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: game.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: game.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _ImageFallback(),
              )
            : const _ImageFallback(),
        title: Text(
          game.name,
          style: AppTypography.titleMedium.copyWith(color: AppColors.onPrimary),
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceContainerHigh,
      child: const Icon(
        Icons.casino_outlined,
        size: 80,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

class _GameStats extends StatelessWidget {
  const _GameStats({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (game.minPlayers != null || game.maxPlayers != null)
          _StatItem(
            icon: Icons.people_outline_rounded,
            label: _playerRange(game),
            title: 'Players',
          ),
        if (game.minPlayTimeMinutes != null || game.maxPlayTimeMinutes != null)
          _StatItem(
            icon: Icons.timer_outlined,
            label: _playTime(game),
            title: 'Play Time',
          ),
        if (game.averageRating != null)
          _StatItem(
            icon: Icons.star_rounded,
            label: game.averageRating!.toStringAsFixed(1),
            title: 'BGG Rating',
          ),
      ],
    );
  }

  String _playerRange(Game g) {
    if (g.minPlayers != null && g.maxPlayers != null) {
      if (g.minPlayers == g.maxPlayers) return '${g.minPlayers}';
      return '${g.minPlayers}–${g.maxPlayers}';
    }
    if (g.minPlayers != null) return '${g.minPlayers}+';
    return '${g.maxPlayers}';
  }

  String _playTime(Game g) {
    if (g.minPlayTimeMinutes != null && g.maxPlayTimeMinutes != null) {
      if (g.minPlayTimeMinutes == g.maxPlayTimeMinutes) {
        return '${g.minPlayTimeMinutes}m';
      }
      return '${g.minPlayTimeMinutes}–${g.maxPlayTimeMinutes}m';
    }
    if (g.minPlayTimeMinutes != null) return '${g.minPlayTimeMinutes}m';
    return '${g.maxPlayTimeMinutes}m';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.title,
  });

  final IconData icon;
  final String label;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        AppSpacing.vGapXs,
        Text(label, style: AppTypography.titleSmall),
        Text(title, style: AppTypography.bodySmall),
      ],
    );
  }
}

class _GameDetailSkeleton extends StatelessWidget {
  const _GameDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: [
          const SkeletonBox(height: 280),
          Padding(
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSpacing.vGapXl,
                const SkeletonBox(height: 16),
                AppSpacing.vGapSm,
                const SkeletonBox(width: 200, height: 14),
                AppSpacing.vGapXl,
                const SkeletonBox(height: 14),
                AppSpacing.vGapXs,
                const SkeletonBox(height: 14),
                AppSpacing.vGapXs,
                const SkeletonBox(width: 160, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// FAB-style add-to-collection button shown at the bottom of game detail.
class AddToCollectionFab extends ConsumerWidget {
  const AddToCollectionFab({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppButton(
        label: 'Add to Collection',
        icon: Icons.add_rounded,
        onPressed: () => ref.read(collectionNotifierProvider.notifier).addGame(
              gameId: gameId,
              isOwned: true,
            ),
      ),
    );
  }
}
