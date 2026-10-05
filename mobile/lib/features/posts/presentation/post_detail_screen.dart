import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Post detail (SCREENS §7.2): images, likes, bookmark, share, full caption,
/// tagged friends and comments (edit 24 h, delete, report).
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
        showBackButton: true,
        actions: [
          if (post.hasValue)
            IconButton(
              tooltip: l10n.commonShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => sharePost(context, post.requireValue),
            ),
        ],
      ),
      body: post.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is NotFoundException
            ? EmptyState(
                icon: Icons.hide_image_outlined,
                title: l10n.postRemoved,
              )
            : ErrorState(
                error: e,
                onRetry: () => ref.invalidate(postDetailProvider(postId)),
              ),
        data: (p) => Column(
          children: [
            Expanded(child: _PostBody(post: p)),
            _CommentInput(postId: p.id),
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
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
          ref.read(commentsNotifierProvider(post.id).notifier).loadMore();
        }
        return false;
      },
      child: ListView(
        children: [
          PostHeader(post: post),
          if (post.imageUrls.isNotEmpty) PostImages(urls: post.imageUrls),
          PostActionBar(
            post: post,
            onLike: () => _run(context, () => actions.toggleLike(post)),
            onComment: () {},
            onShare: () => sharePost(context, post),
            onBookmark: () => _run(context, () => actions.toggleBookmark(post)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.likeCount > 0)
                  Text(
                    l10n.postLikes(post.likeCount),
                    style: AppTypography.labelLarge,
                  ),
                if (post.caption.isNotEmpty) ...[
                  AppSpacing.vGapSm,
                  Text(post.caption, style: AppTypography.bodyLarge),
                ],
                if (post.playedAt != null) ...[
                  AppSpacing.vGapXs,
                  Text(
                    l10n.postPlayedOn(AppDateUtils.formatDate(post.playedAt!)),
                    style: AppTypography.bodySmall,
                  ),
                ],
                if (post.game != null) ...[
                  AppSpacing.vGapSm,
                  GameTagChip(gameId: post.game!.id, name: post.game!.name),
                ],
                if (post.taggedUsers.isNotEmpty) ...[
                  AppSpacing.vGapSm,
                  Row(
                    children: [
                      Text(l10n.postWith, style: AppTypography.labelLarge),
                      AppSpacing.hGapSm,
                      AvatarStack(users: post.taggedUsers, size: 28),
                    ],
                  ),
                ],
                AppSpacing.vGapLg,
                Text(
                  l10n.postCommentsTitle(post.commentCount),
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
          ),
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
                onRetry: () => ref.invalidate(commentsNotifierProvider(post.id)),
              ),
            ],
            data: (s) => s.items.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        l10n.postFirstComment,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ]
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
          AppSpacing.vGapXl,
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.postId, required this.comment});

  final String postId;
  final Comment comment;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final me = ref.read(authNotifierProvider).valueOrNull;
    final mine = me != null && me.id == comment.authorId;
    // The post's author may remove any comment on it.
    final postAuthorId =
        ref.read(postDetailProvider(postId)).valueOrNull?.author.id;
    final canDelete = mine || (me != null && me.id == postAuthorId);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine && comment.canEdit())
              ListTile(
                key: const Key('comment-edit'),
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.commonEdit),
                onTap: () => Navigator.of(sheet).pop('edit'),
              ),
            if (canDelete)
              ListTile(
                key: const Key('comment-delete'),
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  l10n.commonDelete,
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
            if (!mine)
              ListTile(
                key: const Key('comment-report'),
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.reportComment),
                onTap: () => Navigator.of(sheet).pop('report'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    final notifier = ref.read(commentsNotifierProvider(postId).notifier);
    try {
      switch (choice) {
        case 'edit':
          final text = await _editDialog(context, comment.content);
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

  Future<String?> _editDialog(BuildContext context, String initial) =>
      showDialog<String>(
        context: context,
        builder: (_) => _EditCommentDialog(initial: initial),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = comment;
    return InkWell(
      onLongPress: () => _menu(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              imageUrl: c.authorDeleted ? null : c.authorAvatarUrl,
              displayName: displayNameOf(context, c.author),
              size: AvatarSize.sm,
              onTap: c.authorDeleted
                  ? null
                  : () => context.push(AppRoutes.userProfile(c.authorId)),
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
                          text: c.authorDeleted || c.authorUsername.isEmpty
                              ? '${l10n.commonDeletedUser} '
                              : '@${c.authorUsername} ',
                          style: AppTypography.titleSmall,
                        ),
                        TextSpan(text: c.content, style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                  Text(
                    [
                      AppDateUtils.timeAgo(c.createdAt, l10n),
                      if (c.editedAt != null) l10n.postEdited,
                    ].join(' · '),
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('comment-menu-${c.id}'),
              tooltip: l10n.commonMore,
              iconSize: 18,
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => _menu(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(commentsNotifierProvider(widget.postId).notifier).add(text);
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
    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.glassBackground,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
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
                decoration: InputDecoration(
                  hintText: l10n.postAddComment,
                  counterText: '',
                ),
              ),
            ),
            AppSpacing.hGapSm,
            IconButton.filled(
              key: const Key('comment-send'),
              tooltip: l10n.commonSend,
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const Key('comment-edit-save'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
