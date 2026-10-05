import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';

/// "Add Friend" → "Pending" → "Friends" button (CLAUDE.md social wording;
/// never "Follow").
class FriendButton extends ConsumerStatefulWidget {
  const FriendButton({
    super.key,
    required this.userId,
    this.compact = false,
    this.initial,
  });

  final String userId;
  final bool compact;

  /// Status already known from a list response, shown while loading.
  final FriendshipStatus? initial;

  @override
  ConsumerState<FriendButton> createState() => _FriendButtonState();
}

class _FriendButtonState extends ConsumerState<FriendButton> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, {String? success}) async {
    setState(() => _busy = true);
    try {
      await f();
      if (success != null && mounted) {
        showToast(context, success, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = ref.watch(authNotifierProvider).valueOrNull;
    if (me?.id == widget.userId) return const SizedBox.shrink();
    final status = ref.watch(friendStatusNotifierProvider(widget.userId));
    final notifier = ref.read(friendStatusNotifierProvider(widget.userId).notifier);
    final current = status.valueOrNull?.status ?? widget.initial;
    if (current == null) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final style = widget.compact
        ? const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
          )
        : null;
    switch (current) {
      case FriendshipStatus.none:
        return FilledButton.icon(
          key: ValueKey('add-friend-${widget.userId}'),
          style: (style ?? const ButtonStyle()).merge(
            FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
            ),
          ),
          onPressed: _busy
              ? null
              : () => _run(notifier.sendRequest, success: l10n.friendRequestSent),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: Text(l10n.friendAdd),
        );
      case FriendshipStatus.pendingSent:
        return OutlinedButton(
          key: ValueKey('pending-${widget.userId}'),
          style: style,
          onPressed: _busy
              ? null
              : () async {
                  final ok = await showConfirmSheet(
                    context,
                    title: l10n.friendCancelTitle,
                    message: l10n.friendCancelMessage,
                    confirmLabel: l10n.friendCancelRequest,
                    destructive: false,
                  );
                  if (ok) await _run(notifier.cancelRequest);
                },
          child: Text(l10n.friendPending),
        );
      case FriendshipStatus.pendingReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              key: ValueKey('accept-${widget.userId}'),
              style: style,
              onPressed: _busy ? null : () => _run(notifier.accept),
              child: Text(l10n.friendAccept),
            ),
            AppSpacing.hGapXs,
            TextButton(
              key: ValueKey('decline-${widget.userId}'),
              onPressed: _busy ? null : () => _run(notifier.decline),
              child: Text(l10n.friendDecline),
            ),
          ],
        );
      case FriendshipStatus.friends:
        return FilledButton.tonalIcon(
          key: ValueKey('friends-${widget.userId}'),
          style: (style ?? const ButtonStyle()).merge(
            FilledButton.styleFrom(
              backgroundColor: AppColors.tertiaryContainer,
              foregroundColor: AppColors.onTertiaryContainer,
              shape: const StadiumBorder(),
            ),
          ),
          onPressed: _busy
              ? null
              : () async {
                  final ok = await showConfirmSheet(
                    context,
                    title: l10n.friendUnfriendTitle,
                    message: l10n.friendUnfriendMessage,
                    confirmLabel: l10n.friendUnfriend,
                  );
                  if (ok) await _run(notifier.unfriend);
                },
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(l10n.friendFriends),
        );
      case FriendshipStatus.blocked:
        return OutlinedButton(
          key: ValueKey('unblock-${widget.userId}'),
          style: style,
          onPressed: _busy ? null : () => _run(notifier.unblock),
          child: Text(l10n.friendUnblock),
        );
    }
  }
}
