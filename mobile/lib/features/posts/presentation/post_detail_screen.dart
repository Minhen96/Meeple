import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Post detail screen — Phase 1 stub.
///
/// Full implementation loads the post by [postId], renders comments,
/// and supports like / comment / share actions.
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MeepleAppBar(
        title: 'Post',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          // Post body skeleton
          const PostCardSkeleton(),
          const Divider(color: AppColors.outlineVariant, height: 1),
          // Actions row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.favorite_border_rounded,
                  label: '—',
                  onTap: () {},
                ),
                AppSpacing.hGapLg,
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '—',
                  onTap: () {},
                ),
                AppSpacing.hGapLg,
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.outlineVariant, height: 1),
          Padding(
            padding: AppSpacing.pagePadding,
            child: Text('Comments', style: AppTypography.titleMedium),
          ),
          // Comment skeletons
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonCircle(size: 32),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 100, height: 12),
                        SizedBox(height: AppSpacing.xs),
                        SkeletonBox(height: 12),
                        SizedBox(height: 4),
                        SkeletonBox(width: 180, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _CommentInput(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusSm,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.sm,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Write a comment…',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            AppSpacing.hGapSm,
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: AppColors.primary,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
