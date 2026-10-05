import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/features/social/presentation/friend_button.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
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
      subtitle: l10n.onboardingFriendsBody,
      bottom: AppButton(
        key: const Key('onboarding-friends-continue'),
        label: l10n.commonContinue,
        onPressed: () =>
            goToNextOnboardingStep(context, ref, AppRoutes.onboardingFriends),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  if (mounted) setState(() => _query = v.trim());
                });
              },
              decoration: InputDecoration(
                hintText: l10n.friendsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          AppSpacing.vGapSm,
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(userSearchProvider(_query)),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          l10n.friendsNoSuggestions,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final u in list)
                          UserRow(
                            user: u,
                            onTap: () {},
                            trailing: FriendButton(
                              userId: u.id,
                              compact: true,
                              initial: u.friendshipStatus,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
