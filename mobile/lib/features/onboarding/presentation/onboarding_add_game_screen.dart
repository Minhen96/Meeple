import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Onboarding step 5 — add first game to library, then complete onboarding.
class OnboardingAddGameScreen extends ConsumerWidget {
  const OnboardingAddGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              _OnboardingProgress(step: 4, total: 4),
              AppSpacing.vGapXl,
              Text(
                'Add your first game',
                style: AppTypography.headlineMedium,
              ),
              AppSpacing.vGapSm,
              Text(
                'Search the BoardGameGeek database to add games to your collection.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              AppSpacing.vGapXxl,
              // Search bar stub
              Container(
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
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                    AppSpacing.hGapSm,
                    Text(
                      'Search games…',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapXl,
              // Popular games placeholder
              Text('Popular right now', style: AppTypography.titleMedium),
              AppSpacing.vGapMd,
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  children: const [
                    _GamePlaceholderCard(name: 'Catan'),
                    _GamePlaceholderCard(name: 'Ticket to Ride'),
                    _GamePlaceholderCard(name: 'Pandemic'),
                    _GamePlaceholderCard(name: 'Azul'),
                    _GamePlaceholderCard(name: 'Wingspan'),
                    _GamePlaceholderCard(name: 'Gloomhaven'),
                  ],
                ),
              ),
              AppSpacing.vGapMd,
              AppButton(
                label: 'Finish Setup',
                onPressed: () => _completeOnboarding(context, ref),
              ),
              AppSpacing.vGapMd,
              AppTextButton(
                label: 'Skip — I\'ll add games later',
                onPressed: () => _completeOnboarding(context, ref),
              ),
              AppSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Mark onboarding complete — router redirect handles navigation to home.
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user != null) {
      ref.read(authNotifierProvider.notifier).updateUser(
            user.copyWith(onboardingCompleted: true),
          );
    }
    if (context.mounted) context.go(AppRoutes.home);
  }
}

class _GamePlaceholderCard extends StatelessWidget {
  const _GamePlaceholderCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: AppSpacing.borderRadiusSm,
            ),
            child: const Icon(
              Icons.casino_rounded,
              color: AppColors.onSurfaceVariant,
              size: 28,
            ),
          ),
          AppSpacing.vGapXs,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              name,
              style: AppTypography.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
