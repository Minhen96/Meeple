import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/social/data/social_repository.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Blocked users with unblock (`GET /users/me/blocked`).
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.blockedTitle,
        showBackButton: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: ref.watch(blockedUsersProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(blockedUsersProvider),
            ),
            data: (users) => users.isEmpty
                ? EmptyState(icon: Icons.block_rounded, title: l10n.blockedEmpty)
                : ListView(
                    children: [
                      for (final u in users)
                        UserRow(
                          user: u,
                          onTap: () {},
                          trailing: OutlinedButton(
                            key: ValueKey('unblock-${u.id}'),
                            onPressed: () async {
                              try {
                                await ref.read(socialRepositoryProvider).unblock(u.id);
                                ref.invalidate(blockedUsersProvider);
                              } catch (e) {
                                if (context.mounted) showErrorToast(context, e);
                              }
                            },
                            child: Text(l10n.friendUnblock),
                          ),
                        ),
                    ],
                  ),
          ),
    );
  }
}
