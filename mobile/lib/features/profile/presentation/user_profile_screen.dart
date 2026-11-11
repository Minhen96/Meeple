import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/profile/presentation/own_profile_screen.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/profile/presentation/profile_view.dart';
import 'package:meeple_hearth/features/profile/presentation/widgets/profile_action_sheet.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/features/social/presentation/friend_button.dart';
import 'package:meeple_hearth/features/social/presentation/report_sheet.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_back_brand_bar.dart';
import 'package:share_plus/share_plus.dart';

/// Another user's profile (SCREENS §8.2): friend actions, block, report.
/// A blocked relationship returns 404 → "not available".
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final choice = await showProfileActionSheet(
      context,
      keyPrefix: 'profile',
      actions: [
        (
          id: 'share',
          icon: Icons.share_outlined,
          label: l10n.profileShare,
          danger: false
        ),
        (
          id: 'report',
          icon: Icons.flag_outlined,
          label: l10n.profileReport,
          danger: false
        ),
        (
          id: 'block',
          icon: Icons.block_rounded,
          label: l10n.profileBlock,
          danger: true
        ),
      ],
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'share':
        await Share.share('${AppConfig.webOrigin}/profile/$userId');
      case 'block':
        final ok = await showConfirmSheet(
          context,
          title: l10n.profileBlockTitle,
          message: l10n.profileBlockMessage,
          confirmLabel: l10n.profileBlock,
          icon: Icons.block_rounded,
        );
        if (!ok || !context.mounted) return;
        try {
          await ref.read(friendStatusNotifierProvider(userId).notifier).block();
          if (!context.mounted) return;
          showToast(context, l10n.profileBlocked, type: ToastType.success);
          context.canPop() ? context.pop() : context.go(AppRoutes.home);
        } catch (e) {
          if (context.mounted) showErrorToast(context, e);
        }
      case 'report':
        await showReportSheet(context, ref,
            targetType: 'user', targetId: userId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(authNotifierProvider).valueOrNull;
    if (me?.id == userId) return const OwnProfileScreen();
    final profile = ref.watch(userProfileProvider(userId));
    return Scaffold(
      appBar: const MeepleBackBrandBar(fallbackRoute: AppRoutes.home),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is NotFoundException
            ? EmptyState(
                icon: Icons.person_off_outlined,
                title: l10n.profileUnavailable,
              )
            : ErrorState(
                error: e,
                onRetry: () => ref.invalidate(userProfileProvider(userId)),
              ),
        data: (user) => RefreshIndicator(
          notificationPredicate: (n) => n.depth == 0,
          onRefresh: () async {
            ref
              ..invalidate(userProfileProvider(userId))
              ..invalidate(userStatsProvider(userId))
              ..invalidate(userFavoritesProvider(userId))
              ..invalidate(userCollectionProvider(userId))
              ..invalidate(userPostsProvider(userId))
              ..invalidate(taggedPostsProvider(userId))
              ..invalidate(friendStatusNotifierProvider(userId));
          },
          child: ProfileView(
            user: user,
            isSelf: false,
            actions: Row(
              children: [
                Expanded(child: FriendButton(userId: userId)),
                AppSpacing.hGapSm,
                ProfileMoreButton(
                  key: const Key('user-profile-menu'),
                  tooltip: l10n.commonMore,
                  onPressed: () => _menu(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
