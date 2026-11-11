import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/social/data/social_repository.dart';
import 'package:meeple_hearth/features/social/presentation/widgets/people_widgets.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

/// Blocked users with unblock (`GET /users/me/blocked`), styled like the
/// web people lists (settings sub-page header, rounded person rows).
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.sm,
    AppSpacing.lg,
    AppSpacing.xxxl,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.blockedTitle,
        showBackButton: true,
        compactTitle: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: ref.watch(blockedUsersProvider).when(
            loading: () => ListView(
              padding: _padding,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  const SkeletonBox(
                    height: 72,
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppRadius.tile)),
                  ),
                  AppSpacing.vGapSm,
                ],
              ],
            ),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(blockedUsersProvider),
            ),
            data: (users) => ListView(
              padding: _padding,
              children: users.isEmpty
                  ? [
                      EmptyState(
                        icon: Icons.block_rounded,
                        title: l10n.blockedEmpty,
                        boxed: true,
                      ),
                    ]
                  : [
                      for (final u in users) ...[
                        PersonCard(
                          user: u,
                          onTap: () {},
                          trailing: PeoplePillButton(
                            key: ValueKey('unblock-${u.id}'),
                            label: l10n.friendUnblock,
                            icon: Icons.lock_open_rounded,
                            fg: AppColors.onSurfaceVariant,
                            onTap: () async {
                              try {
                                await ref
                                    .read(socialRepositoryProvider)
                                    .unblock(u.id);
                                ref.invalidate(blockedUsersProvider);
                              } catch (e) {
                                if (context.mounted) showErrorToast(context, e);
                              }
                            },
                          ),
                        ),
                        AppSpacing.vGapSm,
                      ],
                    ],
            ),
          ),
    );
  }
}
