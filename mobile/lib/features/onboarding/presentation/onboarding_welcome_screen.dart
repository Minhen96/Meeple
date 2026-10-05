import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Onboarding step 1 (SCREENS §3.2): logo, tagline, three teasers.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final teasers = [
      (Icons.library_books_outlined, l10n.welcomeLibrary),
      (Icons.event_outlined, l10n.welcomeEvents),
      (Icons.group_add_outlined, l10n.welcomeMatching),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 48,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.games_rounded,
                    color: AppColors.onPrimary,
                    size: 64,
                  ),
                ),
              ),
              AppSpacing.vGapXl,
              Text(
                l10n.appName,
                style: AppTypography.displaySmall.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapSm,
              Text(
                l10n.welcomeTagline,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapXl,
              for (final (icon, text) in teasers)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primaryFixed,
                        child: Icon(icon, color: AppColors.primary),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(child: Text(text, style: AppTypography.titleSmall)),
                    ],
                  ),
                ),
              const Spacer(),
              AppButton(
                key: const Key('welcome-start'),
                label: l10n.welcomeStart,
                onPressed: () => context.go(AppRoutes.onboardingProfile),
              ),
              AppSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }
}
