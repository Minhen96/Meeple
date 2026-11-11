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
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/post_card.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/social/presentation/report_sheet.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Post detail (SCREENS §7.2 / web `/posts/[postId]`): circle back + "Post"
/// + circle share header, author row with the date, a rounded card with
/// images, like / comment counts, caption, game chip and tagged friends,
/// the COMMENTS list (edit 24 h, delete, report) and a pinned comment bar.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final post = ref.watch(postDetailProvider(postId));
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.postTitle,
        compactTitle: true,
        leading: const CircleBackButton(
          color: AppColors.surfaceContainerHigh,
        ),
        actions: [
          if (post.hasValue)
            CircleIconButton(
              key: const Key('post-share'),
              icon: Icons.share_outlined,
              iconSize: 20,
              tooltip: l10n.commonShare,
              color: AppColors.surfaceContainerHigh,
              onPressed: () => sharePost(context, post.requireValue),
            ),
        ],
      ),
      body: post.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is NotFoundException
            ? const _NotFound()
            : ErrorState(
                error: e,
                onRetry: () => ref.invalidate(postDetailProvider(postId)),
              ),
        data: (p) => Stack(
          children: [
            Positioned.fill(child: _PostBody(post: p)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CommentInput(postId: p.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hide_image_outlined,
              size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            AppSpacing.vGapLg,
            Text(l10n.postRemoved, style: AppTypography.titleLarge),
            AppSpacing.vGapLg,
            GestureDetector(
              onTap: () => context.go(AppRoutes.home),
              child: Text(
                l10n.postBackHome,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post});

  final Post post;

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.read(postActionsProvider);
    final comments = ref.watch(commentsNotifierProvider(post.id));
    final author = post.author;
    final name = displayNameOf(context, author);
    final meta = [
      DateFormat.yMMMMd().format(post.createdAt.toLocal()).toUpperCase(),
      if (post.location != null && post.location!.isNotEmpty) post.location!,
      if (post.editedAt != null) l10n.postEdited.toUpperCase(),
    ].join(' · ');
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
          ref.read(commentsNotifierProvider(post.id).notifier).loadMore();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          128,
        ),
        children: [
          // Author row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: author.deleted ? null : author.avatarUrl,
                  displayName: name,
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
                      Text(
                        meta,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('post-menu-${post.id}'),
                  tooltip: l10n.commonMore,
                  color: AppColors.onSurfaceVariant,
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => showPostMenu(context, ref, post),
                ),
              ],
            ),
          ),
          AppSpacing.vGapLg,
          _PostCardBody(
            post: post,
            onLike: () => _run(context, () => actions.toggleLike(post)),
            onBookmark: () => _run(context, () => actions.toggleBookmark(post)),
          ),
          AppSpacing.vGapXl,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              l10n.postCommentsLabel.toUpperCase(),
              style: AppTypography.overline.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ),
          AppSpacing.vGapXl,
          ...comments.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [
              ErrorState(
                error: e,
                onRetry: () =>
                    ref.invalidate(commentsNotifierProvider(post.id)),
              ),
            ],
            data: (s) => s.items.isEmpty
                ? [const _NoComments()]
                : [
                    for (final c in s.items)
                      _CommentTile(postId: post.id, comment: c),
                    if (s.isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// `bg-surface-container-low rounded-[32px]` card: images, counts row,
/// likes line, caption, game chip and tagged friends.
class _PostCardBody extends StatelessWidget {
  const _PostCardBody({
    required this.post,
    required this.onLike,
    required this.onBookmark,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = post;
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.panel)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.imageUrls.isNotEmpty) PostImages(urls: p.imageUrls),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CountButton(
                      key: ValueKey('like-${p.id}'),
                      icon:
                          p.likedByMe ? Icons.favorite : Icons.favorite_border,
                      color: p.likedByMe ? AppColors.error : null,
                      count: p.likeCount,
                      tooltip: p.likedByMe ? l10n.postUnlike : l10n.postLike,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 20),
                    _CountButton(
                      icon: Icons.chat_bubble_outline,
                      count: p.commentCount,
                      tooltip: l10n.postComment,
                    ),
                    const SizedBox(width: 20),
                    _CountButton(
                      icon: Icons.share_outlined,
                      tooltip: l10n.commonShare,
                      onTap: () => sharePost(context, p),
                    ),
                    const Spacer(),
                    _CountButton(
                      key: ValueKey('bookmark-${p.id}'),
                      icon: p.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: p.isBookmarked ? AppColors.primary : null,
                      tooltip: p.isBookmarked ? l10n.postUnsave : l10n.postSave,
                      onTap: onBookmark,
                    ),
                  ],
                ),
                if (p.likeCount > 0) ...[
                  AppSpacing.vGapLg,
                  Text(
                    l10n.postLikes(p.likeCount),
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
                if (p.caption.isNotEmpty) ...[
                  AppSpacing.vGapLg,
                  Text(
                    p.caption,
                    style: AppTypography.bodyMedium.copyWith(height: 1.6),
                  ),
                ],
                if (p.playedAt != null) ...[
                  AppSpacing.vGapSm,
                  Text(
                    l10n.postPlayedOn(AppDateUtils.formatDate(p.playedAt!)),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (p.game != null) ...[
                  AppSpacing.vGapLg,
                  _GameChip(gameId: p.game!.id, name: p.game!.name),
                ],
                if (p.taggedUsers.isNotEmpty) ...[
                  AppSpacing.vGapLg,
                  Row(
                    children: [
                      Text(
                        l10n.postWithLabel.toUpperCase(),
                        style: AppTypography.overline.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      AppSpacing.hGapSm,
                      AvatarStack(users: p.taggedUsers, size: 32),
                    ],
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

/// Icon (24px) with an optional bold count (web action row).
class _CountButton extends StatelessWidget {
  const _CountButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.count,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int? count;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.onSurfaceVariant;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: fg),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTypography.titleSmall.copyWith(color: fg),
          ),
        ],
      ],
    );
    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? content
          : InkResponse(onTap: onTap, radius: 24, child: content),
    );
  }
}

/// Web game chip: `bg-secondary/10` pill, casino icon, 10px uppercase.
class _GameChip extends StatelessWidget {
  const _GameChip({required this.gameId, required this.name});

  final String gameId;
  final String name;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.secondary.withValues(alpha: 0.1),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('post-game-chip'),
          onTap: () => context.push(AppRoutes.gameDetail(gameId)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.casino_outlined,
                  size: 14,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    name.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _NoComments extends StatelessWidget {
  const _NoComments();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          children: [
            Icon(
              Icons.forum_outlined,
              size: 30,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            AppSpacing.vGapSm,
            Text(
              context.l10n.postFirstComment,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
}

/// A comment: avatar, name + time, body and inline Edit / Delete / Report
/// links (web), with the same actions on long press.
class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.postId, required this.comment});

  final String postId;
  final Comment comment;

  Future<void> _act(BuildContext context, WidgetRef ref, String choice) async {
    final l10n = context.l10n;
    final notifier = ref.read(commentsNotifierProvider(postId).notifier);
    try {
      switch (choice) {
        case 'edit':
          final text = await showDialog<String>(
            context: context,
            builder: (_) => _EditCommentDialog(initial: comment.content),
          );
          if (text != null && text.trim().isNotEmpty) {
            await notifier.edit(comment.id, text.trim());
          }
        case 'delete':
          final ok = await showConfirmSheet(
            context,
            title: l10n.commentDeleteTitle,
            message: l10n.commentDeleteMessage,
            confirmLabel: l10n.commonDelete,
          );
          if (ok) await notifier.delete(comment.id);
        case 'report':
          await showReportSheet(
            context,
            ref,
            targetType: 'comment',
            targetId: comment.id,
          );
      }
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = comment;
    final me = ref.watch(authNotifierProvider).valueOrNull;
    final mine = me != null && me.id == c.authorId;
    // The post's author may remove any comment on it.
    final postAuthorId =
        ref.watch(postDetailProvider(postId)).valueOrNull?.author.id;
    final canDelete = mine || (me != null && me.id == postAuthorId);
    final links = [
      if (mine && c.canEdit()) ('edit', l10n.commonEdit),
      if (canDelete) ('delete', l10n.commonDelete),
      if (!mine) ('report', l10n.commentReportShort),
    ];
    final name = displayNameOf(context, c.author);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppAvatar(
              imageUrl: c.authorDeleted ? null : c.authorAvatarUrl,
              displayName: name,
              size: AvatarSize.sm,
              onTap: c.authorDeleted
                  ? null
                  : () => context.push(AppRoutes.userProfile(c.authorId)),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$name  ',
                        style: AppTypography.labelMedium.copyWith(
                          fontFamily: AppTypography.titleSmall.fontFamily,
                          color: c.authorDeleted
                              ? AppColors.onSurfaceVariant
                              : AppColors.onSurface,
                        ),
                      ),
                      TextSpan(
                        text: [
                          AppDateUtils.timeAgo(c.createdAt, l10n),
                          if (c.editedAt != null) l10n.postEdited,
                        ].join(' · '),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vGapXs,
                GestureDetector(
                  onLongPress: links.isEmpty
                      ? null
                      : () => _showMenu(context, ref, links),
                  child: Text(
                    c.content,
                    style: AppTypography.bodyMedium.copyWith(height: 1.35),
                  ),
                ),
                if (links.isNotEmpty) ...[
                  AppSpacing.vGapXs,
                  Wrap(
                    spacing: AppSpacing.md,
                    children: [
                      for (final (action, label) in links)
                        GestureDetector(
                          key: ValueKey('comment-$action-${c.id}'),
                          onTap: () => _act(context, ref, action),
                          child: Text(
                            label,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    List<(String, String)> links,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (action, label) in links)
              ListTile(
                title: Text(
                  label,
                  style: action == 'delete'
                      ? const TextStyle(color: AppColors.error)
                      : null,
                ),
                onTap: () => Navigator.of(sheet).pop(action),
              ),
          ],
        ),
      ),
    );
    if (choice != null && context.mounted) await _act(context, ref, choice);
  }
}

/// Pinned comment bar: a pill input with a round primary send button over
/// a fade from the page background.
class _CommentInput extends ConsumerStatefulWidget {
  const _CommentInput({required this.postId});

  final String postId;

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(commentsNotifierProvider(widget.postId).notifier)
          .add(text);
      _controller.clear();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0, 0.6, 1],
          colors: [
            AppColors.surface,
            AppColors.surface,
            AppColors.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: AppSpacing.borderRadiusFull,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('comment-input'),
                    controller: _controller,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: l10n.postAddComment,
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      counterText: '',
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                AppSpacing.hGapMd,
                Tooltip(
                  message: l10n.commonSend,
                  child: Opacity(
                    opacity: canSend ? 1 : 0.4,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('comment-send'),
                        onTap: canSend ? _send : null,
                        child: const SizedBox.square(
                          dimension: 40,
                          child: Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
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

/// Owns its controller so it is disposed only after the dialog is gone.
class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initial});

  final String initial;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.commentEditTitle),
      content: TextField(
        key: const Key('comment-edit-field'),
        controller: _controller,
        maxLength: 1000,
        maxLines: 4,
        autofocus: true,
      ),
      actions: [
        AppTextButton(
          label: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppTextButton(
          key: const Key('comment-edit-save'),
          label: l10n.commonSave,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
