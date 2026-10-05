import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/social/presentation/report_sheet.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a post's web link through the native share sheet.
Future<void> sharePost(BuildContext context, Post post) =>
    Share.share('${AppConfig.webOrigin}/posts/${post.id}');

/// Feed post card (SCREENS §7.3, DESIGN post card).
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.compact = false});

  final Post post;

  /// Compact cards (game sessions tab) hide the caption beyond 2 lines.
  final bool compact;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.read(postActionsProvider);
    void open() => context.push(AppRoutes.postDetail(post.id));
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusXl,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(post: post),
          if (post.imageUrls.isNotEmpty)
            GestureDetector(
              onTap: open,
              child: PostImages(urls: post.imageUrls),
            ),
          PostActionBar(
            post: post,
            onLike: () => _run(context, () => actions.toggleLike(post)),
            onComment: open,
            onShare: () => sharePost(context, post),
            onBookmark: () => _run(context, () => actions.toggleBookmark(post)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.likeCount > 0)
                  Text(
                    l10n.postLikes(post.likeCount),
                    style: AppTypography.labelLarge,
                  ),
                if (post.caption.isNotEmpty) ...[
                  AppSpacing.vGapXs,
                  GestureDetector(
                    onTap: open,
                    child: Text(
                      post.caption,
                      style: AppTypography.bodyMedium,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (post.game != null) ...[
                  AppSpacing.vGapSm,
                  GameTagChip(gameId: post.game!.id, name: post.game!.name),
                ],
                if (post.commentCount > 0) ...[
                  AppSpacing.vGapSm,
                  GestureDetector(
                    onTap: open,
                    child: Text(
                      l10n.postViewComments(post.commentCount),
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Author row with time, location and the "···" menu.
class PostHeader extends ConsumerWidget {
  const PostHeader({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final author = post.author;
    final name = displayNameOf(context, author);
    final meta = [
      AppDateUtils.timeAgo(post.createdAt, l10n),
      if (post.location != null && post.location!.isNotEmpty) post.location!,
      if (post.editedAt != null) l10n.postEdited,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: author.deleted ? null : author.avatarUrl,
            displayName: name,
            size: AvatarSize.md,
            onTap: author.deleted
                ? null
                : () => context.push(AppRoutes.userProfile(author.id)),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleSmall),
                Text(meta, style: AppTypography.labelSmall),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('post-menu-${post.id}'),
            tooltip: l10n.commonMore,
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => showPostMenu(context, ref, post),
          ),
        ],
      ),
    );
  }
}

/// Own posts: edit (48 h) and delete; others: report.
Future<void> showPostMenu(BuildContext context, WidgetRef ref, Post post) async {
  final l10n = context.l10n;
  final me = ref.read(authNotifierProvider).valueOrNull;
  final mine = me != null && me.id == post.author.id;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.commonShare),
            onTap: () => Navigator.of(sheetContext).pop('share'),
          ),
          if (mine && post.canEdit())
            ListTile(
              key: const Key('post-menu-edit'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.commonEdit),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
          if (mine)
            ListTile(
              key: const Key('post-menu-delete'),
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                l10n.postDelete,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          if (!mine)
            ListTile(
              key: const Key('post-menu-report'),
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.reportPost),
              onTap: () => Navigator.of(sheetContext).pop('report'),
            ),
          AppSpacing.vGapSm,
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'share':
      await sharePost(context, post);
    case 'edit':
      await context.push(AppRoutes.editPost(post.id));
    case 'delete':
      final ok = await showConfirmSheet(
        context,
        title: l10n.postDeleteTitle,
        message: l10n.postDeleteMessage,
        confirmLabel: l10n.commonDelete,
      );
      if (!ok || !context.mounted) return;
      try {
        await ref.read(postActionsProvider).delete(post.id);
        if (context.mounted) {
          showToast(context, l10n.postDeleted, type: ToastType.success);
          if (GoRouterState.of(context).uri.path == AppRoutes.postDetail(post.id)) {
            context.canPop() ? context.pop() : context.go(AppRoutes.home);
          }
        }
      } catch (e) {
        if (context.mounted) showErrorToast(context, e);
      }
    case 'report':
      await showReportSheet(context, ref, targetType: 'post', targetId: post.id);
  }
}

/// Like · comment · share … bookmark.
class PostActionBar extends StatelessWidget {
  const PostActionBar({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            key: ValueKey('like-${post.id}'),
            tooltip: post.likedByMe ? l10n.postUnlike : l10n.postLike,
            onPressed: onLike,
            icon: Icon(
              post.likedByMe
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: post.likedByMe ? AppColors.error : AppColors.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: l10n.postComment,
            onPressed: onComment,
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: l10n.commonShare,
            onPressed: onShare,
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          IconButton(
            key: ValueKey('bookmark-${post.id}'),
            tooltip: post.isBookmarked ? l10n.postUnsave : l10n.postSave,
            onPressed: onBookmark,
            icon: Icon(
              post.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: post.isBookmarked ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable square images with dot indicators.
class PostImages extends StatefulWidget {
  const PostImages({super.key, required this.urls});

  final List<String> urls;

  @override
  State<PostImages> createState() => _PostImagesState();
}

class _PostImagesState extends State<PostImages> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => ColoredBox(
              color: AppColors.surfaceContainerLow,
              child: CachedNetworkImage(
                imageUrl: widget.urls[i],
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: AppSpacing.md,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.urls.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: i == _index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.primaryContainer
                            : AppColors.surfaceContainerLowest
                                .withValues(alpha: 0.7),
                        borderRadius: AppSpacing.borderRadiusFull,
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

/// Tagged-game chip (tap opens Game Detail).
class GameTagChip extends StatelessWidget {
  const GameTagChip({super.key, required this.gameId, required this.name});

  final String gameId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(
        Icons.sports_esports_outlined,
        size: 16,
        color: AppColors.onSecondaryContainer,
      ),
      label: Text(name),
      labelStyle: AppTypography.labelLarge.copyWith(
        color: AppColors.onSecondaryContainer,
      ),
      backgroundColor: AppColors.secondaryContainer,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onPressed: () => context.push(AppRoutes.gameDetail(gameId)),
    );
  }
}
