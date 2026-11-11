import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/social/presentation/widgets/people_widgets.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
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
    final notifier =
        ref.read(friendStatusNotifierProvider(widget.userId).notifier);
    final current = status.valueOrNull?.status ?? widget.initial;
    if (current == null) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final busy = _busy;
    Future<void> confirmCancel() async {
      final ok = await showConfirmSheet(
        context,
        title: l10n.friendCancelTitle,
        message: l10n.friendCancelMessage,
        confirmLabel: l10n.friendCancelRequest,
        destructive: false,
      );
      if (ok) await _run(notifier.cancelRequest);
    }

    Future<void> confirmUnfriend() async {
      final ok = await showConfirmSheet(
        context,
        title: l10n.friendUnfriendTitle,
        message: l10n.friendUnfriendMessage,
        confirmLabel: l10n.friendUnfriend,
        icon: Icons.person_remove_outlined,
      );
      if (ok) await _run(notifier.unfriend);
    }

    Future<void> add() =>
        _run(notifier.sendRequest, success: l10n.friendRequestSent);
    final id = widget.userId;

    if (widget.compact) {
      // Web `FriendButton` (size sm): small label pills.
      return switch (current) {
        FriendshipStatus.none => PeoplePillButton(
            key: ValueKey('add-friend-$id'),
            label: l10n.friendAdd,
            icon: Icons.person_add_alt_1_rounded,
            fill: AppColors.primary.withValues(alpha: 0.1),
            fg: AppColors.primary,
            onTap: busy ? null : add,
          ),
        FriendshipStatus.pendingSent => PeoplePillButton(
            key: ValueKey('pending-$id'),
            label: l10n.friendPending,
            fill: AppColors.surfaceContainerHigh,
            fg: AppColors.onSurfaceVariant,
            onTap: busy ? null : confirmCancel,
          ),
        FriendshipStatus.pendingReceived => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PeoplePillButton(
                key: ValueKey('accept-$id'),
                label: l10n.friendAccept,
                gradient: true,
                fg: AppColors.onPrimary,
                onTap: busy ? null : () => _run(notifier.accept),
              ),
              AppSpacing.hGapSm,
              PeoplePillButton(
                key: ValueKey('decline-$id'),
                label: l10n.friendDecline,
                fill: AppColors.surfaceContainerHigh,
                fg: AppColors.onSurfaceVariant,
                onTap: busy ? null : () => _run(notifier.decline),
              ),
            ],
          ),
        FriendshipStatus.friends => PeoplePillButton(
            key: ValueKey('friends-$id'),
            label: l10n.friendFriends,
            icon: Icons.check_rounded,
            fill: AppColors.tertiaryContainer.withValues(alpha: 0.4),
            fg: AppColors.onTertiaryContainer,
            onTap: busy ? null : confirmUnfriend,
          ),
        FriendshipStatus.blocked => PeoplePillButton(
            key: ValueKey('unblock-$id'),
            label: l10n.friendUnblock,
            fill: AppColors.surfaceContainerHigh,
            fg: AppColors.onSurfaceVariant,
            onTap: busy ? null : () => _run(notifier.unblock),
          ),
      };
    }

    // Profile action (web profile page `Button`): primary for Add Friend /
    // Accept, secondary for Pending / Friends.
    return switch (current) {
      FriendshipStatus.none => AppButton(
          key: ValueKey('add-friend-$id'),
          label: l10n.friendAdd,
          icon: Icons.person_add_alt_1_rounded,
          isLoading: busy,
          onPressed: busy ? null : add,
        ),
      FriendshipStatus.pendingSent => AppButton(
          key: ValueKey('pending-$id'),
          label: l10n.friendPending,
          variant: AppButtonVariant.secondary,
          onPressed: busy ? null : confirmCancel,
        ),
      FriendshipStatus.pendingReceived => Row(
          children: [
            Expanded(
              child: AppButton(
                key: ValueKey('accept-$id'),
                label: l10n.friendAcceptRequest,
                isLoading: busy,
                onPressed: busy ? null : () => _run(notifier.accept),
              ),
            ),
            AppSpacing.hGapSm,
            AppButton(
              key: ValueKey('decline-$id'),
              label: l10n.friendDecline,
              minWidth: 0,
              variant: AppButtonVariant.secondary,
              onPressed: busy ? null : () => _run(notifier.decline),
            ),
          ],
        ),
      FriendshipStatus.friends => AppButton(
          key: ValueKey('friends-$id'),
          label: l10n.friendFriends,
          icon: Icons.check_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: busy ? null : confirmUnfriend,
        ),
      FriendshipStatus.blocked => AppButton(
          key: ValueKey('unblock-$id'),
          label: l10n.friendUnblock,
          variant: AppButtonVariant.secondary,
          onPressed: busy ? null : () => _run(notifier.unblock),
        ),
    };
  }
}
