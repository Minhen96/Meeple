import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// First onboarding screen — shown once after successful registration.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Illustration placeholder
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 48,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.games_rounded,
                    color: AppColors.onPrimary,
                    size: 72,
                  ),
                ),
              ),
              AppSpacing.vGapXxl,
              Text(
                'Welcome to\nMeeple',
                style: AppTypography.headlineLarge,
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapMd,
              Text(
                'Your board game community. Track your collection, discover events, and connect with fellow gamers.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: "Let's Get Started",
                onPressed: () => context.go(AppRoutes.onboardingProfile),
              ),
              AppSpacing.vGapMd,
              AppTextButton(
                label: 'Skip setup',
                onPressed: () => context.go(AppRoutes.home),
              ),
              AppSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }
}
