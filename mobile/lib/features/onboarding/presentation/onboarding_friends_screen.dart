import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/features/social/presentation/friend_button.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Onboarding step 4 (SCREENS §3.5): suggestions + search with inline
/// "Add Friend".
class OnboardingFriendsScreen extends ConsumerStatefulWidget {
  const OnboardingFriendsScreen({super.key});

  @override
  ConsumerState<OnboardingFriendsScreen> createState() =>
      _OnboardingFriendsScreenState();
}

class _OnboardingFriendsScreenState
    extends ConsumerState<OnboardingFriendsScreen> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final users = ref.watch(userSearchProvider(_query));
    return OnboardingScaffold(
      route: AppRoutes.onboardingFriends,
      title: l10n.onboardingFriendsTitle,
      bottom: AppButton(
        key: const Key('onboarding-friends-continue'),
        label: l10n.commonContinue,
        onPressed: () =>
            goToNextOnboardingStep(context, ref, AppRoutes.onboardingFriends),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: onboardingGutter),
        children: [
          TextField(
            key: const Key('onboarding-friends-search'),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) setState(() => _query = v.trim());
              });
            },
            style: AppTypography.bodyMedium,
            decoration: appFieldDecoration(
              hint: l10n.onboardingFriendsSearchHint,
              prefixIcon: Icons.search_rounded,
              fill: AppColors.surfaceContainerHighest,
              radius: AppRadius.tile,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ).copyWith(
              hintStyle: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          AppSpacing.vGapLg,
          if (_query.isEmpty) SectionLabel(l10n.friendsSuggestions),
          ...users.when(
            loading: () => [
              for (var i = 0; i < 3; i++) ...[
                const SkeletonBox(
                  height: 72,
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                AppSpacing.vGapSm,
              ],
            ],
            error: (e, _) => [
              ErrorState(
                error: e,
                onRetry: () => ref.invalidate(userSearchProvider(_query)),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxl,
                      ),
                      child: Text(
                        _query.isEmpty
                            ? l10n.friendsNoSuggestions
                            : l10n.onboardingFriendsNoResults(_query),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ]
                : [
                    for (final u in list) ...[
                      _PersonRow(user: u),
                      AppSpacing.vGapSm,
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

/// Web onboarding person row: `p-3 rounded-2xl bg-surface-container-low`,
/// 48px avatar, bold name, @handle and the small Friend button.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final name = displayNameOf(context, user);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Row(
        children: [
          AppAvatar(imageUrl: user.avatarUrl, displayName: name, size: 48),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall,
                ),
                Text(
                  '@${user.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AppSpacing.hGapSm,
          FriendButton(
            userId: user.id,
            compact: true,
            initial: user.friendshipStatus,
          ),
        ],
      ),
    );
  }
}
