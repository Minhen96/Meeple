import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/home_widgets.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/profile/presentation/profile_view.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:share_plus/share_plus.dart';

/// The signed-in user's profile (SCREENS §8.1).
class OwnProfileScreen extends ConsumerWidget {
  const OwnProfileScreen({super.key});

  Future<void> _menu(BuildContext context, WidgetRef ref, String userId) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, icon, label) in [
              ('share', Icons.share_outlined, l10n.profileShare),
              ('friends', Icons.group_outlined, l10n.friendsTitle),
              ('bookmarks', Icons.bookmark_border_rounded, l10n.bookmarksTitle),
              ('matching', Icons.group_add_outlined, l10n.matchingTitle),
              ('settings', Icons.settings_outlined, l10n.settingsTitle),
              ('logout', Icons.logout_rounded, l10n.settingsSignOut),
            ])
              ListTile(
                key: ValueKey('profile-menu-$key'),
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(sheet).pop(key),
              ),
          ],
        ),
      ),
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
      appBar: MeepleAppBar(
        title: l10n.navProfile,
        actions: [
          const NotificationBell(),
          IconButton(
            key: const Key('profile-settings'),
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              notificationPredicate: (n) => n.depth == 0,
              onRefresh: () async {
                ref
                  ..invalidate(userStatsProvider(user.id))
                  ..invalidate(userFavoritesProvider(user.id))
                  ..invalidate(userCollectionProvider(user.id))
                  ..invalidate(userPostsProvider(user.id));
              },
              child: ProfileView(
                user: user,
                isSelf: true,
                actions: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('profile-edit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          foregroundColor: AppColors.onSurface,
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () => context.push(AppRoutes.editProfile),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.profileEdit),
                      ),
                    ),
                    AppSpacing.hGapSm,
                    IconButton.filledTonal(
                      key: const Key('profile-menu'),
                      tooltip: l10n.commonMore,
                      onPressed: () => _menu(context, ref, user.id),
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
