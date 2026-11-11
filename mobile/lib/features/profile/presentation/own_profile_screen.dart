import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/profile/presentation/profile_view.dart';
import 'package:meeple_hearth/features/profile/presentation/widgets/profile_action_sheet.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:share_plus/share_plus.dart';

/// The signed-in user's profile (SCREENS §8.1).
class OwnProfileScreen extends ConsumerWidget {
  const OwnProfileScreen({super.key});

  Future<void> _menu(BuildContext context, WidgetRef ref, String userId) async {
    final l10n = context.l10n;
    final choice = await showProfileActionSheet(
      context,
      actions: [
        (
          id: 'share',
          icon: Icons.share_outlined,
          label: l10n.profileShare,
          danger: false
        ),
        (
          id: 'bookmarks',
          icon: Icons.bookmark_border_rounded,
          label: l10n.bookmarksTitle,
          danger: false
        ),
        (
          id: 'friends',
          icon: Icons.group_outlined,
          label: l10n.friendsTitle,
          danger: false
        ),
        (
          id: 'matching',
          icon: Icons.group_add_outlined,
          label: l10n.matchingTitle,
          danger: false
        ),
        (
          id: 'settings',
          icon: Icons.settings_outlined,
          label: l10n.settingsTitle,
          danger: false
        ),
        (
          id: 'logout',
          icon: Icons.logout_rounded,
          label: l10n.settingsSignOut,
          danger: true
        ),
      ],
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'share':
        await Share.share('${AppConfig.webOrigin}/profile/$userId');
      case 'friends':
        await context.push(AppRoutes.friends);
      case 'bookmarks':
        await context.push(AppRoutes.bookmarks);
      case 'matching':
        await context.push(AppRoutes.matching);
      case 'settings':
        await context.push(AppRoutes.settings);
      case 'logout':
        final ok = await showConfirmSheet(
          context,
          title: l10n.settingsSignOutTitle,
          message: l10n.settingsSignOutMessage,
          confirmLabel: l10n.settingsSignOut,
          destructive: false,
          icon: Icons.logout_rounded,
        );
        if (ok) await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    return Scaffold(
      appBar: const MeepleBrandBar(),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              notificationPredicate: (n) => n.depth == 0,
              onRefresh: () async {
                ref
                  ..invalidate(userStatsProvider(user.id))
                  ..invalidate(userFavoritesProvider(user.id))
                  ..invalidate(userCollectionProvider(user.id))
                  ..invalidate(userPostsProvider(user.id))
                  ..invalidate(taggedPostsProvider(user.id));
              },
              child: ProfileView(
                user: user,
                isSelf: true,
                actions: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        key: const Key('profile-edit'),
                        label: l10n.profileEdit,
                        icon: Icons.edit_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        height: 44,
                        onPressed: () => context.push(AppRoutes.editProfile),
                      ),
                    ),
                    AppSpacing.hGapSm,
                    ProfileMoreButton(
                      key: const Key('profile-menu'),
                      tooltip: l10n.commonMore,
                      onPressed: () => _menu(context, ref, user.id),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
