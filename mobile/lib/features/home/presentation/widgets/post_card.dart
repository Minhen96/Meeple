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
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a post's web link through the native share sheet.
Future<void> sharePost(BuildContext context, Post post) =>
    Share.share('${AppConfig.webOrigin}/posts/${post.id}');

/// Feed post card (SCREENS §7.3) — matches the web `PostCard`: white
/// rounded-2xl card with the soft feed shadow, author row, images, the
/// like / comment / share … bookmark row, caption with the author's name in
/// bold, "Played X", tagged friends, comment count and a quick-comment pill.
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
    final name = displayNameOf(context, post.author);
    const small = TextStyle(fontSize: 11, height: 1.45);
    return AppCard(
      tone: AppCardTone.elevated,
      radius: AppRadius.card,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.likeCount > 0)
                  _Spaced(
                    Text(
                      l10n.postLikes(post.likeCount),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                if (post.caption.isNotEmpty)
                  _Spaced(
                    GestureDetector(
                      onTap: open,
                      child: Text.rich(
                        TextSpan(
                          style: AppTypography.bodyMedium.copyWith(height: 1.375),
                          children: [
                            TextSpan(
                              text: name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${post.caption}'),
                          ],
                        ),
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (post.game != null)
                  _Spaced(
                    GameTagChip(gameId: post.game!.id, name: post.game!.name),
                  ),
                if (post.taggedUsers.isNotEmpty)
                  _Spaced(
                    Text.rich(
                      TextSpan(
                        style: AppTypography.bodySmall.merge(small),
                        children: [
                          TextSpan(text: '${l10n.postWith} '),
                          TextSpan(
                            text: post.taggedUsers
                                .map((u) => displayNameOf(context, u))
                                .join(', '),
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (post.commentCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: GestureDetector(
                      onTap: open,
                      child: Text(
                        l10n.postViewComments(post.commentCount),
                        style: AppTypography.bodySmall.merge(small),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: QuickCommentField(post: post),
            ),
        ],
      ),
    );
  }
}

/// A line of the card body with the web `space-y-1.5` gap above it.
class _Spaced extends StatelessWidget {
  const _Spaced(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: child);
}

/// "Add a comment…" pill under a feed card; a POST action appears once
/// something is typed (web quick comment).
class QuickCommentField extends ConsumerStatefulWidget {
  const QuickCommentField({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<QuickCommentField> createState() => _QuickCommentFieldState();
}

class _QuickCommentFieldState extends ConsumerState<QuickCommentField> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await ref.read(postActionsProvider).addComment(widget.post, body);
      _controller.clear();
      if (mounted) showToast(context, l10n.postCommentPosted, type: ToastType.success);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const text = TextStyle(fontSize: 11, height: 1.45);
    final hasText = _controller.text.trim().isNotEmpty;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('quick-comment-${widget.post.id}'),
              controller: _controller,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: AppTypography.bodyMedium.merge(text),
              decoration: InputDecoration(
                hintText: l10n.postAddComment,
                hintStyle: AppTypography.bodyMedium.merge(text).copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                filled: false,
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              key: ValueKey('quick-comment-send-${widget.post.id}'),
              onTap: _sending ? null : _send,
              child: Opacity(
                opacity: _sending ? 0.5 : 1,
                child: Text(
                  l10n.postPublish.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.55,
                    color: AppColors.primary,
                  ),
                ),
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
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: author.deleted ? null : author.avatarUrl,
            displayName: name,
            size: AvatarSize.sm,
            onTap: author.deleted
                ? null
                : () => context.push(AppRoutes.userProfile(author.id)),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.titleSmall.copyWith(
                    color: author.deleted
                        ? AppColors.onSurfaceVariant
                        : AppColors.onSurface,
                  ),
                ),
                Text(meta, style: AppTypography.labelSmall),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('post-menu-${post.id}'),
            tooltip: l10n.commonMore,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            color: AppColors.onSurfaceVariant,
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

/// Like · comment · share … bookmark (web: plain 24px icons, 16px apart).
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          _ActionIcon(
            key: ValueKey('like-${post.id}'),
            tooltip: post.likedByMe ? l10n.postUnlike : l10n.postLike,
            onPressed: onLike,
            icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
            color: post.likedByMe ? AppColors.error : null,
          ),
          _ActionIcon(
            tooltip: l10n.postComment,
            onPressed: onComment,
            icon: Icons.chat_bubble_outline,
          ),
          _ActionIcon(
            tooltip: l10n.commonShare,
            onPressed: onShare,
            icon: Icons.share_outlined,
          ),
          const Spacer(),
          _ActionIcon(
            key: ValueKey('bookmark-${post.id}'),
            tooltip: post.isBookmarked ? l10n.postUnsave : l10n.postSave,
            onPressed: onBookmark,
            icon: post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: post.isBookmarked ? AppColors.primary : null,
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      // 24px icon + 16px gap, like the web `gap-4` row.
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      icon: Icon(icon, size: 24, color: color ?? AppColors.onSurfaceVariant),
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

/// Tagged-game line — web "🎲 *Played Azul*" (11px bold italic primary with a
/// casino icon). Tap opens Game Detail.
class GameTagChip extends StatelessWidget {
  const GameTagChip({super.key, required this.gameId, required this.name});

  final String gameId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.gameDetail(gameId)),
      borderRadius: AppSpacing.borderRadiusSm,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.casino_outlined,
            size: 13,
            color: AppColors.onSurfaceVariant,
          ),
          AppSpacing.hGapXs,
          Flexible(
            child: Text(
              context.l10n.postPlayed(name),
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
