import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmer-animated skeleton placeholder.
///
/// Wrap with [SkeletonShimmer] to apply the shimmer animation.
/// Individual bones are built with [SkeletonBox] and [SkeletonCircle].
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainerHigh,
      highlightColor: AppColors.surfaceContainerLowest,
      child: child,
    );
  }
}

/// A rounded rectangle bone inside a [SkeletonShimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppSpacing.borderRadiusMd,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// A circular bone inside a [SkeletonShimmer].
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pre-built skeleton for a post/feed card.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonCircle(size: 40),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(width: 120, height: 14),
                      AppSpacing.vGapXs,
                      const SkeletonBox(width: 80, height: 10),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMd,
            const SkeletonBox(height: 14),
            AppSpacing.vGapXs,
            const SkeletonBox(width: 200, height: 14),
            AppSpacing.vGapMd,
            const SkeletonBox(height: 180, borderRadius: AppSpacing.borderRadiusLg),
          ],
        ),
      ),
    );
  }
}

/// Pre-built skeleton for a game card.
class GameCardSkeleton extends StatelessWidget {
  const GameCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            height: 140,
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          AppSpacing.vGapSm,
          const SkeletonBox(height: 14),
          AppSpacing.vGapXs,
          const SkeletonBox(width: 60, height: 10),
        ],
      ),
    );
  }
}
