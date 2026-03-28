import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Authenticated user's own profile screen — Phase 1 stub.
class OwnProfileScreen extends ConsumerWidget {
  const OwnProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: MeepleAppBar(
        title: user?.username ?? 'Profile',
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: authState.isLoading
          ? const _ProfileSkeleton()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    displayName: user?.displayName ?? '',
                    username: user?.username ?? '',
                    avatarUrl: user?.avatarUrl,
                    bio: user?.bio,
                    location: user?.location,
                  ),
                ),
                SliverToBoxAdapter(child: _StatsRow()),
                const SliverToBoxAdapter(
                  child: Divider(color: AppColors.outlineVariant, height: 1),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppSpacing.pagePadding,
                    child: Text(
                      'Recent Activity',
                      style: AppTypography.titleMedium,
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const PostCardSkeleton(),
                    childCount: 3,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
              ],
            ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.location,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final String? location;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        children: [
          AppSpacing.vGapLg,
          AppAvatar(
            size: 80,
            imageUrl: avatarUrl,
            displayName: displayName,
          ),
          AppSpacing.vGapMd,
          Text(displayName, style: AppTypography.headlineSmall),
          AppSpacing.vGapXs,
          Text(
            '@$username',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (bio != null && bio!.isNotEmpty) ...[
            AppSpacing.vGapMd,
            Text(
              bio!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (location != null && location!.isNotEmpty) ...[
            AppSpacing.vGapXs,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  location!,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ],
          AppSpacing.vGapXl,
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _StatItem(value: '—', label: 'Games'),
          _Divider(),
          _StatItem(value: '—', label: 'Friends'),
          _Divider(),
          _StatItem(value: '—', label: 'Posts'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.headlineSmall),
        AppSpacing.vGapXs,
        Text(label, style: AppTypography.bodySmall),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.outlineVariant,
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
