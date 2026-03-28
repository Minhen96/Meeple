import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Onboarding step 4 — suggested friends (contacts / mutual interests).
class OnboardingFriendsScreen extends StatefulWidget {
  const OnboardingFriendsScreen({super.key});

  @override
  State<OnboardingFriendsScreen> createState() =>
      _OnboardingFriendsScreenState();
}

class _OnboardingFriendsScreenState extends State<OnboardingFriendsScreen> {
  // Placeholder suggested users shown before real API is wired up.
  final _suggested = const [
    _SuggestedUser(name: 'Alex Meeple', username: 'alex_meeple', mutual: 3),
    _SuggestedUser(name: 'BoardQueen', username: 'boardqueen', mutual: 7),
    _SuggestedUser(name: 'DiceRoller99', username: 'diceroller99', mutual: 1),
    _SuggestedUser(name: 'HexMaster', username: 'hexmaster', mutual: 5),
  ];
  final Set<String> _added = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OnboardingProgress(step: 3, total: 4),
              AppSpacing.vGapXl,
              Text('Find friends', style: AppTypography.headlineMedium),
              AppSpacing.vGapSm,
              Text(
                'Send friend requests to people you may know.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              AppSpacing.vGapXl,
              Expanded(
                child: ListView.separated(
                  itemCount: _suggested.length,
                  separatorBuilder: (_, __) => AppSpacing.vGapSm,
                  itemBuilder: (context, index) {
                    final user = _suggested[index];
                    final isAdded = _added.contains(user.username);
                    return _SuggestedUserTile(
                      user: user,
                      isAdded: isAdded,
                      onAdd: () => setState(
                        () => isAdded
                            ? _added.remove(user.username)
                            : _added.add(user.username),
                      ),
                    );
                  },
                ),
              ),
              AppSpacing.vGapMd,
              AppButton(
                label: _added.isEmpty ? 'Skip' : 'Send ${_added.length} Request${_added.length > 1 ? 's' : ''}',
                onPressed: () => context.go(AppRoutes.onboardingAddGame),
              ),
              AppSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedUserTile extends StatelessWidget {
  const _SuggestedUserTile({
    required this.user,
    required this.isAdded,
    required this.onAdd,
  });

  final _SuggestedUser user;
  final bool isAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Row(
        children: [
          AppAvatar(size: 40, displayName: user.name),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTypography.titleSmall),
                Text(
                  '${user.mutual} mutual friend${user.mutual > 1 ? 's' : ''}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              foregroundColor:
                  isAdded ? AppColors.onSurfaceVariant : AppColors.primary,
            ),
            child: Text(
              isAdded ? 'Pending' : 'Add Friend',
              style: AppTypography.labelMedium.copyWith(
                color: isAdded ? AppColors.onSurfaceVariant : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < step;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: AppSpacing.xs),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : AppColors.surfaceContainerHigh,
              borderRadius: AppSpacing.borderRadiusSm,
            ),
          ),
        );
      }),
    );
  }
}

class _SuggestedUser {
  const _SuggestedUser({
    required this.name,
    required this.username,
    required this.mutual,
  });

  final String name;
  final String username;
  final int mutual;
}
