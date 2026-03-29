import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';

/// Feed card for a single [Post].
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onLikeTap,
    this.onCommentTap,
  });

  final Post post;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.postDetail(post.id)),
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostHeader(post: post),
            AppSpacing.vGapMd,
            Text(post.content, style: AppTypography.bodyMedium),
            if (post.imageUrls.isNotEmpty) ...[
              AppSpacing.vGapMd,
              _PostImageGrid(imageUrls: post.imageUrls),
            ],
            if (post.taggedGameId != null) ...[
              AppSpacing.vGapSm,
              AppChip(
                label: 'Game',
                icon: Icons.sports_esports_rounded,
                variant: AppChipVariant.primary,
              ),
            ],
            AppSpacing.vGapMd,
            _PostActions(
              post: post,
              onLikeTap: onLikeTap,
              onCommentTap: onCommentTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(post.createdAt);
    return Row(
      children: [
        AppAvatar(
          imageUrl: post.authorAvatarUrl,
          displayName: post.authorDisplayName,
          size: 40,
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorDisplayName,
                style: AppTypography.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '@${post.authorUsername} · $timeAgo',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
  }
}

class _PostImageGrid extends StatelessWidget {
  const _PostImageGrid({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: AppSpacing.borderRadiusLg,
        child: CachedNetworkImage(
          imageUrl: imageUrls.first,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusLg),
                bottomLeft: Radius.circular(AppSpacing.radiusLg),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrls[0],
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppSpacing.radiusLg),
                bottomRight: Radius.circular(AppSpacing.radiusLg),
              ),
              child: imageUrls.length > 2
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrls[1],
                          fit: BoxFit.cover,
                        ),
                        ColoredBox(
                          color: AppColors.scrimOverlay,
                          child: Center(
                            child: Text(
                              '+${imageUrls.length - 2}',
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrls[1],
                      height: 160,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostActions extends StatelessWidget {
  const _PostActions({
    required this.post,
    this.onLikeTap,
    this.onCommentTap,
  });

  final Post post;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: post.isLikedByMe
              ? Icons.favorite_rounded
              : Icons.favorite_outline_rounded,
          label: '${post.likeCount}',
          color: post.isLikedByMe ? AppColors.error : AppColors.onSurfaceVariant,
          onTap: onLikeTap,
        ),
        AppSpacing.hGapLg,
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: '${post.commentCount}',
          color: AppColors.onSurfaceVariant,
          onTap: onCommentTap,
        ),
        const Spacer(),
        _ActionButton(
          icon: Icons.share_outlined,
          label: '',
          color: AppColors.onSurfaceVariant,
          onTap: () {},
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          if (label.isNotEmpty) ...[
            AppSpacing.hGapXs,
            Text(label, style: AppTypography.bodySmall.copyWith(color: color)),
          ],
        ],
      ),
    );
  }
}
